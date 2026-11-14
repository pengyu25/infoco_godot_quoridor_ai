# headless 测试入口：依次跑 tests/cases/ 下的用例文件
# 运行（在项目根目录）：godot --headless --path . --script tests/run_tests.gd
# 退出码：0 = 全部通过，1 = 有失败
#
# 加用例：在 tests/cases/ 新建 case_xxx.gd（写一个 static func run(t)），再登记到下面的 CASES。
extends SceneTree

const Kit = preload("res://tests/test_kit.gd")

const CASES := [
	preload("res://tests/cases/case_state.gd"),
	preload("res://tests/cases/case_pawn.gd"),
	preload("res://tests/cases/case_walls.gd"),
	preload("res://tests/cases/case_geometry.gd"),
	preload("res://tests/cases/case_queries.gd"),
	preload("res://tests/cases/case_ai.gd"),
]

func _initialize() -> void:
	print("== quoridor tests ==")
	var t = Kit.new()
	for case_script in CASES:
		case_script.run(t)

	print("--------------------------------")
	print("PASS %d  FAIL %d" % [t.passed, t.failed])
	quit(0 if t.failed == 0 else 1)
