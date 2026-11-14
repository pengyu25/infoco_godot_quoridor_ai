# 场景入口：持有 RuleState，把「点击」翻译成规则着法，再更新视图与 HUD。
# 规则判断全部委托给 scripts/rules/ —— 这里一行规则逻辑都不写。
extends Node2D

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")

var state = null
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array = []
var wall_mode: bool = false
var game_over: bool = false

@onready var board = $Board
@onready var hud = $UI/HUD

func _ready() -> void:
	board.cell_clicked.connect(_on_cell_clicked)
	board.wall_clicked.connect(_on_wall_clicked)
	hud.wall_mode_toggled.connect(_on_wall_mode_toggled)
	hud.restart_pressed.connect(_on_restart_pressed)
	new_game()

func new_game() -> void:
	state = RS.initial()
	selected = Vector2i(-1, -1)
	legal_targets = []
	wall_mode = false
	game_over = false
	_sync("点自己的棋子开始；放墙要点下方按钮")

# 把当前局面推给视图与 HUD
func _sync(hint: String = "") -> void:
	board.state = state
	board.selected = selected
	board.legal_targets = legal_targets
	board.wall_mode = wall_mode
	board.queue_redraw()

	hud.set_walls(state.walls_left)
	hud.set_wall_mode(wall_mode)

	var w: int = RM.winner(state)
	if w != -1:
		game_over = true
	hud.set_turn(state.turn, game_over)

	if hint != "":
		hud.set_hint(hint)
	elif w != -1:
		hud.set_hint("玩家 %d 获胜！点「重开一局」再来" % (w + 1))
	else:
		hud.set_hint("")

func _on_cell_clicked(cell: Vector2i) -> void:
	if game_over:
		return
	if wall_mode:
		hud.set_hint("放墙模式开着：关掉它才能走子")
		return

	var my_pawn: Vector2i = state.pawns[state.turn]

	# 点自己的棋子 → 选中并显示可走位置
	if cell == my_pawn:
		selected = cell
		legal_targets = _targets()
		_sync()
		return

	# 已选中棋子，再点目标格
	if selected != Vector2i(-1, -1):
		var mv := {"type": "move", "to": cell}
		if RM.is_legal(state, mv):
			_apply(mv)
			return
		selected = Vector2i(-1, -1)
		legal_targets = []
		_sync("那格走不过去")
		return

	hud.set_hint("先点自己的棋子（蓝=玩家1，橙=玩家2）")

func _on_wall_clicked(kind: String, x: int, y: int) -> void:
	if game_over:
		return
	if not wall_mode:
		hud.set_hint("想放墙请先点「放墙模式」")
		return

	var mv := {"type": kind, "x": x, "y": y}
	if RM.is_legal(state, mv):
		_apply(mv)
	else:
		hud.set_hint("这里不能放墙（重叠／交叉／墙数不足／会封死通路）")

func _on_wall_mode_toggled(on: bool) -> void:
	if game_over:
		return
	wall_mode = on
	selected = Vector2i(-1, -1)
	legal_targets = []
	_sync("放墙模式：点格线附近放墙" if on else "")

func _on_restart_pressed() -> void:
	new_game()

func _apply(mv: Dictionary) -> void:
	state = RM.apply(state, mv)
	selected = Vector2i(-1, -1)
	legal_targets = []
	wall_mode = false
	_sync()

# 当前行动方的可走格（用于界面高亮）
func _targets() -> Array:
	var out: Array = []
	for m in RM.pawn_moves(state, state.turn):
		out.append(m["to"])
	return out
