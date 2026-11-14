# 界面冒烟测试：加载主场景，用模拟鼠标点击走完「菜单 → 人机对战 → 电脑应对 → 重开竞态 → 回菜单 → 双人对战」
# 运行（在项目根目录，需要窗口，不能加 --headless）：godot --path . --script tests/ui_smoke.gd
# 退出码：0 = 全部符合预期，1 = 有不符合。截图存到 user://（路径会打印出来），不进仓库。
extends SceneTree

const RS = preload("res://scripts/rules/rule_state.gd")
const DRIVER = preload("res://tests/ui_driver.gd")

const MAX_TRIES := 100                # 等电脑落子最多等 100 轮（每轮 6 帧，约 10 秒）

var _d = DRIVER.new(self)
var _main = null
var _step: int = 0
var _frames: int = 0
var _tries: int = 0

func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.settings_path = "user://test_ui_smoke_settings.cfg"    # 不碰玩家真实的设置
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:                   # 每步之间留几帧给界面刷新
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
	match i:
		0:
			_d.expect("启动停在菜单", _main.phase, S.MENU)
			_d.expect("菜单可见", _main.menu.visible, true)
			_d.shot("ui_smoke_menu")
			_d.click_control(_main.menu.buttons["normal"])
		1:
			_d.expect("选人机·中后进入对局", _main.phase, S.WAITING_INPUT)
			_d.expect("档位为 normal", _main.level, "normal")
			_d.expect("菜单已隐藏", _main.menu.visible, false)
			_d.click_cell(Vector2i(4, 0))     # 选中蓝方棋子
			_d.click_cell(Vector2i(4, 1))     # 走到 (4,1)
			_d.expect("人走完立刻进入电脑回合", _main.phase, S.AI_THINKING)
		2:
			if _main.phase != S.WAITING_INPUT:
				return false
			_d.expect("电脑走完轮回到人", _main.state.turn, 0)
			_d.expect("人仍在 (4,1)", _main.state.pawns[0], Vector2i(4, 1))
			var moved: bool = _main.state.pawns[1] != Vector2i(4, 8) or _main.state.walls_left[1] == 9
			_d.expect("电脑确实走了一步或放了一堵墙", moved, true)
			_d.shot("ui_smoke_vs_ai")
			_d.click_cell(Vector2i(4, 1))                 # 再选中蓝方棋子
			_d.click_cell(_main.human.legal_targets[0])   # 随便走一个合法格（电脑的墙可能挡住某些方向）
			_d.expect("第二步后进入电脑回合", _main.phase, S.AI_THINKING)
			_d.click_control(_main.hud.restart_button)    # 电脑思考途中点重开
		3:
			_d.expect("重开后是初始局面", _main.state.to_string_state(), RS.initial().to_string_state())
			_d.expect("重开后等人操作", _main.phase, S.WAITING_INPUT)
			_frames = -60                 # 再多等一秒，让被作废的那次电脑回合有机会「捣乱」
		4:
			_d.expect("作废的电脑着法没有落到新局上", _main.state.to_string_state(), RS.initial().to_string_state())
			_d.click_control(_main.hud.menu_button)
		5:
			_d.expect("点菜单回到菜单", _main.phase, S.MENU)
			_d.click_control(_main.menu.buttons[""])
		6:
			_d.expect("选双人对战", _main.level, "")
			_d.click_cell(Vector2i(4, 0))
			_d.click_cell(Vector2i(4, 1))
			_d.expect("双人模式走完不进电脑回合", _main.phase, S.WAITING_INPUT)
			_d.expect("双人模式轮到玩家2", _main.state.turn, 1)
			_finish()
	return true

func _finish() -> void:
	print("UI smoke fail=%d" % _d.fail)
	quit(0 if _d.fail == 0 else 1)
