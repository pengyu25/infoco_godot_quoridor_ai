# 用例：交给大模型的工具 —— 查看局面 / 试走 / 落子（合法、非法、缺台词、墙用完、未知工具）
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const GT = preload("res://scripts/llm/game_tools.gd")
const P = preload("res://scripts/llm/prompts.gd")

static func run(t) -> void:
	# 蓝方走了 e2，轮到橙方（大模型，me = 1）
	var s = RM.apply(RS.initial(), {"type": "move", "to": Vector2i(4, 1)})
	var before: String = s.to_string_state()

	t.eq(GT.TOOLS.size(), 3, "three tools exposed")
	var board: String = GT.execute(s, 1, "get_board", {})["content"]
	t.check(board.contains("棋子在 e9") and board.contains("可以走到：f9、d9、e8"), "get_board reports position and targets")

	var pv: String = GT.execute(s, 1, "preview_move", {"move": "e8"})["content"]
	t.check(pv.begins_with("合法") and pv.contains("你 7 步（现在 8）"), "preview of a legal step shows distances")
	t.check(GT.execute(s, 1, "preview_move", {"move": "e5"})["content"].contains("走不到"), "preview of an unreachable cell")
	t.check(GT.execute(s, 1, "preview_move", {"move": "zz"})["content"].contains("看不懂"), "preview of malformed text")
	var pw: String = GT.execute(s, 1, "preview_move", {"move": "d2h"})["content"]
	t.check(pw.contains("对手 9 步（现在 7）") or pw.begins_with("合法"), "preview of a wall")

	var ok: Dictionary = GT.execute(s, 1, "make_move", {"move": "e8", "say": "你好"})
	t.eq(ok["move"], {"type": "move", "to": Vector2i(4, 7)}, "make_move returns the parsed move")
	t.eq(ok["say"], "你好", "make_move returns the line")

	t.check(GT.execute(s, 1, "make_move", {"move": "e8", "say": "  "})["move"].is_empty(), "empty say is rejected")
	t.check(GT.execute(s, 1, "make_move", {"move": "e8"})["move"].is_empty(), "missing say is rejected")
	var bad: Dictionary = GT.execute(s, 1, "make_move", {"move": "e5", "say": "嘿"})
	t.check(bad["move"].is_empty() and bad["content"].contains("被拒绝"), "illegal move is rejected with a reason")
	t.check(GT.execute(s, 0, "make_move", {"move": "e3", "say": "嘿"})["content"].contains("不是你的回合"), "wrong side is rejected")

	var long_say: String = "哈".repeat(60)
	t.eq(GT.execute(s, 1, "make_move", {"move": "e8", "say": long_say})["say"].length(), P.MAX_SAY + 1, "long line is clipped")

	var no_walls = s.clone()
	no_walls.walls_left[1] = 0
	t.check(GT.execute(no_walls, 1, "make_move", {"move": "c3h", "say": "嘿"})["content"].contains("用完"), "out of walls")
	t.check(GT.execute(s, 1, "fly", {})["content"].contains("没有叫"), "unknown tool")
	t.eq(s.to_string_state(), before, "tools never change the state")

	t.eq(P.clip_say("  “你好呀”  "), "你好呀", "clip_say strips quotes and spaces")
	t.check(P.system_prompt("大肥鱼", "").contains("你的名字：大肥鱼"), "persona name goes into the system prompt")
	t.check(P.system_prompt("x", "").contains(P.DEFAULT_PERSONA), "empty persona falls back to the default")
