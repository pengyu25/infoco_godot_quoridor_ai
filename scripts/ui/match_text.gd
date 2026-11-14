# 对局文案：双方显示名、顶部回合提示、结算提示。纯函数，由 main.gd 调用。
#   ai_name：对手的显示名；"" = 双人对战，"电脑·中" = 本地电脑，角色名 = 大模型
#   ai_side：人机模式下对手执哪一方（0 蓝 / 1 橙）
extends RefCounted

static func player_name(ai_name: String, player: int, ai_side: int) -> String:
	if ai_name == "":
		return "玩家%d" % (player + 1)
	if player == ai_side:
		return ai_name
	return "你"

# 双方显示名 [蓝, 橙]
static func names(ai_name: String, ai_side: int) -> Array:
	return [player_name(ai_name, 0, ai_side), player_name(ai_name, 1, ai_side)]

# 对局进行中（还没分胜负）时顶部那行字
static func turn_text(ai_name: String, turn: int, ai_side: int) -> String:
	if ai_name == "":
		return "玩家 %d 回合" % (turn + 1)
	if turn == ai_side:
		return ai_name + "思考中…"
	return "你的回合"

# 顶部那行字与颜色：[文字, 阵营色下标（-1 = 中性白）]
static func header(ai_name: String, turn: int, ai_side: int, in_menu: bool, is_over: bool) -> Array:
	if in_menu:
		return ["步步为营", -1]
	if is_over:
		return ["对局结束", -1]
	return [turn_text(ai_name, turn, ai_side), turn]

static func result_text(ai_name: String, winner: int, ai_side: int) -> String:
	if ai_name == "":
		return "玩家 %d 获胜！点「重开一局」再来" % (winner + 1)
	if winner == ai_side:
		return ai_name + "获胜，点「重开一局」再来"
	return "你赢了！点「重开一局」再来"

# 对手落子后给人的提示
static func ai_moved_text(ai_name: String, move: Dictionary) -> String:
	if String(move["type"]) == "move":
		return ai_name + "走了一步，轮到你"
	return ai_name + "放了一堵墙，轮到你"

# 没选中棋子就点了别处时的提示
static func pick_pawn_hint(ai_name: String, ai_side: int) -> String:
	var n: Array = names(ai_name, ai_side)
	return "先点自己的棋子（蓝=%s，橙=%s）" % [n[0], n[1]]
