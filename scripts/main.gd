# 场景入口：持有局面，把「点击」翻译成规则着法，再更新视图与 HUD；人机模式下交给 ComputerTurn 算电脑的一步。
# 规则判断全在 scripts/rules/，电脑怎么选全在 scripts/ai/ —— 这里既不写规则也不写算法。
extends Node2D

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")
const MT = preload("res://scripts/ui/match_text.gd")

# MENU 开局菜单 / WAITING_INPUT 等人操作 / AI_THINKING 电脑回合（锁住一切输入）/ GAME_OVER 已分胜负
enum State { MENU, WAITING_INPUT, AI_THINKING, GAME_OVER }

const AI_SIDE := 1            # 电脑执橙（玩家 2，后手）

var state = null
var phase: int = State.MENU
var level: String = ""        # "" = 双人对战；否则是 difficulty.gd 里的档位名
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array = []
var wall_mode: bool = false

@onready var board = $Board
@onready var hud = $UI/HUD
@onready var menu = $UI/Menu
@onready var computer = $ComputerTurn

func _ready() -> void:
	board.cell_clicked.connect(_on_cell_clicked)
	board.wall_clicked.connect(_on_wall_clicked)
	hud.wall_mode_toggled.connect(_on_wall_mode_toggled)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.menu_pressed.connect(show_menu)
	menu.mode_chosen.connect(_on_mode_chosen)
	computer.move_ready.connect(_on_computer_move)
	show_menu()

func show_menu() -> void:
	computer.cancel()
	phase = State.MENU
	_reset_board()
	menu.visible = true
	_sync()

func new_game() -> void:
	computer.cancel()
	phase = State.WAITING_INPUT
	menu.visible = false
	_reset_board()
	_sync("点自己的棋子开始；放墙要点下方按钮")
	_maybe_start_computer()

func _reset_board() -> void:
	state = RS.initial()
	wall_mode = false
	_clear_selection()

func _clear_selection() -> void:
	selected = Vector2i(-1, -1)
	legal_targets = []

# 把当前局面推给视图与 HUD；已分胜负时提示语固定为结果
func _sync(hint: String = "") -> void:
	board.show_state(state, selected, legal_targets, wall_mode)

	var w: int = RM.winner(state)
	if w != -1:
		phase = State.GAME_OVER
		hint = MT.result_text(level, w, AI_SIDE)

	var head: Array = MT.header(level, state.turn, AI_SIDE, phase == State.MENU, phase == State.GAME_OVER)
	hud.set_turn(head[0], head[1])
	hud.set_walls(state.walls_left, MT.names(level, AI_SIDE))
	hud.set_wall_mode(wall_mode)
	hud.set_hint(hint)

func _on_mode_chosen(chosen: String) -> void:
	level = chosen
	new_game()

func _on_cell_clicked(cell: Vector2i) -> void:
	if phase != State.WAITING_INPUT:
		return
	if wall_mode:
		hud.set_hint("放墙模式开着：关掉它才能走子")
		return

	# 点自己的棋子 → 选中并显示可走位置
	if cell == state.pawns[state.turn]:
		selected = cell
		legal_targets = []
		for m in RM.pawn_moves(state, state.turn):
			legal_targets.append(m["to"])
		_sync()
		return

	# 已选中棋子，再点目标格
	if selected != Vector2i(-1, -1):
		var mv := {"type": "move", "to": cell}
		if RM.is_legal(state, mv):
			_apply(mv)
			return
		_clear_selection()
		_sync("那格走不过去")
		return

	hud.set_hint(MT.pick_pawn_hint(level, AI_SIDE))

func _on_wall_clicked(kind: String, x: int, y: int) -> void:
	if phase != State.WAITING_INPUT:
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
	if phase != State.WAITING_INPUT:
		return
	wall_mode = on
	_clear_selection()
	_sync("放墙模式：点格线附近放墙" if on else "")

func _on_restart_pressed() -> void:
	if phase != State.MENU:
		new_game()

func _apply(mv: Dictionary, hint: String = "") -> void:
	state = RM.apply(state, mv)
	wall_mode = false
	_clear_selection()
	phase = State.WAITING_INPUT
	_sync(hint)
	_maybe_start_computer()

# 人机模式且轮到电脑：锁住输入，交给 ComputerTurn 去算
func _maybe_start_computer() -> void:
	if level == "" or phase != State.WAITING_INPUT or state.turn != AI_SIDE:
		return
	phase = State.AI_THINKING
	_sync()
	computer.start(state, DIFF.get_preset(level))

func _on_computer_move(mv: Dictionary) -> void:
	if phase == State.AI_THINKING:
		_apply(mv, MT.ai_moved_text(mv))
