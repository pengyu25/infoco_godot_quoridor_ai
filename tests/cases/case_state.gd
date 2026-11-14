# 用例：局面数据 —— 初始局面 / 序列化往返 / apply 不改原局面 / 胜负 / 墙查询接口
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")

static func run(t) -> void:
	_test_initial(t)
	_test_serialization(t)
	_test_apply_immutable(t)
	_test_winner(t)
	_test_placed_walls(t)

static func _test_initial(t) -> void:
	var s = RS.initial()
	t.eq(s.pawns[0], Vector2i(4, 0), "p0 starts at (4,0)")
	t.eq(s.pawns[1], Vector2i(4, 8), "p1 starts at (4,8)")
	t.eq(s.walls_left, [10, 10], "both have 10 walls")
	t.eq(s.turn, 0, "p0 moves first")
	t.eq(RP.shortest_path_len(s, 0), 8, "p0 shortest path is 8")
	t.eq(RP.shortest_path_len(s, 1), 8, "p1 shortest path is 8")

static func _test_serialization(t) -> void:
	var s = RS.initial()
	t.eq(RS.from_string_state(s.to_string_state()).to_string_state(), s.to_string_state(), "roundtrip initial")

	s.h_walls[4][3] = true
	s.v_walls[2][5] = true
	s.walls_left[0] = 8
	s.turn = 1
	var text: String = s.to_string_state()
	var back = RS.from_string_state(text)
	t.eq(back.to_string_state(), text, "roundtrip with walls")
	t.eq(back.h_walls[4][3], true, "h wall parsed")
	t.eq(back.v_walls[2][5], true, "v wall parsed")
	t.eq(back.walls_left[0], 8, "walls_left parsed")
	t.eq(back.turn, 1, "turn parsed")

static func _test_apply_immutable(t) -> void:
	var s = RS.initial()
	var before: String = s.to_string_state()
	var s2 = RM.apply(s, {"type": "move", "to": Vector2i(4, 1)})
	t.eq(s.to_string_state(), before, "apply does not mutate original")
	t.eq(s2.pawns[0], Vector2i(4, 1), "pawn moved")
	t.eq(s2.turn, 1, "turn switched")

static func _test_winner(t) -> void:
	var s = t.new_state(Vector2i(4, 7), Vector2i(0, 8))
	t.eq(RM.winner(s), -1, "no winner yet")
	var s2 = RM.apply(s, {"type": "move", "to": Vector2i(4, 8)})
	t.eq(RM.winner(s2), 0, "p0 wins on reaching row 8")

	var u = t.new_state(Vector2i(0, 0), Vector2i(4, 1))
	u.turn = 1
	var u2 = RM.apply(u, {"type": "move", "to": Vector2i(4, 0)})
	t.eq(RM.winner(u2), 1, "p1 wins on reaching row 0")

# placed_walls()：UI / AI 取墙位置的唯一入口，格式与着法一致
static func _test_placed_walls(t) -> void:
	var s = RS.initial()
	t.eq(s.placed_walls().size(), 0, "no walls on a fresh board")

	var s2 = RM.apply(s, {"type": "wall_v", "x": 2, "y": 3})
	s2 = RM.apply(s2, {"type": "wall_h", "x": 4, "y": 1})
	var walls: Array = s2.placed_walls()
	t.eq(walls.size(), 2, "two walls listed")
	t.eq(walls[0], {"type": "wall_h", "x": 4, "y": 1}, "h walls come first, in move format")
	t.eq(walls[1], {"type": "wall_v", "x": 2, "y": 3}, "v walls follow, in move format")
	t.eq(s2.walls_left, [9, 9], "each player spent one wall")
