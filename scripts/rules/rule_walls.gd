# 放墙规则：合法位置枚举 / 合法性 / 落墙。纯逻辑，不引用 UI、Input、OS。
#
# 调用方请走 rule_moves.gd 的同名接口（wall_moves / is_wall_legal）——
# 这个文件是它们的实现，单独拆出来只是为了守住「单文件 ≤150 行」。
# 墙的坐标与几何定义见 rule_state.gd 顶部注释。
extends RefCounted

const RP = preload("res://scripts/rules/rule_path.gd")

const SIZE := 9

# 放墙着法（全部合法位置）
static func wall_moves(state, player: int) -> Array:
	var out: Array = []
	if state.walls_left[player] <= 0:
		return out

	# 横墙：第 1..8 条横线，起点列 0..7
	for y in range(1, SIZE):
		for x in range(0, SIZE - 1):
			if is_wall_legal(state, "wall_h", x, y, player):
				out.append({"type": "wall_h", "x": x, "y": y})

	# 竖墙：第 1..8 条竖线，起点行 0..7
	for x in range(1, SIZE):
		for y in range(0, SIZE - 1):
			if is_wall_legal(state, "wall_v", x, y, player):
				out.append({"type": "wall_v", "x": x, "y": y})

	return out

# 放墙合法性：越界 / 重叠 / 与异向墙交叉 / 封死任何一方
static func is_wall_legal(state, kind: String, x: int, y: int, player: int) -> bool:
	if state.walls_left[player] <= 0:
		return false

	if kind == "wall_h":
		if y < 1 or y > SIZE - 1 or x < 0 or x > SIZE - 2:
			return false
		if state.h_walls[y][x]:
			return false
		if _h_conflicts(state, y, x):
			return false
	else:
		if x < 1 or x > SIZE - 1 or y < 0 or y > SIZE - 2:
			return false
		if state.v_walls[y][x]:
			return false
		if _v_conflicts(state, x, y):
			return false

	# 兜底：放墙后双方都必须还能走到终点（标准规则）
	var probe = state.clone()
	put_wall(probe, kind, x, y, player)
	return RP.shortest_path_len(probe, 0) >= 0 and RP.shortest_path_len(probe, 1) >= 0

# 把墙落到 state 上并扣墙数（直接改传入的 state，调用方负责先 clone）
static func put_wall(state, kind: String, x: int, y: int, player: int) -> void:
	if kind == "wall_h":
		state.h_walls[y][x] = true
	else:
		state.v_walls[y][x] = true
	state.walls_left[player] -= 1

# ---- 内部工具 ----

# 两面垂直墙是否冲突：共享点必须是「双方的端点」（L 形拐角）才允许；
# T 形（一端顶在另一面中间）与 X 形（十字交叉）都非法。
static func _crosses(h_y: int, h_x: int, v_y: int, v_x: int) -> bool:
	if v_x < h_x or v_x > h_x + 2:
		return false
	if h_y < v_y or h_y > v_y + 2:
		return false
	var h_end: bool = (v_x == h_x or v_x == h_x + 2)
	var v_end: bool = (h_y == v_y or h_y == v_y + 2)
	return not (h_end and v_end)

# 放横墙 h(y, x) 时，检查附近的竖墙
static func _h_conflicts(state, h_y: int, h_x: int) -> bool:
	for v_x in [h_x, h_x + 1, h_x + 2]:
		if v_x < 1 or v_x > SIZE - 1:
			continue
		for v_y in [h_y - 2, h_y - 1, h_y]:
			if v_y < 0 or v_y > SIZE - 2:
				continue
			if state.v_walls[v_y][v_x] and _crosses(h_y, h_x, v_y, v_x):
				return true
	return false

# 放竖墙 v(x, y) 时，检查附近的横墙
static func _v_conflicts(state, v_x: int, v_y: int) -> bool:
	for h_y in [v_y, v_y + 1, v_y + 2]:
		if h_y < 1 or h_y > SIZE - 1:
			continue
		for h_x in [v_x - 2, v_x - 1, v_x]:
			if h_x < 0 or h_x > SIZE - 2:
				continue
			if state.h_walls[h_y][h_x] and _crosses(h_y, h_x, v_y, v_x):
				return true
	return false
