# 候选着法：走子全收；墙只挑「挡在对手最短路线上、且让对手比自己更吃亏」的前几个。
# 全量枚举 128 个墙位每次要 20ms 以上（技术骨架第 13 节），塞不进搜索，所以只看这一小批。
# 结果按启发分从高到低排好：搜索先试好棋，alpha-beta 剪得更多。
extends RefCounted

const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")

const STEP := 100          # 与 ai_eval.gd 一致：100 分 = 一步路

# 当前行动方的候选着法（已排序）
static func generate(state, preset: Dictionary) -> Array:
	var me: int = state.turn
	var base_me: int = RP.shortest_path_len(state, me)
	var scored: Array = []          # 每项 [启发分, 着法]

	# 走子：离终点近了多少步就加多少分（跳过对手可能一下近 2 步）
	for m in RM.pawn_moves(state, me):
		var d: int = RP.shortest_path_len(RM.apply(state, m), me)
		scored.append([(base_me - d) * STEP, m])

	if bool(preset["use_walls"]) and state.walls_left[me] > 0:
		scored.append_array(wall_candidates(state, preset))

	sort_desc(scored)
	var out: Array = []
	for item in scored:
		out.append(item[1])
	return out

# 墙候选：返回 [启发分, 墙着法] 列表，最多 preset.wall_candidates 个
static func wall_candidates(state, preset: Dictionary) -> Array:
	var limit: int = int(preset["wall_candidates"])
	if limit <= 0:
		return []

	var me: int = state.turn
	var opp: int = 1 - me
	var base_me: int = RP.shortest_path_len(state, me)
	var base_opp: int = RP.shortest_path_len(state, opp)
	var path: Array = RP.shortest_path(state, opp)

	var seen: Dictionary = {}
	var out: Array = []
	for i in range(path.size() - 1):
		for w in RM.walls_blocking_step(path[i], path[i + 1]):
			var key: String = "%s/%d/%d" % [w["type"], w["x"], w["y"]]
			if seen.has(key):
				continue
			seen[key] = true

			# 先试放看收益（便宜），收益为正的再做完整合法性校验（贵）
			var after = RM.apply(state, w)
			var d_opp: int = RP.shortest_path_len(after, opp)
			var d_me: int = RP.shortest_path_len(after, me)
			if d_opp < 0 or d_me < 0:
				continue
			var gain: int = (d_opp - base_opp) - (d_me - base_me)
			if gain <= 0:
				continue
			if not RM.is_wall_legal(state, w["type"], w["x"], w["y"], me):
				continue
			out.append([gain * STEP - int(preset["wall_weight"]), w])

	sort_desc(out)
	if out.size() > limit:
		out.resize(limit)
	return out

# 按 [分数, 着法] 的分数从高到低排。插入排序：列表只有十几项，且同分保持原有先后
static func sort_desc(items: Array) -> void:
	for i in range(1, items.size()):
		var cur: Array = items[i]
		var j: int = i - 1
		while j >= 0 and items[j][0] < cur[0]:
			items[j + 1] = items[j]
			j -= 1
		items[j + 1] = cur
