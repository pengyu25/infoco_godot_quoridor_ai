# 大模型对战的界面冒烟测试（用假客户端，不联网、不需要 key）：
#   没配 key 的提示 → 设置页遮挡与保存 → 开场白 → 走子后对手带台词应对 → 聊天和走法随请求发出
#   → key 无效转电脑代下且之后不再请求 → 思考中途重开，迟到的回复作废
# 运行（在项目根目录，需要窗口，不能加 --headless）：godot --path . --script tests/ui_llm_smoke.gd
extends SceneTree

const FAKE = preload("res://tests/fake_llm_client.gd")
const DRIVER = preload("res://tests/ui_driver.gd")
const RS = preload("res://scripts/rules/rule_state.gd")

const SETTINGS_PATH := "user://test_ui_llm_settings.cfg"
const KEY := "sk-test-0123456789abcd"
const MAX_TRIES := 60                 # 每步最多等 60 轮（每轮 6 帧，约 6 秒）

var _d = DRIVER.new(self)
var _main = null
var _fake = null
var _chat_fake = null
var _step: int = 0
var _frames: int = 0
var _tries: int = 0

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.settings_path = SETTINGS_PATH
	var llm = _main.get_node("LlmTurn")
	_fake = FAKE.new()
	_chat_fake = FAKE.new()
	llm.add_child(_fake)
	llm.add_child(_chat_fake)
	llm.client = _fake
	llm.chat_client = _chat_fake
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	_frames = 0
	if _run_step(_step):
		_step += 1
		_tries = 0
	else:
		_tries += 1
		if _tries > MAX_TRIES:
			_d.expect("第 %d 步等待超时" % _step, false, true)
			_finish()
	return false

# 返回 true = 这一步做完；false = 条件还没满足，下一轮再看
func _run_step(i: int) -> bool:
	var S = _main.State
	var p = _main.settings_panel
	match i:
		0:
			_d.click_control(_main.menu.buttons["llm"])
			_d.expect("没配 key 时停在菜单", _main.phase, S.MENU)
			_d.expect("弹出未配置提示", _main.menu.notice.visible, true)
			_d.click_control(_main.menu.notice_go)
			_d.expect("点「去设置」打开设置页", p.visible, true)
			_d.expect("key 输入框默认遮挡", p.key_edit.secret, true)
			p.key_edit.text = KEY
			p.name_edit.text = "大肥鱼"
			p.remember.button_pressed = false
			_d.click_control(p.save_button)
			_d.expect("保存后有 key", _main.settings.has_key(), true)
			_d.expect("不保存到本机时文件里没有 key", FileAccess.get_file_as_string(SETTINGS_PATH).contains("0123456789"), false)
			_d.click_control(_main.menu.settings_button)
			_d.expect("再次打开时不回填 key", p.key_edit.text, "")
			var ph: String = p.key_edit.placeholder_text
			_d.expect("占位文字只露首尾", ph.contains("sk-****abcd") and not ph.contains(KEY), true)
		1:
			_d.shot("ui_llm_smoke_settings")
			_d.click_control(p.cancel_button)
			_chat_fake.replies = [FAKE.text_reply("准备好挨揍了吗")]
			_fake.replies = [FAKE.tool_reply("make_move", {"move": "e8", "say": "看招"})]
			_d.click_control(_main.menu.buttons["llm"])
			_d.expect("有 key 后进入大模型对局", _main.phase, S.WAITING_INPUT)
			_d.expect("聊天框可见", _main.chat.visible, true)
		2:
			if not _main.hud.speech_label.text.contains("准备好挨揍了吗"):
				return false
			_d.expect("开场白显示在气泡里", _main.hud.speech_label.text, "大肥鱼：准备好挨揍了吗")
			_main.chat.input.text = "你好呀"
			_d.click_control(_main.chat.send_button)
			_human_move(Vector2i(4, 1))
			_d.expect("人走完进入对手回合", _main.phase, S.AI_THINKING)
			_d.expect("顶部显示角色名思考中", _main.hud.turn_label.text, "大肥鱼思考中…")
		3:
			if _main.phase != S.WAITING_INPUT:
				return false
			_d.expect("对手走到 e8", _main.state.pawns[1], Vector2i(4, 7))
			_d.expect("台词显示在气泡里", _main.hud.speech_label.text, "大肥鱼：看招")
			var msg: String = _fake.bodies[0]["messages"][1]["content"]
			_d.expect("请求里带着玩家刚才的走法", msg.contains("走到 e2"), true)
			_d.expect("请求里带着玩家的聊天", msg.contains("你好呀"), true)
			_d.expect("请求里带着开场白", msg.contains("准备好挨揍了吗"), true)
			_d.shot("ui_llm_smoke_llm")
			_fake.replies = [FAKE.error_reply("API key 无效", true)]
			_human_move(Vector2i(4, 2))
		4:
			if _main.phase != S.WAITING_INPUT:
				return false
			_d.expect("key 无效时电脑代下了一步", _main.state.turn, 0)
			_d.expect("气泡里提示走神", _main.hud.speech_label.text.contains("走神"), true)
			_human_move(Vector2i(-1, -1))
		5:
			if _main.phase != S.WAITING_INPUT:
				return false
			_d.expect("离线后不再请求大模型", _fake.bodies.size(), 2)
			_d.click_control(_main.hud.restart_button)
		6:
			_fake.hold = true
			_fake.replies = [FAKE.tool_reply("make_move", {"move": "e8", "say": "嘿"})]
			_human_move(Vector2i(4, 1))
			_d.expect("重开后恢复请求（不再离线）", _main.phase, S.AI_THINKING)
		7:
			if _fake.bodies.size() < 3:
				return false
			_d.click_control(_main.hud.restart_button)
			_fake.release()
		8:
			_d.expect("思考中重开后是初始局面", _main.state.to_string_state(), RS.initial().to_string_state())
			_d.expect("重开后等人操作", _main.phase, S.WAITING_INPUT)
			_finish()
	return true

# 人走一步：先点自己的棋子，再点目标（目标传 (-1,-1) = 随便挑一个能走的格子）
func _human_move(target: Vector2i) -> void:
	_d.click_cell(_main.state.pawns[0])
	if target.x < 0:
		target = _main.human.legal_targets[0]
	_d.click_cell(target)

func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("UI LLM smoke fail=%d" % _d.fail)
	quit(0 if _d.fail == 0 else 1)
