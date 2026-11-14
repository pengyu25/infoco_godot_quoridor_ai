# headless 测试入口：依次跑 tests/cases/ 下的用例文件
# 运行（在项目根目录）：godot --headless --path . --script tests/run_tests.gd
# 退出码：0 = 全部通过，1 = 有失败
#
# 加用例：在 tests/cases/ 新建 case_xxx.gd（写一个 static func run(t)），再登记到下面的 CASES。
# 需要等信号的用例（例如假客户端）写成实例方法 func run(t) 并用 await，登记到 ASYNC_CASES。
extends SceneTree

const Kit = preload("res://tests/test_kit.gd")

const CASES := [
	preload("res://tests/cases/case_state.gd"),
	preload("res://tests/cases/case_pawn.gd"),
	preload("res://tests/cases/case_walls.gd"),
	preload("res://tests/cases/case_geometry.gd"),
	preload("res://tests/cases/case_queries.gd"),
	preload("res://tests/cases/case_ai.gd"),
	preload("res://tests/cases/case_notation.gd"),
	preload("res://tests/cases/case_game_tools.gd"),
	preload("res://tests/cases/case_settings.gd"),
]

const ASYNC_CASES := [
	preload("res://tests/cases/case_llm_agent.gd"),
]

func _initialize() -> void:
	_run_all()

func _run_all() -> void:
	print("== quoridor tests ==")
	var t = Kit.new()
	for case_script in CASES:
		case_script.run(t)
	for case_script in ASYNC_CASES:
		# 异步用例跑完必须返回 true；中途脚本出错会返回别的值，这里记为失败
		var finished = await case_script.new().run(t)
		t.check(finished == true, "%s ran to the end" % case_script.resource_path.get_file())

	print("--------------------------------")
	print("PASS %d  FAIL %d" % [t.passed, t.failed])
	quit(0 if t.failed == 0 else 1)
