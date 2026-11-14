# 局面评估：站在 me 一方看，分数越高越好。只用规则引擎第 5 节接口。
#   主项：双方最短路之差（对手还要走几步 - 我还要走几步）× STEP
#   次项：手里剩余墙数之差 × wall_weight —— 让「放一堵只拖慢对手 0 步的墙」变成亏本买卖
extends RefCounted

const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")

const STEP := 100          # 一步路值多少分
const WIN := 100000        # 已分胜负的分数，远大于任何「差几步」的分

static func evaluate(state, me: int, preset: Dictionary) -> int:
	var w: int = RM.winner(state)
	if w != -1:
		return WIN if w == me else -WIN

	var opp: int = 1 - me
	var score: int = (RP.shortest_path_len(state, opp) - RP.shortest_path_len(state, me)) * STEP
	score += (state.walls_left[me] - state.walls_left[opp]) * int(preset["wall_weight"])
	return score
