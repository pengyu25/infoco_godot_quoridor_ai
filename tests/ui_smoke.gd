# 界面冒烟测试：加载主场景，用模拟鼠标点击走完「菜单 → 人机对战 → 电脑应对 → 重开竞态 → 回菜单 → 双人对战」
# 运行（在项目根目录，需要窗口，不能加 --headless）：godot --path . --script tests/ui_smoke.gd
# 退出码：0 = 全部符合预期，1 = 有不符合。截图存到 user://（路径会打印出来），不进仓库。
extends SceneTree

const RS = preload("res://scripts/rules/rule_state.gd")
const GEO = preload("res://scripts/ui/board_geometry.gd")

const TIMEOUT_FRAMES := 600           # 等电脑落子最多等这么多帧（约 10 秒）

var _main = null
var _step: int = 0
var _wait: int = 0
var _fail: int = 0

func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:                     # 每步之间留几帧给界面刷新
		return false
	_wait = 0
	_step += 1
	var S = _main.State
	match _step:
		1:
			_expect("启动停在菜单", _main.phase, S.MENU)
			_expect("菜单可见", _main.menu.visible, true)
			_shot("menu")
			_click(_center(_main.menu.buttons["normal"]))
		2:
			_expect("选人机·中后进入对局", _main.phase, S.WAITING_INPUT)
			_expect("档位为 normal", _main.level, "normal")
			_expect("菜单已隐藏", _main.menu.visible, false)
			_click(Vector2(480, 168))     # 选中蓝方棋子 (4,0)
			_click(Vector2(480, 260))     # 走到 (4,1)
			_expect("人走完立刻进入电脑回合", _main.phase, S.AI_THINKING)
		3:
			if not _wait_for(S.WAITING_INPUT):
				return false
			_expect("电脑走完轮回到人", _main.state.turn, 0)
			_expect("人仍在 (4,1)", _main.state.pawns[0], Vector2i(4, 1))
			var moved: bool = _main.state.pawns[1] != Vector2i(4, 8) or _main.state.walls_left[1] == 9
			_expect("电脑确实走了一步或放了一堵墙", moved, true)
			_shot("vs_ai")
			_click(_cell_px(Vector2i(4, 1)))                # 再选中蓝方棋子
			_click(_cell_px(_main.legal_targets[0]))       # 随便走一个合法格（电脑的墙可能挡住某些方向）
			_expect("第二步后进入电脑回合", _main.phase, S.AI_THINKING)
			_click(_center(_main.hud.restart_button))   # 电脑思考途中点重开
		4:
			_expect("重开后是初始局面", _main.state.to_string_state(), RS.initial().to_string_state())
			_expect("重开后等人操作", _main.phase, S.WAITING_INPUT)
		5:
			_wait = -60                   # 再多等一秒，让被作废的那次电脑回合有机会「捣乱」
		6:
			_expect("作废的电脑着法没有落到新局上", _main.state.to_string_state(), RS.initial().to_string_state())
			_click(_center(_main.hud.menu_button))
		7:
			_expect("点菜单回到菜单", _main.phase, S.MENU)
			_click(_center(_main.menu.buttons[""]))
		8:
			_expect("选双人对战", _main.level, "")
			_click(Vector2(480, 168))
			_click(Vector2(480, 260))
			_expect("双人模式走完不进电脑回合", _main.phase, S.WAITING_INPUT)
			_expect("双人模式轮到玩家2", _main.state.turn, 1)
		9:
			print("UI smoke fail=%d" % _fail)
			quit(0 if _fail == 0 else 1)
	return false

# 等 phase 变成 target；超时算失败并结束
func _wait_for(target: int) -> bool:
	if _main.phase == target:
		return true
	if _wait_frames_used() > TIMEOUT_FRAMES:
		_expect("等待电脑落子超时", _main.phase, target)
		print("UI smoke fail=%d" % _fail)
		quit(1)
	_step -= 1                        # 下一轮再检查这一步
	return false

var _waited: int = 0
func _wait_frames_used() -> int:
	_waited += 6
	return _waited

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _cell_px(cell: Vector2i) -> Vector2:
	return GEO.cell_center(cell)

func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev, true)

func _expect(label: String, actual, expected) -> void:
	var ok: bool = actual == expected
	if not ok:
		_fail += 1
	print("  [%s] %s -> %s" % ["OK" if ok else "FAIL", label, str(actual)])

func _shot(name: String) -> void:
	var path: String = "user://ui_smoke_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("  shot: ", ProjectSettings.globalize_path(path))
