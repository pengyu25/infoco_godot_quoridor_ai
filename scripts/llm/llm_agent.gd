# 一个回合的「小 agent」：把局面发给大模型 → 执行它调用的工具 → 直到 make_move 成功。
# 出错（网络 / key / 一直走错 / 太慢）就返回 error，由 llm_turn.gd 交给本地电脑兜底。
# client 只要有 request_chat() 和 completed 信号就行（测试里换成假客户端）。
extends RefCounted

const P = preload("res://scripts/llm/prompts.gd")
const GT = preload("res://scripts/llm/game_tools.gd")

const MAX_REQUESTS := 4        # 一回合最多发几次请求
const MAX_REJECTS := 2         # make_move 被拒几次就放弃
const TURN_BUDGET_MS := 45000  # 一回合最多等多久
const REMINDER := "请调用 make_move 工具走这一步，并在 say 参数里对玩家说一句话。"

# 返回 {"move": 着法或 {}, "say": 台词, "error": 出错原因, "fatal": 是否 key 无效 / 余额不足, "requests": 发了几次}
func play_turn(client, settings, state, me: int, turn_msg: String) -> Dictionary:
	var messages: Array = [
		{"role": "system", "content": P.system_prompt(settings.display_name(), settings.persona_prompt)},
		{"role": "user", "content": turn_msg},
	]
	var rejects: int = 0
	var started: int = Time.get_ticks_msec()
	for i in range(MAX_REQUESTS):
		if Time.get_ticks_msec() - started > TURN_BUDGET_MS:
			return _fail("想得太久了", false, i)
		client.request_chat(settings.base_url, settings.api_key, build_body(settings, messages, true))
		var res: Dictionary = await client.completed
		if not res["ok"]:
			return _fail(res["error"], res.get("fatal", false), i + 1)

		var msg: Dictionary = res["message"]
		var calls = msg.get("tool_calls")
		if typeof(calls) != TYPE_ARRAY:
			calls = []
		messages.append(_assistant_copy(msg, calls))
		if calls.is_empty():
			messages.append({"role": "user", "content": REMINDER})   # 光说话没落子：提醒一次
			continue

		for call in calls:
			var fn: Dictionary = call.get("function", {})
			var tool_name: String = str(fn.get("name", ""))
			var r: Dictionary = GT.execute(state, me, tool_name, _parse_args(str(fn.get("arguments", "{}"))))
			if not r["move"].is_empty():
				return {"move": r["move"], "say": r["say"], "error": "", "fatal": false, "requests": i + 1}
			if tool_name == "make_move":
				rejects += 1
			messages.append({"role": "tool", "tool_call_id": str(call.get("id", "")), "content": r["content"]})
		if rejects >= MAX_REJECTS:
			return _fail("连续 %d 次走错" % rejects, false, i + 1)
	return _fail("问了 %d 次也没走出一步" % MAX_REQUESTS, false, MAX_REQUESTS)

# 只说一句话、不下棋（开场白 / 终局感言）。失败返回 ""
func speak(client, settings, prompt: String) -> String:
	var messages: Array = [
		{"role": "system", "content": P.system_prompt(settings.display_name(), settings.persona_prompt)},
		{"role": "user", "content": prompt},
	]
	client.request_chat(settings.base_url, settings.api_key, build_body(settings, messages, false))
	var res: Dictionary = await client.completed
	if not res["ok"]:
		return ""
	return P.clip_say(str(res["message"].get("content", "")))

# 请求体：关掉思考模式（更快；也免去「带工具时必须回传推理内容」的要求）
static func build_body(settings, messages: Array, with_tools: bool) -> Dictionary:
	var body: Dictionary = {
		"model": settings.model,
		"messages": messages,
		"thinking": {"type": "disabled"},
		"max_tokens": 400,
		"temperature": 0.7,
		"stream": false,
	}
	if with_tools:
		body["tools"] = GT.TOOLS
	return body

# 把模型的回复原样放回对话（工具调用要配对回复；万一开着思考模式，推理内容也要带上）
static func _assistant_copy(msg: Dictionary, calls: Array) -> Dictionary:
	var content = msg.get("content")
	var copy: Dictionary = {"role": "assistant", "content": content if typeof(content) == TYPE_STRING else ""}
	if not calls.is_empty():
		copy["tool_calls"] = calls
	if msg.has("reasoning_content"):
		copy["reasoning_content"] = msg["reasoning_content"]
	return copy

# 工具参数是 JSON 字符串；模型偶尔写坏，解析不了就当空参数（工具会返回「看不懂」让它重来）
static func _parse_args(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

static func _fail(reason: String, fatal: bool, requests: int) -> Dictionary:
	return {"move": {}, "say": "", "error": reason, "fatal": fatal, "requests": requests}
