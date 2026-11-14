# 场景入口：持有局面与状态机，决定轮到谁——人（HumanTurn）、本地电脑（ComputerTurn）或大模型（LlmTurn）。
# 规则判断在 scripts/rules/，电脑怎么选在 scripts/ai/，大模型怎么问在 scripts/llm/ —— 这里只做调度。
extends Node2D

const RS = preload("res://scripts/rules/rule_state.gd")
const RM = preload("res://scripts/rules/rule_moves.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")
const MT = preload("res://scripts/ui/match_text.gd")
const SETTINGS = preload("res://scripts/llm/settings_store.gd")

# MENU 开局菜单 / WAITING_INPUT 等人操作 / AI_THINKING 对手回合（锁住棋盘）/ GAME_OVER 已分胜负
enum State { MENU, WAITING_INPUT, AI_THINKING, GAME_OVER }

const AI_SIDE := 1            # 电脑 / 大模型执橙（玩家 2，后手）
const LLM := "llm"            # level 取这个值 = 大模型对战

var state = null
var phase: int = State.MENU
var level: String = ""        # "" 双人；easy / normal / hard 本地电脑；"llm" 大模型
var settings_path: String = SETTINGS.DEFAULT_PATH    # 测试脚本会换成临时文件，不碰真实设置
var settings = null

@onready var board = $Board
@onready var human = $HumanTurn
@onready var computer = $ComputerTurn
@onready var llm = $LlmTurn
@onready var hud = $UI/HUD
@onready var chat = $UI/ChatPanel
@onready var menu = $UI/Menu
@onready var settings_panel = $UI/SettingsPanel

func _ready() -> void:
	settings = SETTINGS.new()
	settings.path = settings_path
	settings.load_from_disk()
	menu.settings = settings
	settings_panel.settings = settings
	llm.settings = settings

	board.cell_clicked.connect(human.on_cell_clicked)
	board.wall_clicked.connect(human.on_wall_clicked)
	hud.wall_mode_toggled.connect(human.on_wall_mode_toggled)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.menu_pressed.connect(show_menu)
	human.move_chosen.connect(_apply)
	human.changed.connect(_sync)
	human.hint.connect(hud.set_hint)
	computer.move_ready.connect(_on_opponent_move)
	llm.move_ready.connect(_on_opponent_move)
	llm.said.connect(_on_llm_said)
	chat.message_sent.connect(llm.add_player_chat)
	menu.mode_chosen.connect(_on_mode_chosen)
	menu.settings_requested.connect(settings_panel.open)
	show_menu()

func show_menu() -> void:
	_stop_opponents()
	phase = State.MENU
	state = RS.initial()
	human.stop()
	menu.visible = true
	chat.visible = false
	hud.set_speech("")
	_sync()

func new_game() -> void:
	_stop_opponents()
	menu.visible = false
	chat.visible = level == LLM
	chat.clear()
	hud.set_speech("")
	state = RS.initial()
	human.pawn_hint = MT.pick_pawn_hint(_ai_name(), AI_SIDE)
	_enter_turn("点自己的棋子开始；放墙要点下方按钮")
	if level == LLM:
		llm.greet()

func _stop_opponents() -> void:
	computer.cancel()
	llm.reset()

# 局面一变就走这里：分出胜负就结束；轮到对手就锁住棋盘交给它；否则开放给人操作
func _enter_turn(hint: String = "") -> void:
	var w: int = RM.winner(state)
	if w != -1:
		phase = State.GAME_OVER
		human.stop()
		_sync(hint)
		if level == LLM:
			llm.farewell(w == AI_SIDE)
		return
	if level != "" and state.turn == AI_SIDE:
		phase = State.AI_THINKING
		human.stop()
		_sync(hint)
		if level == LLM:
			llm.start(state, AI_SIDE)
		else:
			computer.start(state, DIFF.get_preset(level))
		return
	phase = State.WAITING_INPUT
	human.begin(state)
	_sync(hint)

# 把当前局面推给视图与 HUD；已分胜负时提示语固定为结果
func _sync(hint: String = "") -> void:
	board.show_state(state, human.selected, human.legal_targets, human.wall_mode)
	var w: int = RM.winner(state)
	if w != -1:
		hint = MT.result_text(_ai_name(), w, AI_SIDE)
	var head: Array = MT.header(_ai_name(), state.turn, AI_SIDE, phase == State.MENU, phase == State.GAME_OVER)
	hud.set_turn(head[0], head[1])
	hud.set_walls(state.walls_left, MT.names(_ai_name(), AI_SIDE))
	hud.set_wall_mode(human.wall_mode)
	hud.set_hint(hint)

# 对手显示名："" = 双人对战
func _ai_name() -> String:
	if level == "":
		return ""
	if level == LLM:
		return settings.display_name()
	return "电脑·" + DIFF.label_of(level)

func _on_mode_chosen(chosen: String) -> void:
	level = chosen
	new_game()

func _on_restart_pressed() -> void:
	if phase != State.MENU:
		new_game()

func _apply(mv: Dictionary, hint: String = "") -> void:
	if level == LLM and state.turn != AI_SIDE:
		llm.note_player_move(mv)
	state = RM.apply(state, mv)
	_enter_turn(hint)

func _on_opponent_move(mv: Dictionary) -> void:
	if phase == State.AI_THINKING:
		_apply(mv, MT.ai_moved_text(_ai_name(), mv))

# 大模型说的话：顶部气泡显示最新一句，对话记录里留底
func _on_llm_said(text: String, is_system: bool) -> void:
	var who: String = "系统" if is_system else settings.display_name()
	hud.set_speech(text if is_system else "%s：%s" % [who, text])
	chat.add_line(who, text)
