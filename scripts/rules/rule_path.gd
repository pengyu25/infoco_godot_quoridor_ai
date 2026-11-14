# 通路与几何：BFS 最短路 + 单步阻挡判定。纯逻辑，不引用 UI。
#
# 坐标与墙的几何定义见 rule_state.gd 顶部注释。
# 性能说明：BFS 用定长数组 + 整数队列（不用 Dictionary / Vector2i），
#           这是全项目最热的一段 —— AI 搜索与放墙校验都压在这里。
extends RefCounted

const SIZE := 9
const CELL_COUNT := 81      # SIZE * SIZE
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func is_in_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE

# 单步可否通行（整数版，给 BFS 热路径用，避免创建 Vector2i）
static func can_walk(state, cx: int, cy: int, dx: int, dy: int) -> bool:
	if dx != 0:
		var nx: int = cx + dx
		if nx < 0 or nx >= SIZE:
			return false
		var line_x: int = max(cx, nx)
		# 竖墙 v_walls[y0][x] 覆盖 y0..y0+2 → 能挡住第 y0 与 y0+1 行
		if cy - 1 >= 0 and state.v_walls[cy - 1][line_x]:
			return false
		if cy <= SIZE - 2 and state.v_walls[cy][line_x]:
			return false
		return true

	var ny: int = cy + dy
	if ny < 0 or ny >= SIZE:
		return false
	var line_y: int = max(cy, ny)
	# 横墙 h_walls[y][x] 覆盖 x..x+2 → 能挡住第 x 与 x+1 列
	if cx - 1 >= 0 and state.h_walls[line_y][cx - 1]:
		return false
	if cx <= SIZE - 2 and state.h_walls[line_y][cx]:
		return false
	return true

# 从 from 走到相邻格 to 是否被墙挡住（不检查棋子占用）
static func is_step_blocked(state, from: Vector2i, to: Vector2i) -> bool:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if abs(dx) + abs(dy) != 1:
		return true
	return not can_walk(state, from.x, from.y, dx, dy)

# BFS 最短路长度（步数）。不可达返回 -1。
# 注意：不把对方棋子当障碍 —— 棋子是会动的，这个距离衡量的是「墙造成的绕路」，
#       放墙合法性校验与 AI 评估都用它。
static func shortest_path_len(state, player: int) -> int:
	var start: Vector2i = state.pawns[player]
	var goal_row: int = SIZE - 1 if player == 0 else 0
	if start.y == goal_row:
		return 0

	var dist: Array = []
	dist.resize(CELL_COUNT)
	dist.fill(-1)

	var queue: PackedInt32Array = PackedInt32Array()
	var start_i: int = start.y * SIZE + start.x
	dist[start_i] = 0
	queue.append(start_i)

	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var cx: int = cur % SIZE
		var cy: int = cur / SIZE
		var d: int = dist[cur]
		if cy == goal_row:
			return d

		for dir in DIRS:
			if not can_walk(state, cx, cy, dir.x, dir.y):
				continue
			var nx: int = cx + dir.x
			var ny: int = cy + dir.y
			var ni: int = ny * SIZE + nx
			if dist[ni] != -1:
				continue
			dist[ni] = d + 1
			queue.append(ni)

	return -1

static func has_path(state, player: int) -> bool:
	return shortest_path_len(state, player) >= 0

# BFS 最短路线：从起点到终点线的格子序列（含起点与终点）；不可达返回 []，已在终点返回 [起点]。
# 与 shortest_path_len 同一套规则（同样不把对方棋子当障碍），路线步数 = 返回数组大小 - 1。
# 有多条等长路线时按 DIRS 顺序取第一条，结果确定。AI 用它找「挡哪里最有效」。
static func shortest_path(state, player: int) -> Array:
	var start: Vector2i = state.pawns[player]
	var goal_row: int = SIZE - 1 if player == 0 else 0
	if start.y == goal_row:
		return [start]

	var parent: Array = []
	parent.resize(CELL_COUNT)
	parent.fill(-2)                      # -2 = 未访问，-1 = 起点

	var queue: PackedInt32Array = PackedInt32Array()
	var start_i: int = start.y * SIZE + start.x
	parent[start_i] = -1
	queue.append(start_i)

	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var cx: int = cur % SIZE
		var cy: int = cur / SIZE
		if cy == goal_row:
			return _trace_path(parent, cur)

		for dir in DIRS:
			if not can_walk(state, cx, cy, dir.x, dir.y):
				continue
			var ni: int = (cy + dir.y) * SIZE + (cx + dir.x)
			if parent[ni] != -2:
				continue
			parent[ni] = cur
			queue.append(ni)

	return []

# 从终点沿 parent 倒推回起点
static func _trace_path(parent: Array, end_i: int) -> Array:
	var out: Array = []
	var i: int = end_i
	while i != -1:
		out.push_front(Vector2i(i % SIZE, i / SIZE))
		i = parent[i]
	return out
