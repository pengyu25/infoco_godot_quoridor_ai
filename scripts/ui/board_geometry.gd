# 棋盘几何：像素坐标 ↔ 格子 / 墙坐标。纯计算，不碰节点，可 headless 测试。
# 尺寸与 tools/bake_board.ps1 烘焙的贴图一一对应 —— 改一边要同步另一边。
# 墙一律用着法同款 Dictionary：{"type": "wall_h" / "wall_v", "x": int, "y": int}
extends RefCounted

const CELL := 92.0                       # 单格边长
const BOARD_PX := 828.0                  # 9 格总宽
const CANVAS_PX := 864.0                 # board.png 边长（棋盘 + 两侧各 18 的边框）
const ORIGIN_CANVAS := Vector2(48, 104)  # board.png 左上角在画面里的位置
const ORIGIN := Vector2(66, 122)         # 第 (0,0) 格左上角 = ORIGIN_CANVAS + 边框 18

const WALL_LONG := 188.0                 # 墙贴图长边（跨 2 格再两头各出 2）
const WALL_THICK := 26.0                 # 墙贴图短边

static func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell.x + 0.5, cell.y + 0.5) * CELL

static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(cell.x, cell.y) * CELL, Vector2(CELL, CELL))

# 像素 → 格子；点在棋盘外返回 (-1, -1)
static func pick_cell(local: Vector2) -> Vector2i:
	var fx: float = (local.x - ORIGIN.x) / CELL
	var fy: float = (local.y - ORIGIN.y) / CELL
	if fx < 0.0 or fy < 0.0 or fx >= 9.0 or fy >= 9.0:
		return Vector2i(-1, -1)
	return Vector2i(int(floor(fx)), int(floor(fy)))

# 像素 → 墙：找最近的格线，横线（横墙）还是竖线（竖墙），谁近选谁；离棋盘太远返回 {}
static func pick_wall(local: Vector2) -> Dictionary:
	var fx: float = (local.x - ORIGIN.x) / CELL
	var fy: float = (local.y - ORIGIN.y) / CELL
	if fx < -0.5 or fy < -0.5 or fx > 9.5 or fy > 9.5:
		return {}

	var near_y: int = int(round(fy))
	var near_x: int = int(round(fx))
	var dh: float = abs(fy - near_y)
	var dv: float = abs(fx - near_x)

	if dh <= dv:
		return {
			"type": "wall_h",
			"x": clampi(int(floor(fx)), 0, 7),
			"y": clampi(near_y, 1, 8),
		}

	return {
		"type": "wall_v",
		"x": clampi(near_x, 1, 8),
		"y": clampi(int(floor(fy)), 0, 7),
	}

# 墙 → 贴图矩形（墙压在格线正中，所以短边方向往回退半个厚度）
static func wall_rect(w: Dictionary) -> Rect2:
	var at: Vector2 = ORIGIN + Vector2(float(w["x"]), float(w["y"])) * CELL
	if String(w["type"]) == "wall_h":
		return Rect2(at + Vector2(-2.0, -WALL_THICK * 0.5), Vector2(WALL_LONG, WALL_THICK))
	return Rect2(at + Vector2(-WALL_THICK * 0.5, -2.0), Vector2(WALL_THICK, WALL_LONG))
