# 用例：AI 用到的两个只读查询 —— shortest_path（最短路线）/ walls_blocking_step（挡某一步的墙位）
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")

static func run(t) -> void:
	_test_shortest_path(t)
	_test_walls_blocking_step(t)

# 路线的通用性质：长度与 shortest_path_len 一致、从棋子出发、到终点线、每步都没被墙挡
static func _check_path(t, s, player: int, label: String) -> void:
	var path: Array = RP.shortest_path(s, player)
	t.eq(path.size() - 1, RP.shortest_path_len(s, player), label + ": length matches shortest_path_len")
	t.eq(path[0], s.pawns[player], label + ": starts at the pawn")
	var goal_row: int = 8 if player == 0 else 0
	t.eq(path[path.size() - 1].y, goal_row, label + ": ends on the goal row")
	var open: bool = true
	for i in range(path.size() - 1):
		if RP.is_step_blocked(s, path[i], path[i + 1]):
			open = false
	t.check(open, label + ": every step is open")

static func _test_shortest_path(t) -> void:
	var s = RS.initial()
	_check_path(t, s, 0, "p0 empty board")
	_check_path(t, s, 1, "p1 empty board")

	# 双方门口各挡一堵墙 → 都要绕 1 步
	var w = RM.apply(s, {"type": "wall_h", "x": 3, "y": 1})    # 挡 (3,0)/(4,0) 往下
	w = RM.apply(w, {"type": "wall_h", "x": 3, "y": 8})        # 挡 (3,8)/(4,8) 往上（不碍蓝方走第 5 列）
	_check_path(t, w, 0, "p0 with walls")
	_check_path(t, w, 1, "p1 with walls")
	t.eq(RP.shortest_path(w, 0).size() - 1, 9, "p0 detour path has 9 steps")

	var at_goal = t.new_state(Vector2i(2, 8), Vector2i(4, 4))
	t.eq(RP.shortest_path(at_goal, 0), [Vector2i(2, 8)], "already on goal row -> [start]")

	var trapped = t.new_state(Vector2i(0, 4), Vector2i(8, 8))
	trapped.h_walls[4][0] = true
	trapped.h_walls[5][0] = true
	trapped.v_walls[3][1] = true
	t.eq(RP.shortest_path(trapped, 0), [], "trapped pawn -> []")

static func _test_walls_blocking_step(t) -> void:
	# [起点, 终点, 期望墙数]：中间 2 个，贴边 1 个
	var cases: Array = [
		[Vector2i(4, 4), Vector2i(4, 5), 2],
		[Vector2i(4, 5), Vector2i(4, 4), 2],
		[Vector2i(4, 4), Vector2i(5, 4), 2],
		[Vector2i(5, 4), Vector2i(4, 4), 2],
		[Vector2i(0, 2), Vector2i(0, 3), 1],
		[Vector2i(8, 2), Vector2i(8, 3), 1],
		[Vector2i(3, 0), Vector2i(4, 0), 1],
		[Vector2i(3, 8), Vector2i(4, 8), 1],
	]
	for c in cases:
		var a: Vector2i = c[0]
		var b: Vector2i = c[1]
		var walls: Array = RM.walls_blocking_step(a, b)
		var label: String = "%s->%s" % [str(a), str(b)]
		t.eq(walls.size(), c[2], label + ": wall count")
		var all_block: bool = true
		for w in walls:
			var s = RS.initial()
			if not RM.is_legal(s, w):
				all_block = false
				continue
			if not RP.is_step_blocked(RM.apply(s, w), a, b):
				all_block = false
		t.check(all_block, label + ": every wall is legal on an empty board and blocks the step")

	t.eq(RM.walls_blocking_step(Vector2i(4, 4), Vector2i(4, 6)), [], "two cells apart -> []")
	t.eq(RM.walls_blocking_step(Vector2i(4, 4), Vector2i(5, 5)), [], "diagonal -> []")
	t.eq(RM.walls_blocking_step(Vector2i(4, 8), Vector2i(4, 9)), [], "off the board -> []")
