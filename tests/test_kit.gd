# 测试小工具：通过/失败计数 + 断言 + 造局面。
# run_tests.gd 建一个实例，依次传给 tests/cases/ 下每个用例文件的 run(t)。
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")

var passed: int = 0
var failed: int = 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", msg)

func eq(actual, expected, msg: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [msg, str(expected), str(actual)])

func has_move(moves: Array, cell: Vector2i) -> bool:
	for m in moves:
		if m["type"] == "move" and m["to"] == cell:
			return true
	return false

# 空棋盘 + 指定双方棋子位置
func new_state(p0: Vector2i, p1: Vector2i) -> RefCounted:
	var s = RS.initial()
	s.pawns[0] = p0
	s.pawns[1] = p1
	return s
