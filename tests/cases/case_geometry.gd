# 用例：棋盘几何 —— 像素 ↔ 格子 / 墙坐标（scripts/ui/board_geometry.gd，纯计算可 headless 测）
extends RefCounted

const GEO = preload("res://scripts/ui/board_geometry.gd")

static func run(t) -> void:
	# 格子：中心点能换回同一格；棋盘外返回 (-1,-1)
	t.eq(GEO.pick_cell(GEO.cell_center(Vector2i(4, 0))), Vector2i(4, 0), "centre of (4,0) picks (4,0)")
	t.eq(GEO.pick_cell(GEO.cell_center(Vector2i(8, 8))), Vector2i(8, 8), "centre of (8,8) picks (8,8)")
	t.eq(GEO.pick_cell(Vector2(0, 0)), Vector2i(-1, -1), "outside the board picks nothing")

	# 墙：靠近哪条格线就选哪种墙
	var on_h_line: Vector2 = GEO.ORIGIN + Vector2(4.5, 4.0) * GEO.CELL
	t.eq(GEO.pick_wall(on_h_line), {"type": "wall_h", "x": 4, "y": 4}, "point on h line 4 picks wall_h")
	var on_v_line: Vector2 = GEO.ORIGIN + Vector2(4.0, 0.4) * GEO.CELL
	t.eq(GEO.pick_wall(on_v_line), {"type": "wall_v", "x": 4, "y": 0}, "point on v line 4 picks wall_v")
	t.eq(GEO.pick_wall(Vector2(-500, -500)), {}, "far outside picks no wall")

	# 贴边：最外侧的格线上不能放墙，要夹回 1..8 / 0..7
	var top_edge: Vector2 = GEO.ORIGIN + Vector2(8.6, 0.05) * GEO.CELL
	t.eq(GEO.pick_wall(top_edge), {"type": "wall_h", "x": 7, "y": 1}, "edge click clamps into range")

	# 墙贴图矩形：压在格线正中、跨两格
	var h_rect: Rect2 = GEO.wall_rect({"type": "wall_h", "x": 4, "y": 4})
	t.eq(h_rect, Rect2(432, 477, 188, 26), "wall_h rect")
	var v_rect: Rect2 = GEO.wall_rect({"type": "wall_v", "x": 4, "y": 0})
	t.eq(v_rect, Rect2(421, 120, 26, 188), "wall_v rect")
