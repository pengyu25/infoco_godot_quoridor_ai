# 电脑对手强度评估：各档互相对战，统计胜率与每步思考时间
# 运行（在项目根目录）：godot --headless --path . --script tests/ai_match.gd
# 退出码：0 = 全程无非法着法，1 = 出现非法着法（强度高低只打印，不算失败——那是调参的依据）
#
# 每组对局交替先后手，抵消先手优势；固定随机种子，结果可复现（时间上限触发点除外）。
extends SceneTree

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const AP = preload("res://scripts/ai/ai_player.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")

const GAMES_PER_PAIR := 10
const MAX_PLIES := 200                 # 超过算和棋（正常一局 30~80 手）
const PAIRS := [["normal", "easy"], ["hard", "normal"], ["hard", "easy"]]

var _illegal: int = 0
var _stats: Dictionary = {}            # 档位 → {moves, ms_sum, ms_max, depth_sum, walls}

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	for level in DIFF.LEVELS:
		_stats[level] = {"moves": 0, "ms_sum": 0, "ms_max": 0, "depth_sum": 0, "walls": 0}

	print("== AI match: %d games per pair ==" % GAMES_PER_PAIR)
	for pair in PAIRS:
		var wins: Dictionary = {pair[0]: 0, pair[1]: 0, "draw": 0}
		var plies_sum: int = 0
		for g in range(GAMES_PER_PAIR):
			# 偶数局 pair[0] 执蓝先手，奇数局换过来
			var sides: Array = [pair[0], pair[1]] if g % 2 == 0 else [pair[1], pair[0]]
			var r: Dictionary = _play(sides, rng)
			plies_sum += r["plies"]
			if r["winner"] == -1:
				wins["draw"] += 1
			else:
				wins[sides[r["winner"]]] += 1
		print("  %-6s vs %-6s  %2d : %2d  draw %d  avg plies %.0f" % [
			pair[0], pair[1], wins[pair[0]], wins[pair[1]], wins["draw"],
			float(plies_sum) / GAMES_PER_PAIR,
		])

	print("-- per move --")
	for level in DIFF.LEVELS:
		var st: Dictionary = _stats[level]
		var n: int = maxi(st["moves"], 1)
		print("  %-6s moves %4d  avg %6.1f ms  max %5d ms  avg depth %.2f  walls/game-side %.1f" % [
			level, st["moves"], float(st["ms_sum"]) / n, st["ms_max"],
			float(st["depth_sum"]) / n, float(st["walls"]) / (GAMES_PER_PAIR * 2.0),
		])
	print("illegal moves: %d" % _illegal)
	quit(0 if _illegal == 0 else 1)

func _play(sides: Array, rng: RandomNumberGenerator) -> Dictionary:
	var s = RS.initial()
	var plies: int = 0
	while plies < MAX_PLIES and RM.winner(s) == -1:
		var level: String = sides[s.turn]
		var info: Dictionary = AP.think(s, DIFF.get_preset(level), rng)
		if not RM.is_legal(s, info["move"]):
			_illegal += 1
			print("  ILLEGAL by %s: %s at %s" % [level, str(info["move"]), s.to_string_state()])
			break
		var st: Dictionary = _stats[level]
		st["moves"] += 1
		st["ms_sum"] += info["ms"]
		st["ms_max"] = maxi(st["ms_max"], info["ms"])
		st["depth_sum"] += info["depth"]
		if info["move"]["type"] != "move":
			st["walls"] += 1
		s = RM.apply(s, info["move"])
		plies += 1
	return {"winner": RM.winner(s), "plies": plies}
