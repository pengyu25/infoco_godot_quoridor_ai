# 局面数据：唯一真相源。纯逻辑，不引用 UI / 场景 / Input / OS。
#
# 坐标约定
#   格子 (x, y)：x = 列 0..8，y = 行 0..8；格子 (x, y) 占据方块 [x, x+1] × [y, y+1]
#   横墙 h_walls[y][x]：在第 y 条横线（y = 1..8）上、从第 x 列起，占线段 [x, x+2]
#   竖墙 v_walls[y][x]：在第 x 条竖线（x = 1..8）上、从第 y 行起，占线段 [y, y+2]
#
# 玩家：0 = 起点 (4, 0)，目标第 8 行；1 = 起点 (4, 8)，目标第 0 行
extends RefCounted

const SIZE := 9
const WALLS_PER_PLAYER := 10

var pawns: Array = []          # [Vector2i, Vector2i]（下标 = 玩家）
var walls_left: Array = []     # [int, int]
var h_walls: Array = []        # 9×9 bool
var v_walls: Array = []        # 9×9 bool
var turn: int = 0              # 当前行动方

# 构造初始局面
# 注意：用 load() 而不是 class_name，避免依赖全局类缓存（headless --script 更稳）
static func initial() -> RefCounted:
	var s = load("res://scripts/rules/rule_state.gd").new()
	s.pawns = [Vector2i(4, 0), Vector2i(4, 8)]
	s.walls_left = [WALLS_PER_PLAYER, WALLS_PER_PLAYER]
	s.h_walls = []
	s.v_walls = []
	for y in range(SIZE):
		var row_h: Array = []
		var row_v: Array = []
		for x in range(SIZE):
			row_h.append(false)
			row_v.append(false)
		s.h_walls.append(row_h)
		s.v_walls.append(row_v)
	s.turn = 0
	return s

# 深拷贝：给「试探着法」（UI 预览 / AI 搜索 / 放墙校验）用，绝不共享数组引用
func clone() -> RefCounted:
	var s = load("res://scripts/rules/rule_state.gd").new()
	s.pawns = [pawns[0], pawns[1]]
	s.walls_left = [walls_left[0], walls_left[1]]
	s.h_walls = []
	s.v_walls = []
	for y in range(SIZE):
		s.h_walls.append(h_walls[y].duplicate())
		s.v_walls.append(v_walls[y].duplicate())
	s.turn = turn
	return s

# 确定性序列化：同一局面永远得到同一个字符串（墙按 y→x 排序输出）
func to_string_state() -> String:
	var parts: Array = []
	parts.append("turn=%d" % turn)
	parts.append("p0=%d,%d" % [pawns[0].x, pawns[0].y])
	parts.append("p1=%d,%d" % [pawns[1].x, pawns[1].y])
	parts.append("walls=%d,%d" % [walls_left[0], walls_left[1]])
	parts.append("H=" + _walls_to_text(h_walls))
	parts.append("V=" + _walls_to_text(v_walls))
	return "|".join(parts)

static func from_string_state(text: String) -> RefCounted:
	var s = initial()
	for part in text.split("|"):
		var kv: PackedStringArray = part.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"turn":
				s.turn = int(kv[1])
			"p0":
				s.pawns[0] = _parse_vec(kv[1])
			"p1":
				s.pawns[1] = _parse_vec(kv[1])
			"walls":
				var w: PackedStringArray = kv[1].split(",")
				s.walls_left[0] = int(w[0])
				s.walls_left[1] = int(w[1])
			"H":
				_parse_walls_into(kv[1], s.h_walls)
			"V":
				_parse_walls_into(kv[1], s.v_walls)
	return s

# 已放置的墙：着法同款 Dictionary（{"type","x","y"}），先横墙后竖墙，各按 y→x 排序。
# UI / AI 想知道墙在哪就用它，不要直接读 h_walls / v_walls（那是内部表示，以后可能换）。
func placed_walls() -> Array:
	var out: Array = []
	_collect_walls(h_walls, "wall_h", out)
	_collect_walls(v_walls, "wall_v", out)
	return out

# ---- 内部工具 ----

func _collect_walls(grid: Array, kind: String, out: Array) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			if grid[y][x]:
				out.append({"type": kind, "x": x, "y": y})

func _walls_to_text(grid: Array) -> String:
	var items: Array = []
	for y in range(SIZE):
		for x in range(SIZE):
			if grid[y][x]:
				items.append("%d,%d" % [x, y])
	return ";".join(items)

static func _parse_vec(text: String) -> Vector2i:
	var p: PackedStringArray = text.split(",")
	return Vector2i(int(p[0]), int(p[1]))

static func _parse_walls_into(text: String, grid: Array) -> void:
	if text.strip_edges() == "":
		return
	for item in text.split(";"):
		if item.strip_edges() == "":
			continue
		var p: PackedStringArray = item.split(",")
		grid[int(p[1])][int(p[0])] = true
