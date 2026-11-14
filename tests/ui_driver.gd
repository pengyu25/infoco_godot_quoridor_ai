# 界面测试小工具：模拟鼠标点击、断言计数、截图。ui_smoke.gd 与 ui_llm_smoke.gd 共用。
# 截图存到 user://（路径会打印出来），不进仓库。
extends RefCounted

const GEO = preload("res://scripts/ui/board_geometry.gd")

var tree: SceneTree
var fail: int = 0

func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree

func click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		tree.root.push_input(ev, true)

func click_control(c: Control) -> void:
	click(c.get_global_rect().get_center())

func click_cell(cell: Vector2i) -> void:
	click(GEO.cell_center(cell))

func expect(label: String, actual, expected) -> void:
	var ok: bool = actual == expected
	if not ok:
		fail += 1
	print("  [%s] %s -> %s" % ["OK" if ok else "FAIL", label, str(actual)])

# 截的是上一帧画好的画面：刚改完界面要隔一帧再截
func shot(file_name: String) -> void:
	var path: String = "user://%s.png" % file_name
	tree.root.get_texture().get_image().save_png(path)
	print("  shot: ", ProjectSettings.globalize_path(path))
