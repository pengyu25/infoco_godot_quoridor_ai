# 用例：走子 —— 直走 / 跳过对手 / 斜走绕行
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")

static func run(t) -> void:
	_test_pawn_moves(t)
	_test_jump_and_diagonal(t)

static func _test_pawn_moves(t) -> void:
	var s = RS.initial()
	var moves: Array = RM.pawn_moves(s, 0)
	t.eq(moves.size(), 3, "3 pawn moves at start")
	t.check(t.has_move(moves, Vector2i(4, 1)), "forward (4,1)")
	t.check(t.has_move(moves, Vector2i(3, 0)), "left (3,0)")
	t.check(t.has_move(moves, Vector2i(5, 0)), "right (5,0)")
	t.check(not t.has_move(moves, Vector2i(4, 2)), "no two-step move")
	t.check(not t.has_move(moves, Vector2i(3, 1)), "no diagonal without opponent")

static func _test_jump_and_diagonal(t) -> void:
	# 正对对手，越过格空着 → 可以跳
	var s = t.new_state(Vector2i(4, 0), Vector2i(4, 1))
	var moves: Array = RM.pawn_moves(s, 0)
	t.check(t.has_move(moves, Vector2i(4, 2)), "can jump over opponent")
	t.check(not t.has_move(moves, Vector2i(4, 1)), "cannot move onto opponent")
	t.check(not t.has_move(moves, Vector2i(3, 1)), "no diagonal when jump is available")

	# 越过格被墙挡住 → 改为斜走绕行
	var d = t.new_state(Vector2i(4, 0), Vector2i(4, 1))
	d.h_walls[2][3] = true      # 挡 (4,1)-(4,2) 与 (3,1)-(3,2)
	d.walls_left[0] = 9
	var dm: Array = RM.pawn_moves(d, 0)
	t.check(not t.has_move(dm, Vector2i(4, 2)), "jump blocked by wall")
	t.check(t.has_move(dm, Vector2i(3, 1)) or t.has_move(dm, Vector2i(5, 1)), "diagonal detour available")
