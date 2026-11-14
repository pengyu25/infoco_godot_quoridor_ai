# 搜索：逐层加深 + negamax + alpha-beta 剪枝。
#   negamax：分数永远站在「当前行动方」看，子局面的分取负数就是父局面的分
#   逐层加深：先算 1 层、再 2 层……超过思考上限就停，用最后一层完整算完的结果
#             —— 机器慢时自动少看一层，而不是卡得更久
extends RefCounted

const RM = preload("res://scripts/rules/rule_moves.gd")
const AE = preload("res://scripts/ai/ai_eval.gd")
const AC = preload("res://scripts/ai/ai_candidates.gd")

const INF := 1000000000

# 返回 {"moves": 根着法（好的在前）, "scores": 对应分数, "depth": 完整算完的层数, "nodes": 访问节点数}
# exact_root = true：每个根着法都算精确分（要从次优里挑时用）；false：根节点也剪枝，更快，
#                    但除第一名外的分数只是上界
static func search(state, preset: Dictionary, exact_root: bool) -> Dictionary:
	var ctx: Dictionary = {
		"deadline": Time.get_ticks_msec() + int(preset["time_budget_ms"]),
		"can_abort": false,
		"aborted": false,
		"nodes": 0,
		"preset": preset,
	}
	var moves: Array = AC.generate(state, preset)
	var result: Dictionary = {"moves": moves, "scores": [], "depth": 0, "nodes": 0}

	for depth in range(1, int(preset["search_depth"]) + 1):
		ctx["can_abort"] = depth > 1          # 第 1 层必定算完，保证总有结果
		var scored: Array = _search_root(state, moves, depth, exact_root, ctx)
		if ctx["aborted"]:
			break
		AC.sort_desc(scored)                  # 同分保持原顺序 → 本层最佳一定排第一
		moves = []
		var scores: Array = []
		for item in scored:
			moves.append(item[1])
			scores.append(item[0])
		result = {"moves": moves, "scores": scores, "depth": depth, "nodes": 0}

	result["nodes"] = ctx["nodes"]
	return result

# 根节点：逐个试根着法，返回 [分数, 着法] 列表（顺序同 moves）
static func _search_root(state, moves: Array, depth: int, exact_root: bool, ctx: Dictionary) -> Array:
	var scored: Array = []
	var alpha: int = -INF
	for m in moves:
		var child_beta: int = INF if exact_root else -alpha
		var v: int = -_negamax(RM.apply(state, m), depth - 1, -INF, child_beta, ctx)
		if ctx["aborted"]:
			return scored
		scored.append([v, m])
		if v > alpha:
			alpha = v
	return scored

static func _negamax(state, depth: int, alpha: int, beta: int, ctx: Dictionary) -> int:
	ctx["nodes"] += 1

	# 已分胜负：剩余层数越多 = 胜负来得越早，赢家更想早赢、输家更想晚输
	var w: int = RM.winner(state)
	if w != -1:
		var s: int = AE.WIN + depth
		return s if w == state.turn else -s

	if depth <= 0:
		return AE.evaluate(state, state.turn, ctx["preset"])

	if ctx["can_abort"] and Time.get_ticks_msec() > int(ctx["deadline"]):
		ctx["aborted"] = true
		return 0

	var best: int = -INF
	for m in AC.generate(state, ctx["preset"]):
		var v: int = -_negamax(RM.apply(state, m), depth - 1, -beta, -alpha, ctx)
		if ctx["aborted"]:
			return 0
		if v > best:
			best = v
		if v > alpha:
			alpha = v
		if alpha >= beta:
			break                             # 对手不会让局面走到这里，剩下的不用试了
	return best
