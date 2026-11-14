# 棋盘渲染与输入：只负责「贴图」和「把点击翻译成格子/墙坐标」。
# 美术全部来自 assets/sprites/ 的静态贴图（CC0 + 站点配色烘焙），运行时不画棋盘/棋子形状。
# 配色对齐 InfoCo 网站：--ink #0d1117 / --panel #161b22 / --acid #3fb950 / --blue #58a6ff / --orange #d29922
# 像素 ↔ 格子的换算全在 board_geometry.gd；墙的位置只通过 state.placed_walls() 取。
extends Node2D

signal cell_clicked(cell: Vector2i)
signal wall_clicked(kind: String, x: int, y: int)

const GEO = preload("res://scripts/ui/board_geometry.gd")

const TEX_BG := preload("res://assets/sprites/bg.png")
const TEX_BOARD := preload("res://assets/sprites/board.png")
const TEX_WALL_H := preload("res://assets/sprites/wall_h.png")
const TEX_WALL_V := preload("res://assets/sprites/wall_v.png")
const TEX_PAWN_BLUE := preload("res://assets/sprites/pawn_blue.png")
const TEX_PAWN_ORANGE := preload("res://assets/sprites/pawn_orange.png")

const PAWN_SIZE := 108.0
# 把 Kenney 原始配色往站点 accent 上靠（modulate 是乘法）
const PAWN_TINT := [Color(0.92, 1.00, 1.10), Color(0.98, 0.82, 0.46)]

const ACID := Color(0.247, 0.725, 0.314)
const BLUE := Color(0.345, 0.651, 1.000)
const ORANGE := Color(0.824, 0.600, 0.133)

# 由 main.gd 每回合写入
var state = null
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array = []
var wall_mode: bool = false

var _preview: Dictionary = {}

# main.gd 每次局面或选中状态变化时调用
func show_state(new_state, new_selected: Vector2i, targets: Array, in_wall_mode: bool) -> void:
	state = new_state
	selected = new_selected
	legal_targets = targets
	wall_mode = in_wall_mode
	queue_redraw()

func _draw() -> void:
	# 页面背景（含站点那种顶部绿色微光，已烘进图里）
	draw_texture_rect(TEX_BG, Rect2(0, 0, 960, 1080), false)

	# 棋盘面板
	draw_texture_rect(TEX_BOARD, Rect2(GEO.ORIGIN_CANVAS, Vector2(GEO.CANVAS_PX, GEO.CANVAS_PX)), false)

	# 终点提示：目标行外侧一条阵营色实线 + 极淡底色，第一眼就能看出往哪走
	var row := Vector2(GEO.BOARD_PX, GEO.CELL)
	var edge := Vector2(GEO.BOARD_PX, 3)
	draw_rect(Rect2(GEO.ORIGIN, row), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.09))
	draw_rect(Rect2(GEO.ORIGIN + Vector2(0, 8 * GEO.CELL), row), Color(BLUE.r, BLUE.g, BLUE.b, 0.09))
	draw_rect(Rect2(GEO.ORIGIN, edge), Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.55))
	draw_rect(Rect2(GEO.ORIGIN + Vector2(0, 9 * GEO.CELL - 3), edge), Color(BLUE.r, BLUE.g, BLUE.b, 0.55))

	if state == null:
		return

	# 已放置的墙
	for w in state.placed_walls():
		_draw_wall(w, Color(1, 1, 1, 1))

	# 放墙预览
	if wall_mode and not _preview.is_empty():
		_draw_wall(_preview, Color(1, 1, 1, 0.42))

	# 可走位置：绿色点位（站点 accent）
	for t in legal_targets:
		var c: Vector2 = GEO.cell_center(t)
		draw_circle(c, 13.0, Color(ACID.r, ACID.g, ACID.b, 0.18))
		draw_circle(c, 7.0, Color(ACID.r, ACID.g, ACID.b, 0.62))

	# 棋子（Kenney 贴图 + 剪影投影）
	for i in range(2):
		var c: Vector2 = GEO.cell_center(state.pawns[i])
		var tex: Texture2D = TEX_PAWN_BLUE if i == 0 else TEX_PAWN_ORANGE
		var base := c - Vector2(PAWN_SIZE, PAWN_SIZE) * 0.5

		# 投影：三层逐渐放大、逐层变淡，做出柔和衰减（现代暗色 UI 不要太重）
		draw_texture_rect(tex, Rect2(base + Vector2(5, 9), Vector2(PAWN_SIZE, PAWN_SIZE)), false, Color(0, 0, 0, 0.10))
		draw_texture_rect(tex, Rect2(base + Vector2(7, 12), Vector2(PAWN_SIZE * 1.04, PAWN_SIZE * 1.04)), false, Color(0, 0, 0, 0.07))
		draw_texture_rect(tex, Rect2(base + Vector2(9, 15), Vector2(PAWN_SIZE * 1.09, PAWN_SIZE * 1.09)), false, Color(0, 0, 0, 0.05))

		draw_texture_rect(tex, Rect2(base, Vector2(PAWN_SIZE, PAWN_SIZE)), false, PAWN_TINT[i])

	# 选中框
	if selected != Vector2i(-1, -1):
		draw_rect(GEO.cell_rect(selected), Color(BLUE.r, BLUE.g, BLUE.b, 0.75), false, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if wall_mode:
			_preview = GEO.pick_wall(to_local(event.position))
		else:
			_preview = {}
		queue_redraw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local: Vector2 = to_local(event.position)
		if wall_mode:
			var w: Dictionary = GEO.pick_wall(local)
			if not w.is_empty():
				wall_clicked.emit(w["type"], w["x"], w["y"])
		else:
			var cell: Vector2i = GEO.pick_cell(local)
			if cell.x >= 0:
				cell_clicked.emit(cell)

func _draw_wall(w: Dictionary, tint: Color) -> void:
	var tex: Texture2D = TEX_WALL_H if String(w["type"]) == "wall_h" else TEX_WALL_V
	draw_texture_rect(tex, GEO.wall_rect(w), false, tint)
