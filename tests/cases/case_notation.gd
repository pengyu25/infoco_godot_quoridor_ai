# 用例：记谱法 —— 格子 / 墙文字往返、墙的实际阻挡方向、看不懂的写法、文字棋盘
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")
const N = preload("res://scripts/llm/notation.gd")

static func run(t) -> void:
	_test_round_trips(t)
	_test_wall_meaning(t)
	_test_rejects(t)
	_test_board_ascii(t)

static func _test_round_trips(t) -> void:
	t.eq(N.cell_to_text(Vector2i(4, 0)), "e1", "blue start is e1")
	t.eq(N.cell_to_text(Vector2i(4, 8)), "e9", "orange start is e9")
	var ok: bool = true
	for y in range(9):
		for x in range(9):
			if N.parse_cell(N.cell_to_text(Vector2i(x, y))) != Vector2i(x, y):
				ok = false
	t.check(ok, "all 81 cells round-trip")

	var walls_ok: bool = true
	for y in range(1, 9):
		for x in range(0, 8):
			var h: Dictionary = {"type": "wall_h", "x": x, "y": y}
			if N.parse_move(N.move_to_text(h)) != h:
				walls_ok = false
	for x in range(1, 9):
		for y in range(0, 8):
			var v: Dictionary = {"type": "wall_v", "x": x, "y": y}
			if N.parse_move(N.move_to_text(v)) != v:
				walls_ok = false
	t.check(walls_ok, "all 128 wall positions round-trip")
	t.eq(N.parse_move(" E2 "), {"type": "move", "to": Vector2i(4, 1)}, "case and spaces are tolerated")

# 提示词里写的「c3h 挡住 c3↔c4、d3↔d4」「c3v 挡住 c3↔d3、c4↔d4」必须和规则引擎一致
static func _test_wall_meaning(t) -> void:
	var s = RS.initial()
	var h = RM.apply(s, N.parse_move("c3h"))
	t.check(_blocked(h, "c3", "c4") and _blocked(h, "d3", "d4"), "c3h blocks c3-c4 and d3-d4")
	t.check(not _blocked(h, "c3", "d3") and not _blocked(h, "e3", "e4"), "c3h blocks nothing else nearby")
	var v = RM.apply(s, N.parse_move("c3v"))
	t.check(_blocked(v, "c3", "d3") and _blocked(v, "c4", "d4"), "c3v blocks c3-d3 and c4-d4")
	t.check(not _blocked(v, "c3", "c4") and not _blocked(v, "c5", "d5"), "c3v blocks nothing else nearby")

static func _blocked(s, a: String, b: String) -> bool:
	return RP.is_step_blocked(s, N.parse_cell(a), N.parse_cell(b))

static func _test_rejects(t) -> void:
	var bad: Array = ["", "e", "e0", "j5", "e10", "i3h", "a9h", "c3x", "e3hh", "33"]
	var all_empty: bool = true
	for text in bad:
		if not N.parse_move(text).is_empty():
			all_empty = false
			print("    unexpectedly parsed: ", text)
	t.check(all_empty, "malformed notation is rejected")

static func _test_board_ascii(t) -> void:
	var s = RM.apply(RS.initial(), N.parse_move("c3h"))
	var lines: PackedStringArray = N.board_ascii(s).split("\n")
	t.eq(lines.size(), 18, "header + 9 rows + 8 wall lines")
	t.eq(lines[1].left(1), "9", "rank 9 is printed first")
	t.eq(lines[1].find("O"), 11, "orange pawn shown at e9")
	t.eq(lines[17].find("B"), 11, "blue pawn shown at e1")
	# 第 4 行与第 3 行之间那条线：c、d 两列下面是 -
	t.eq(lines[12].strip_edges(), "- -", "c3h drawn under c4 and d4")
	t.eq(lines[12].find("-"), 7, "c3h starts under column c")
