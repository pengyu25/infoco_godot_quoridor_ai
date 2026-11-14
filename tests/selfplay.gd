# 自对弈压力测试：验证「一局能下完」+「合法着法永不封死任何一方」
# 用法：godot --headless --path "<项目>" --script res://tests/selfplay.gd
#
# 说明：走子局故意不走墙枚举（那是最贵的一条路径，见文件末尾的性能取样），
#       这样才能快速跑多局；带墙的一局专门验证墙的合法性不变量。
extends SceneTree

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const RP = preload("res://scripts/rules/rule_path.gd")

const PAWN_GAMES := 5
const PAWN_MAX_PLIES := 200
const WALL_GAMES := 1
const WALL_MAX_PLIES := 100

var _fail: int = 0

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261023

	var finished: int = 0
	var plies_sum: int = 0

	for g in range(PAWN_GAMES):
		var r: Dictionary = _play(rng, false, PAWN_MAX_PLIES)
		finished += r["finished"]
		plies_sum += r["plies"]
		print("  pawn game %d: plies=%d winner=%d" % [g, r["plies"], r["winner"]])

	for g in range(WALL_GAMES):
		var r: Dictionary = _play(rng, true, WALL_MAX_PLIES)
		finished += r["finished"]
		plies_sum += r["plies"]
		print("  wall game %d: plies=%d winner=%d walls=%d" % [g, r["plies"], r["winner"], r["walls"]])

	# 性能取样：枚举「全部合法着法」（含 128 个墙位校验）的平均耗时
	var s = RS.initial()
	var t0: int = Time.get_ticks_msec()
	var n: int = 3
	for i in range(n):
		var moves: Array = RM.legal_moves(s)
		if moves.is_empty():
			_fail += 1
		s = RM.apply(s, moves[0])
	var ms: float = float(Time.get_ticks_msec() - t0) / float(n)
	print("  legal_moves(with walls) avg = %.1f ms/call" % ms)

	var total_games: int = PAWN_GAMES + WALL_GAMES
	print("--------------------------------")
	print("games=%d finished=%d avg_plies=%.1f fail=%d" % [
		total_games, finished, float(plies_sum) / float(total_games), _fail
	])
	quit(0 if _fail == 0 else 1)

func _play(rng: RandomNumberGenerator, allow_walls: bool, max_plies: int) -> Dictionary:
	var s = RS.initial()
	var plies: int = 0
	var walls_used: int = 0

	while plies < max_plies and RM.winner(s) == -1:
		var moves: Array = []
		if allow_walls and rng.randf() < 0.3:
			moves = RM.wall_moves(s, s.turn)
		if moves.is_empty():
			moves = RM.pawn_moves(s, s.turn)

		if moves.is_empty():
			_fail += 1
			print("  FAIL: no legal moves at all")
			break

		var pick: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
		if pick["type"] != "move":
			walls_used += 1

		var before: int = s.turn
		s = RM.apply(s, pick)
		plies += 1

		# 不变量：任何合法着法都不能破坏双方通路
		if not (RP.has_path(s, 0) and RP.has_path(s, 1)):
			_fail += 1
			print("  FAIL: path destroyed")
			break

		# 不变量：回合必须交替
		if s.turn == before:
			_fail += 1
			print("  FAIL: turn did not switch")
			break

	return {
		"finished": 1 if RM.winner(s) != -1 else 0,
		"plies": plies,
		"winner": RM.winner(s),
		"walls": walls_used,
	}
