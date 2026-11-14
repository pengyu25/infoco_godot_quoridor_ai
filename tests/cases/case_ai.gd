# 用例：电脑对手 —— 永不走非法步 / 能赢必赢 / 对手要赢时会挡 / 同种子可复现 / 不改原局面
extends RefCounted

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const AP = preload("res://scripts/ai/ai_player.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")

const SAMPLE_COUNT := 12
const FAST_BUDGET_MS := 150

static func run(t) -> void:
	var positions: Array = _sample_positions(SAMPLE_COUNT)
	t.eq(positions.size(), SAMPLE_COUNT, "collected sample positions")
	_test_always_legal(t, positions)
	_test_takes_win(t)
	_test_blocks_loss(t)
	_test_reproducible(t, positions)
	_test_does_not_mutate(t, positions)

# 同档参数，但思考上限压到 150ms，单元测试不至于太慢
static func _fast(level: String) -> Dictionary:
	var p: Dictionary = DIFF.get_preset(level).duplicate()
	p["time_budget_ms"] = mini(int(p["time_budget_ms"]), FAST_BUDGET_MS)
	return p

# 一盘带墙的随机对局沿途的局面，当作「各种中局」样本（固定种子，每次一样）
static func _sample_positions(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s = RS.initial()
	var out: Array = []
	while out.size() < count and RM.winner(s) == -1:
		var moves: Array = []
		if rng.randf() < 0.3:
			moves = RM.wall_moves(s, s.turn)
		if moves.is_empty():
			moves = RM.pawn_moves(s, s.turn)
		s = RM.apply(s, moves[rng.randi_range(0, moves.size() - 1)])
		if RM.winner(s) == -1:
			out.append(s)
	return out

static func _test_always_legal(t, positions: Array) -> void:
	for level in DIFF.LEVELS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var illegal: int = 0
		for s in positions:
			if not RM.is_legal(s, AP.choose_move(s, _fast(level), rng)):
				illegal += 1
		t.eq(illegal, 0, "%s: legal move in all %d sample positions" % [level, positions.size()])

static func _test_takes_win(t) -> void:
	var a = t.new_state(Vector2i(2, 7), Vector2i(6, 3))       # 蓝方下一步就到第 8 行
	var b = t.new_state(Vector2i(2, 5), Vector2i(5, 1))       # 橙方下一步就到第 0 行
	b.turn = 1
	for level in DIFF.LEVELS:
		t.eq(RM.winner(RM.apply(a, AP.choose_move(a, _fast(level)))), 0, "%s: p0 takes the winning step" % level)
		t.eq(RM.winner(RM.apply(b, AP.choose_move(b, _fast(level)))), 1, "%s: p1 takes the winning step" % level)

# 对手下一步就到终点、自己又赢不了：会放墙的档位必须挡住（低档不放墙，不测）
static func _test_blocks_loss(t) -> void:
	var a = t.new_state(Vector2i(0, 0), Vector2i(4, 1))       # 电脑执蓝，橙方站在 (4,1)
	var b = t.new_state(Vector2i(4, 7), Vector2i(8, 8))       # 电脑执橙，蓝方站在 (4,7)
	b.turn = 1
	for level in ["normal", "hard"]:
		for s in [a, b]:
			var after = RM.apply(s, AP.choose_move(s, _fast(level)))
			var opp: int = 1 - s.turn
			var opp_can_win: bool = false
			for m in RM.pawn_moves(after, opp):
				if RM.winner(RM.apply(after, m)) == opp:
					opp_can_win = true
			t.check(not opp_can_win, "%s: AI as p%d blocks the opponent's winning step" % [level, s.turn])

# 时间上限放大到不会触发，结果只取决于随机种子
static func _test_reproducible(t, positions: Array) -> void:
	var p: Dictionary = DIFF.get_preset("normal").duplicate()
	p["time_budget_ms"] = 60000
	var s = positions[positions.size() / 2]
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	t.eq(AP.choose_move(s, p, r1), AP.choose_move(s, p, r2), "same seed -> same move")

static func _test_does_not_mutate(t, positions: Array) -> void:
	var s = positions[positions.size() - 1]
	var before: String = s.to_string_state()
	AP.choose_move(s, _fast("hard"))
	t.eq(s.to_string_state(), before, "choose_move does not mutate the state")
