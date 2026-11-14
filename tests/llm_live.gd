# 大模型联调脚本（真实请求 DeepSeek）
#   设置了环境变量 DEEPSEEK_API_KEY：用你的 key 要一句开场白 + 下 3 步（蓝方由「低」档电脑代替玩家），
#     打印台词、走法、请求次数和耗时，用来看延迟和违规率。key 只显示首尾几位，绝不打印全文
#   没设置：用一个故意无效的 key 发一次请求，只检查网络连通与错误处理（应得到「API key 无效」）
# 运行（在项目根目录）：godot --headless --path . --script tests/llm_live.gd
extends SceneTree

const CLIENT = preload("res://scripts/llm/llm_client.gd")
const AGENT = preload("res://scripts/llm/llm_agent.gd")
const SETTINGS = preload("res://scripts/llm/settings_store.gd")
const P = preload("res://scripts/llm/prompts.gd")
const N = preload("res://scripts/llm/notation.gd")
const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const AI = preload("res://scripts/ai/ai_player.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")

const FAKE_KEY := "sk-invalid-key-for-connectivity-test"
const TURNS := 3

func _initialize() -> void:
	_run()

func _run() -> void:
	var client = CLIENT.new()
	root.add_child(client)
	await process_frame                       # 等节点进场景树，HTTPRequest 才能工作
	var settings = SETTINGS.new()
	var key: String = OS.get_environment("DEEPSEEK_API_KEY").strip_edges()

	if key == "":
		print("未设置 DEEPSEEK_API_KEY：用无效 key 检查网络连通与错误处理")
		var t0: int = Time.get_ticks_msec()
		var probe: Array = [{"role": "user", "content": "hi"}]
		client.request_chat(settings.base_url, FAKE_KEY, AGENT.build_body(settings, probe, false))
		var r: Dictionary = await client.completed
		print("  结果：ok=%s  错误=%s  fatal=%s  HTTP %d  用时 %d ms" % [
			r["ok"], r["error"], r["fatal"], r["code"], Time.get_ticks_msec() - t0])
		var passed: bool = not r["ok"] and r["fatal"] and r["code"] == 401
		print("  %s" % ("通过：网络可达，无效 key 被正确识别" if passed else "不符合预期"))
		quit(0 if passed else 1)
		return

	settings.api_key = key
	print("使用 key：%s  模型：%s  接口：%s" % [SETTINGS.mask_key(key), settings.model, settings.base_url])
	var agent = AGENT.new()
	var t1: int = Time.get_ticks_msec()
	var hello: String = await agent.speak(client, settings, P.greeting_message())
	print("开场白（%d ms）：%s" % [Time.get_ticks_msec() - t1, hello])

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var s = RS.initial()
	var fails: int = 0
	var total_ms: int = 0
	for turn in range(TURNS):
		var blue: Dictionary = AI.choose_move(s, DIFF.get_preset("easy"), rng)
		s = RM.apply(s, blue)
		if RM.winner(s) != -1:
			break
		var t0: int = Time.get_ticks_msec()
		var r: Dictionary = await agent.play_turn(client, settings, s, 1, P.turn_message(s, 1, N.describe(blue), [], []))
		var ms: int = Time.get_ticks_msec() - t0
		total_ms += ms
		if r["move"].is_empty():
			fails += 1
			print("第 %d 步失败（%d ms，%d 次请求）：%s" % [turn + 1, ms, r["requests"], r["error"]])
			s = RM.apply(s, AI.choose_move(s, DIFF.get_preset("normal"), rng))
		else:
			print("第 %d 步（%d ms，%d 次请求）：%s  台词：%s" % [
				turn + 1, ms, r["requests"], N.move_to_text(r["move"]), r["say"]])
			s = RM.apply(s, r["move"])
	print("共 %d 步，失败 %d 步，平均每步 %d ms" % [TURNS, fails, total_ms / TURNS])
	quit(0 if fails == 0 else 1)
