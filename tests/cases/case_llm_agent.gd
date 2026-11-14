# 用例：大模型 agent 循环（用假客户端，不联网、不需要 key）
#   直接走对 / 先走错再改对 / 光说话不落子 / 一直走错 / 先试走再落子 / 坏参数 / key 无效 / 请求体 / 开场白
# 需要等信号，所以是实例方法 + await（run_tests.gd 的异步用例）。
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const AGENT = preload("res://scripts/llm/llm_agent.gd")
const SETTINGS = preload("res://scripts/llm/settings_store.gd")
const FAKE = preload("res://tests/fake_llm_client.gd")

var _agent = AGENT.new()
var _settings = SETTINGS.new()
var _state = null

func run(t) -> bool:
	_settings.api_key = "sk-test-not-real"
	_settings.persona_name = "大肥鱼"
	_state = RM.apply(RS.initial(), {"type": "move", "to": Vector2i(4, 1)})   # 轮到橙方
	var e8: Dictionary = {"move": "e8", "say": "看招"}
	var e5: Dictionary = {"move": "e5", "say": "嘿"}

	var r: Dictionary = await _turn([FAKE.tool_reply("make_move", e8)])
	t.eq(r["move"], {"type": "move", "to": Vector2i(4, 7)}, "direct legal move")
	t.eq(r["say"], "看招", "line comes back with the move")
	t.eq(r["requests"], 1, "one request is enough")
	var body: Dictionary = _last_fake.bodies[0]
	t.eq(body["thinking"], {"type": "disabled"}, "thinking mode disabled")
	t.eq(body["model"], "deepseek-flash", "default model")
	t.eq(body["tools"].size(), 3, "tools sent")
	t.check(body["messages"][0]["content"].contains("你的名字：大肥鱼"), "persona in system prompt")
	t.check(not JSON.stringify(body).contains("sk-test"), "key never goes into the body")

	r = await _turn([FAKE.tool_reply("make_move", e5), FAKE.tool_reply("make_move", e8)])
	t.eq(r["move"], {"type": "move", "to": Vector2i(4, 7)}, "corrects itself after a rejection")
	var second: Array = _last_fake.bodies[1]["messages"]
	t.check(second[second.size() - 1]["role"] == "tool" and second[second.size() - 1]["content"].contains("被拒绝"),
		"rejection reason is sent back as a tool result")

	r = await _turn([FAKE.text_reply("让我想想"), FAKE.tool_reply("make_move", e8)])
	t.eq(r["requests"], 2, "reminded once after a reply without tool call")

	r = await _turn([FAKE.tool_reply("make_move", e5), FAKE.tool_reply("make_move", e5)])
	t.check(r["move"].is_empty() and r["error"].contains("走错"), "gives up after repeated illegal moves")
	t.check(not r["fatal"], "illegal moves are not fatal")

	r = await _turn([FAKE.calls_reply([["preview_move", {"move": "e8"}], ["make_move", e8]])])
	t.eq(r["requests"], 1, "preview + move in one reply")

	r = await _turn([FAKE.calls_reply([["make_move", "not json"]]), FAKE.tool_reply("make_move", e8)])
	t.eq(r["move"], {"type": "move", "to": Vector2i(4, 7)}, "bad JSON arguments are survivable")

	r = await _turn([FAKE.error_reply("API key 无效", true)])
	t.check(r["move"].is_empty() and r["fatal"], "invalid key is fatal")

	var fake = _new_fake([FAKE.text_reply("  “你好呀，准备好了吗？”  ")])
	var line: String = await _agent.speak(fake, _settings, "打个招呼")
	t.eq(line, "你好呀，准备好了吗？", "greeting is cleaned up")
	t.check(not fake.bodies[0].has("tools"), "greeting request carries no tools")

	# 假客户端可能还在发信号的调用栈里，统一延后释放
	for f in _fakes:
		f.call_deferred("free")
	return true                                # run_tests 据此确认用例没有中途出错

var _fakes: Array = []
var _last_fake = null

func _new_fake(replies: Array):
	var f = FAKE.new()
	f.replies = replies
	_fakes.append(f)
	return f

# 用一组预设回复跑一回合
func _turn(replies: Array) -> Dictionary:
	_last_fake = _new_fake(replies)
	var r: Dictionary = await _agent.play_turn(_last_fake, _settings, _state, 1, "轮到你了")
	return r
