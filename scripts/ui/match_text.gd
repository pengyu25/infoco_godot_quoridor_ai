# 对局文案：双方显示名、顶部回合提示、结算提示。纯函数，由 main.gd 调用。
#   level：""= 双人对战，否则是 difficulty.gd 里的档位名
#   ai_side：人机模式下电脑执哪一方（0 蓝 / 1 橙）
extends RefCounted

const DIFF = preload("res://scripts/ai/difficulty.gd")

static func player_name(level: String, player: int, ai_side: int) -> String:
	if level == "":
		return "玩家%d" % (player + 1)
	if player == ai_side:
		return "电脑·" + DIFF.label_of(level)
	return "你"

# 双方显示名 [蓝, 橙]
static func names(level: String, ai_side: int) -> Array:
	return [player_name(level, 0, ai_side), player_name(level, 1, ai_side)]

# 顶部那行字与颜色：[文字, 阵营色下标（-1 = 中性白）]
static func header(level: String, turn: int, ai_side: int, in_menu: bool, is_over: bool) -> Array:
	if in_menu:
		return ["步步为营", -1]
	if is_over:
		return ["对局结束", -1]
	return [turn_text(level, turn, ai_side), turn]

# 没选中棋子就点了别处时的提示
static func pick_pawn_hint(level: String, ai_side: int) -> String:
	var n: Array = names(level, ai_side)
	return "先点自己的棋子（蓝=%s，橙=%s）" % [n[0], n[1]]

# 对局进行中（还没分胜负）时顶部那行字
static func turn_text(level: String, turn: int, ai_side: int) -> String:
	if level == "":
		return "玩家 %d 回合" % (turn + 1)
	if turn == ai_side:
		return "电脑思考中…"
	return "你的回合"

static func result_text(level: String, winner: int, ai_side: int) -> String:
	if level == "":
		return "玩家 %d 获胜！点「重开一局」再来" % (winner + 1)
	if winner == ai_side:
		return "电脑获胜，点「重开一局」再来"
	return "你赢了！点「重开一局」再来"

# 电脑落子后给人的提示
static func ai_moved_text(move: Dictionary) -> String:
	if String(move["type"]) == "move":
		return "电脑走了一步，轮到你"
	return "电脑放了一堵墙，轮到你"
