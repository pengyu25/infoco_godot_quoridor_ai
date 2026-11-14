# 坐标记谱：内部坐标 ↔ 给大模型看的文字（格子 e2、横墙 c3h、竖墙 c3v），以及文字棋盘。
# 行号 = 内部 y + 1（蓝方起点 e1，橙方起点 e9）。墙写成「墙左下方那一格 + h / v」：
#   c3h = 挡住 c3↔c4、d3↔d4 的横墙 = 内部 {"type": "wall_h", "x": 2, "y": 3}
#   c3v = 挡住 c3↔d3、c4↔d4 的竖墙 = 内部 {"type": "wall_v", "x": 3, "y": 2}
extends RefCounted

const RP = preload("res://scripts/rules/rule_path.gd")

const COLS := "abcdefghi"

static func cell_to_text(c: Vector2i) -> String:
	return COLS[c.x] + str(c.y + 1)

# 解析格子；看不懂返回 (-1, -1)
static func parse_cell(text: String) -> Vector2i:
	var s: String = text.strip_edges().to_lower()
	if s.length() != 2 or not s[1].is_valid_int():
		return Vector2i(-1, -1)
	var col: int = COLS.find(s[0])
	var row: int = int(s[1])
	if col < 0 or row < 1 or row > 9:
		return Vector2i(-1, -1)
	return Vector2i(col, row - 1)

static func move_to_text(m: Dictionary) -> String:
	match String(m.get("type", "")):
		"move":
			return cell_to_text(m["to"])
		"wall_h":
			return COLS[int(m["x"])] + str(int(m["y"])) + "h"
		"wall_v":
			return COLS[int(m["x"]) - 1] + str(int(m["y"]) + 1) + "v"
	return "?"

# 解析着法文字；看不懂返回 {}（合不合法另由规则引擎判断）
static func parse_move(text: String) -> Dictionary:
	var s: String = text.strip_edges().to_lower()
	if s.length() == 2:
		var c: Vector2i = parse_cell(s)
		if c.x >= 0:
			return {"type": "move", "to": c}
		return {}
	if s.length() != 3 or not s[1].is_valid_int():
		return {}
	var col: int = COLS.find(s[0])
	var rank: int = int(s[1])
	if col < 0 or col > 7 or rank < 1 or rank > 8:
		return {}
	if s[2] == "h":
		return {"type": "wall_h", "x": col, "y": rank}
	if s[2] == "v":
		return {"type": "wall_v", "x": col + 1, "y": rank - 1}
	return {}

# 「走到 e3」「放了横墙 c3h」——给大模型描述玩家上一步
static func describe(m: Dictionary) -> String:
	match String(m.get("type", "")):
		"move":
			return "走到 " + move_to_text(m)
		"wall_h":
			return "放了横墙 " + move_to_text(m)
		"wall_v":
			return "放了竖墙 " + move_to_text(m)
	return "未知着法"

# 文字棋盘：第 9 行在上；B = 蓝方棋子，O = 橙方棋子；格子之间的 | 是竖墙，行之间的 - 是横墙
static func board_ascii(state) -> String:
	var out: Array = ["   a b c d e f g h i"]
	for y in range(8, -1, -1):
		var row: String = "%d  " % (y + 1)
		for x in range(9):
			row += _cell_char(state, Vector2i(x, y))
			if x < 8:
				row += "|" if RP.is_step_blocked(state, Vector2i(x, y), Vector2i(x + 1, y)) else " "
		out.append(row)
		if y > 0:
			var line: String = "   "
			for x in range(9):
				line += "-" if RP.is_step_blocked(state, Vector2i(x, y), Vector2i(x, y - 1)) else " "
				if x < 8:
					line += " "
			out.append(line.rstrip(" "))
	return "\n".join(out)

static func _cell_char(state, c: Vector2i) -> String:
	if c == state.pawns[0]:
		return "B"
	if c == state.pawns[1]:
		return "O"
	return "."
