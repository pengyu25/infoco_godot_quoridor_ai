# 电脑对手入口：给局面和难度参数，返回一步棋（着法 Dictionary，格式同技术骨架第 4 节）。
# 只用规则引擎第 5 节接口；不修改传入的 state。难度参数见 difficulty.gd。
#
# 用法：
#   const AI = preload("res://scripts/ai/ai_player.gd")
#   const DIFF = preload("res://scripts/ai/difficulty.gd")
#   var mv: Dictionary = AI.choose_move(state, DIFF.get_preset("hard"), rng)
extends RefCounted

const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")
const AE = preload("res://scripts/ai/ai_eval.gd")
const AS = preload("res://scripts/ai/ai_search.gd")

# rng 传 null 则每次随机；测试 / 回放想复现就传一个固定种子的 RandomNumberGenerator
static func choose_move(state, preset: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	return think(state, preset, rng)["move"]

# 同 choose_move，另外带回统计：{"move", "depth": 搜到几层, "nodes": 节点数, "ms": 用时}
static func think(state, preset: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var t0: int = Time.get_ticks_msec()
	var info: Dictionary = {"move": {}, "depth": 0, "nodes": 0, "ms": 0}

	var win: Dictionary = _winning_step(state)
	if not win.is_empty():
		info["move"] = win                    # 一步能赢就赢，哪一档都不放过
	elif int(preset["search_depth"]) <= 0:
		info["move"] = _greedy(state, preset, rng)
	else:
		var r: Dictionary = AS.search(state, preset, float(preset["random"]) > 0.0)
		info["move"] = _pick(r, preset, rng)
		info["depth"] = r["depth"]
		info["nodes"] = r["nodes"]

	info["ms"] = Time.get_ticks_msec() - t0
	return info

# 能直接走到终点的一步；没有返回 {}
static func _winning_step(state) -> Dictionary:
	for m in RM.pawn_moves(state, state.turn):
		if RM.winner(RM.apply(state, m)) == state.turn:
			return m
	return {}

# 低难度：不往后看，挑走完离终点最近的一步（同样近就随机挑）；有 random 概率随便走
static func _greedy(state, preset: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var moves: Array = RM.pawn_moves(state, state.turn)
	if moves.is_empty():
		return RM.legal_moves(state)[0]       # 标准规则下不会发生，兜底
	if rng.randf() < float(preset["random"]):
		return moves[rng.randi_range(0, moves.size() - 1)]

	var best: Array = []
	var best_d: int = 1 << 30
	for m in moves:
		var d: int = RP.shortest_path_len(RM.apply(state, m), state.turn)
		if d < best_d:
			best_d = d
			best = [m]
		elif d == best_d:
			best.append(m)
	return best[rng.randi_range(0, best.size() - 1)]

# 从搜索结果挑一步：通常取第一名；有 random 概率改取第二名，
# 但只在第二名比第一名差不到一步、且第一名不是必胜时（别把赢棋送掉）
static func _pick(r: Dictionary, preset: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var moves: Array = r["moves"]
	var scores: Array = r["scores"]
	if moves.size() >= 2 and scores.size() >= 2 and scores[0] < AE.WIN / 2:
		var close_enough: bool = scores[1] >= scores[0] - AE.STEP
		if close_enough and rng.randf() < float(preset["random"]):
			return moves[1]
	return moves[0]
