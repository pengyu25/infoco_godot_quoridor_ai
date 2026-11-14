# 规则引擎：合法着法 / 合法性 / 执行 / 胜负。纯逻辑，不引用 UI、Input、OS。
#
# 着法表示（Dictionary，便于序列化与 AI 传递）
#   { "type": "move",   "to": Vector2i }
#   { "type": "wall_h", "x": int, "y": int }   # 横墙：第 y 条横线（1..8）上、从第 x 列（0..7）起
#   { "type": "wall_v", "x": int, "y": int }   # 竖墙：第 x 条竖线（1..8）上、从第 y 行（0..7）起
#
# 放墙部分的实现在 rule_walls.gd，这里保留同名接口做转发（对外接口不变）。
extends RefCounted

const RP = preload("res://scripts/rules/rule_path.gd")
const RW = preload("res://scripts/rules/rule_walls.gd")

const SIZE := 9

# ---- 对外接口 ----

# 当前行动方的全部合法着法
static func legal_moves(state) -> Array:
	var out: Array = pawn_moves(state, state.turn)
	if state.walls_left[state.turn] > 0:
		out.append_array(wall_moves(state, state.turn))
	return out

# 走子着法（含 跳过 与 斜走绕行）
static func pawn_moves(state, player: int) -> Array:
	var out: Array = []
	var p: Vector2i = state.pawns[player]
	var opp: Vector2i = state.pawns[1 - player]

	for d in RP.DIRS:
		var a: Vector2i = p + d
		if not RP.is_in_board(a):
			continue
		if RP.is_step_blocked(state, p, a):
			continue

		if a == opp:
			# 正对对手：优先跳过；越过的格子不可用才允许斜走绕行
			var b: Vector2i = a + d
			var can_jump: bool = RP.is_in_board(b) and b != opp and not RP.is_step_blocked(state, a, b)
			if can_jump:
				out.append({"type": "move", "to": b})
			else:
				for pd in [Vector2i(d.y, -d.x), Vector2i(-d.y, d.x)]:
					var t2: Vector2i = a + pd
					if not RP.is_in_board(t2):
						continue
					if t2 == p or t2 == opp:
						continue
					if _corner_blocked(state, p, t2):
						continue
					out.append({"type": "move", "to": t2})
		else:
			out.append({"type": "move", "to": a})

	return out

# 放墙着法（全部合法位置）
static func wall_moves(state, player: int) -> Array:
	return RW.wall_moves(state, player)

static func is_legal(state, move: Dictionary) -> bool:
	var kind: String = String(move.get("type", ""))
	if kind == "move":
		if not move.has("to"):
			return false
		for m in pawn_moves(state, state.turn):
			if m["to"] == move["to"]:
				return true
		return false
	if kind == "wall_h" or kind == "wall_v":
		if not move.has("x") or not move.has("y"):
			return false
		return is_wall_legal(state, kind, int(move["x"]), int(move["y"]), state.turn)
	return false

# 放墙合法性：越界 / 重叠 / 与异向墙交叉 / 封死任何一方
static func is_wall_legal(state, kind: String, x: int, y: int, player: int) -> bool:
	return RW.is_wall_legal(state, kind, x, y, player)

# 能挡住相邻两格之间这一步的墙位（只算几何，不查合法性）
static func walls_blocking_step(from: Vector2i, to: Vector2i) -> Array:
	return RW.walls_blocking_step(from, to)

# 执行着法：返回新局面（不改传入的 state）
static func apply(state, move: Dictionary) -> RefCounted:
	var s = state.clone()
	var t: int = s.turn

	match String(move.get("type", "")):
		"move":
			s.pawns[t] = move["to"]
		"wall_h":
			RW.put_wall(s, "wall_h", int(move["x"]), int(move["y"]), t)
		"wall_v":
			RW.put_wall(s, "wall_v", int(move["x"]), int(move["y"]), t)

	s.turn = 1 - t
	return s

static func winner(state) -> int:
	if state.pawns[0].y == SIZE - 1:
		return 0
	if state.pawns[1].y == 0:
		return 1
	return -1

# ---- 内部工具 ----

# 斜走绕行是否被墙挡住：对角线穿过「两格共享的格点」，
# 任何一条墙线段压住这个格点（含端点）就算挡住。
static func _corner_blocked(state, a: Vector2i, b: Vector2i) -> bool:
	var px: int = max(a.x, b.x)
	var py: int = max(a.y, b.y)

	for x0 in [px - 2, px - 1, px]:
		if x0 < 0 or x0 > SIZE - 2:
			continue
		if py < 1 or py > SIZE - 1:
			continue
		if state.h_walls[py][x0]:
			return true

	for y0 in [py - 2, py - 1, py]:
		if y0 < 0 or y0 > SIZE - 2:
			continue
		if px < 1 or px > SIZE - 1:
			continue
		if state.v_walls[y0][px]:
			return true

	return false
