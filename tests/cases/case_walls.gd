# 用例：墙 —— 阻挡 / 重叠与交叉 / 墙数用尽 / 封死兜底
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")

static func run(t) -> void:
	_test_wall_blocks(t)
	_test_wall_conflicts(t)
	_test_wall_limit(t)
	_test_bfs_trapped(t)

static func _test_wall_blocks(t) -> void:
	var s = RS.initial()
	# 横墙 line y=1, x=4 → 挡 (4,0)-(4,1) 与 (5,0)-(5,1)
	s.h_walls[1][4] = true
	s.walls_left[0] = 9
	t.eq(RP.is_step_blocked(s, Vector2i(4, 0), Vector2i(4, 1)), true, "h wall blocks (4,0)->(4,1)")
	t.eq(RP.is_step_blocked(s, Vector2i(5, 0), Vector2i(5, 1)), true, "h wall blocks (5,0)->(5,1)")
	t.eq(RP.is_step_blocked(s, Vector2i(3, 0), Vector2i(3, 1)), false, "h wall leaves col 3 open")
	t.eq(RP.shortest_path_len(s, 0), 9, "detour makes p0 path 9")

	var v = RS.initial()
	# 竖墙 line x=4, y=0 → 挡 (3,0)-(4,0) 与 (3,1)-(4,1)
	v.v_walls[0][4] = true
	v.walls_left[0] = 9
	t.eq(RP.is_step_blocked(v, Vector2i(3, 0), Vector2i(4, 0)), true, "v wall blocks (3,0)->(4,0)")
	t.eq(RP.is_step_blocked(v, Vector2i(3, 1), Vector2i(4, 1)), true, "v wall blocks (3,1)->(4,1)")
	t.eq(RP.is_step_blocked(v, Vector2i(4, 0), Vector2i(4, 1)), false, "v wall leaves vertical move open")

static func _test_wall_conflicts(t) -> void:
	var s = RS.initial()
	t.check(RM.is_wall_legal(s, "wall_h", 4, 1, 0), "h(4,1) legal on empty board")

	s.h_walls[1][4] = true
	s.walls_left[0] = 9
	t.check(not RM.is_wall_legal(s, "wall_h", 4, 1, 0), "same wall illegal (overlap)")
	t.check(RM.is_wall_legal(s, "wall_h", 3, 1, 0), "collinear neighbour legal")

	var c = RS.initial()
	c.h_walls[1][2] = true      # 横墙 line1 x2..4
	c.walls_left[0] = 9
	t.check(not RM.is_wall_legal(c, "wall_v", 3, 0, 0), "X crossing illegal")
	t.check(not RM.is_wall_legal(c, "wall_v", 3, 1, 0), "T junction illegal")
	t.check(RM.is_wall_legal(c, "wall_v", 2, 1, 0), "L corner legal")
	t.check(RM.is_wall_legal(c, "wall_v", 5, 0, 0), "far vertical wall legal")

static func _test_wall_limit(t) -> void:
	var s = RS.initial()
	s.walls_left[0] = 0
	t.eq(RM.wall_moves(s, 0).size(), 0, "no wall moves when out of walls")
	t.check(not RM.is_wall_legal(s, "wall_h", 4, 1, 0), "wall illegal when out of walls")
	# 手牌用完仍可走子
	t.check(RM.pawn_moves(s, 0).size() > 0, "pawn can still move")

static func _test_bfs_trapped(t) -> void:
	# 人为构造「被围墙封死」的局面，验证 BFS 兜底（正常对局构造不出来）
	var s = t.new_state(Vector2i(0, 4), Vector2i(8, 8))
	# 把 (0,4) 四周封住
	s.h_walls[4][0] = true      # 挡 (0,3)-(0,4)
	s.h_walls[5][0] = true      # 挡 (0,4)-(0,5)
	s.v_walls[3][1] = true      # 挡 (0,3)-(1,3) 与 (0,4)-(1,4)
	t.eq(RP.shortest_path_len(s, 0), -1, "trapped pawn has no path")
	t.eq(RP.has_path(s, 0), false, "has_path false when trapped")
	t.eq(RP.has_path(s, 1), true, "other player still has a path")
