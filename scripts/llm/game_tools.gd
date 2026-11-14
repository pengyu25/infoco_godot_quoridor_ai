# 交给大模型的工具：一张工具表（名字 + 描述 + 参数结构，形式与 MCP 工具一致）+ 执行逻辑。
# 纯逻辑，可 headless 测试。大模型只能通过 make_move 落子，每一步都由规则引擎校验，作弊不了。
# 以后想让外部程序（MCP 客户端）连进来下棋，把这张表包装成 MCP 服务器即可，工具本身不用改。
extends RefCounted

const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")
const N = preload("res://scripts/llm/notation.gd")
const P = preload("res://scripts/llm/prompts.gd")

const MOVE_HINT := "走子写目标格，如 e8；墙写左下格加 h 或 v，如 c3h、c3v"

const TOOLS := [
	{"type": "function", "function": {
		"name": "get_board",
		"description": "查看当前局面：双方位置、剩余墙数、离终点还差几步、已放的墙、你能走到的格子和文字棋盘。",
		"parameters": {"type": "object", "properties": {}, "required": []},
	}},
	{"type": "function", "function": {
		"name": "preview_move",
		"description": "试走一步但不真的走：返回是否合法；合法时返回走完后你和对手离终点各差几步。",
		"parameters": {"type": "object", "properties": {
			"move": {"type": "string", "description": MOVE_HINT},
		}, "required": ["move"]},
	}},
	{"type": "function", "function": {
		"name": "make_move",
		"description": "正式走这一步，同时对玩家说一句话。成功后你的回合结束；被拒绝会返回原因。",
		"parameters": {"type": "object", "properties": {
			"move": {"type": "string", "description": MOVE_HINT},
			"say": {"type": "string", "description": "对玩家说的一句话：中文，不超过 40 个字，必填"},
		}, "required": ["move", "say"]},
	}},
]

# 执行一次工具调用。返回 {"content": 给大模型看的结果, "move": 落子成功时的着法否则 {}, "say": 台词}
static func execute(state, me: int, tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_board":
			return _reply(P.board_report(state, me))
		"preview_move":
			return _preview(state, me, str(args.get("move", "")))
		"make_move":
			return _make_move(state, me, str(args.get("move", "")), str(args.get("say", "")))
	return _reply("没有叫 %s 的工具。可用的工具：get_board、preview_move、make_move。" % tool_name)

static func _preview(state, me: int, text: String) -> Dictionary:
	var mv: Dictionary = N.parse_move(text)
	var why: String = _why_illegal(state, me, mv, text)
	if why != "":
		return _reply("不合法：" + why)
	var after = RM.apply(state, mv)
	return _reply("合法。走完后离终点：你 %d 步（现在 %d），对手 %d 步（现在 %d）。" % [
		RP.shortest_path_len(after, me), RP.shortest_path_len(state, me),
		RP.shortest_path_len(after, 1 - me), RP.shortest_path_len(state, 1 - me),
	])

static func _make_move(state, me: int, text: String, say: String) -> Dictionary:
	var mv: Dictionary = N.parse_move(text)
	var why: String = _why_illegal(state, me, mv, text)
	if why != "":
		return _reply("被拒绝：" + why + " 请换一步，再调用 make_move。")
	var line: String = P.clip_say(say)
	if line == "":
		return _reply("被拒绝：say 不能为空，落子的同时要对玩家说一句话。请再调用 make_move。")
	return {"content": "已走 " + N.move_to_text(mv) + "。", "move": mv, "say": line}

# 不合法的原因；合法返回 ""
static func _why_illegal(state, me: int, mv: Dictionary, text: String) -> String:
	if mv.is_empty():
		return "看不懂「%s」。%s。" % [text, MOVE_HINT]
	if state.turn != me:
		return "现在不是你的回合。"
	if RM.is_legal(state, mv):
		return ""
	if String(mv["type"]) == "move":
		var targets: Array = []
		for m in RM.pawn_moves(state, me):
			targets.append(N.cell_to_text(m["to"]))
		return "%s 走不到。你这一步可以走到：%s。" % [text, "、".join(targets)]
	if state.walls_left[me] <= 0:
		return "你的墙已经用完了，只能走子。"
	return "%s 放不了：和已有的墙重叠或交叉，或者会把某一方的路完全堵死。" % text

static func _reply(content: String) -> Dictionary:
	return {"content": content, "move": {}, "say": ""}
