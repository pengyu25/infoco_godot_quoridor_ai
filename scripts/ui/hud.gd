# HUD：回合提示 / 剩余墙数 / 提示语 / 底栏三个按钮（放墙模式、重开一局、菜单）。
# 只负责显示和报告按钮点击；显示什么文字由 main.gd 决定。配色与控件样式见 ui_kit.gd。
extends Control

signal wall_mode_toggled(on: bool)
signal restart_pressed()
signal menu_pressed()

const KIT = preload("res://scripts/ui/ui_kit.gd")

const HINT_Y_ALONE := 60.0                # 没有台词时提示语的位置
const HINT_Y_WITH_SPEECH := 77.0          # 有台词时提示语往下让一行

var turn_label: Label
var speech_label: Label                   # 大模型最新一句台词（只在大模型对战里有内容）
var hint_label: Label
var wall_p0_label: Label
var wall_p1_label: Label
var wall_button: Button
var restart_button: Button
var menu_button: Button

var _wall_on: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = KIT.make_theme()

	# 底部状态条：面板色 + 一条 1px 分隔线（网站的面板语言）
	var bar := ColorRect.new()
	bar.color = Color(KIT.PANEL.r, KIT.PANEL.g, KIT.PANEL.b, 0.96)
	bar.position = Vector2(0, 958)
	bar.size = Vector2(960, 122)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var top_line := ColorRect.new()
	top_line.color = KIT.LINE
	top_line.position = Vector2(0, 958)
	top_line.size = Vector2(960, 1)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_line)

	turn_label = KIT.make_label(self, Rect2(0, 8, 960, 44), 30, KIT.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	speech_label = KIT.make_label(self, Rect2(30, 50, 900, 26), 19, KIT.P1, HORIZONTAL_ALIGNMENT_CENTER)
	speech_label.clip_text = true
	hint_label = KIT.make_label(self, Rect2(0, HINT_Y_ALONE, 960, 26), 18, KIT.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	wall_p0_label = KIT.make_label(self, Rect2(40, 976, 200, 40), 22, KIT.P0, HORIZONTAL_ALIGNMENT_LEFT)
	wall_p1_label = KIT.make_label(self, Rect2(720, 976, 200, 40), 22, KIT.P1, HORIZONTAL_ALIGNMENT_RIGHT)

	wall_button = KIT.make_button(self, Rect2(256, 972, 184, 46), "放墙模式：关", 22)
	wall_button.pressed.connect(_on_wall_button_pressed)

	restart_button = KIT.make_button(self, Rect2(452, 972, 140, 46), "重开一局", 22)
	restart_button.pressed.connect(_on_restart_button_pressed)

	menu_button = KIT.make_button(self, Rect2(604, 972, 100, 46), "菜单", 22)
	menu_button.pressed.connect(_on_menu_button_pressed)

# ---- 对外更新接口 ----

# player = 0 / 1 用该方阵营色，-1 用中性白
func set_turn(text: String, player: int) -> void:
	turn_label.text = text
	var color: Color = KIT.TEXT
	if player == 0:
		color = KIT.P0
	elif player == 1:
		color = KIT.P1
	turn_label.add_theme_color_override("font_color", color)

# names：双方显示名，如 ["玩家1", "玩家2"] 或 ["你", "电脑·中"]
func set_walls(left: Array, names: Array) -> void:
	wall_p0_label.text = "%s 墙 %d" % [names[0], left[0]]
	wall_p1_label.text = "%s 墙 %d" % [names[1], left[1]]

func set_wall_mode(on: bool) -> void:
	_wall_on = on
	wall_button.text = "放墙模式：开" if on else "放墙模式：关"
	wall_button.add_theme_color_override("font_color", KIT.ACID if on else KIT.TEXT)

func set_hint(text: String) -> void:
	hint_label.text = text

# 大模型的台词气泡；传 "" 收起
func set_speech(text: String) -> void:
	speech_label.text = text
	hint_label.position.y = HINT_Y_ALONE if text == "" else HINT_Y_WITH_SPEECH

# ---- 内部 ----

func _on_wall_button_pressed() -> void:
	wall_mode_toggled.emit(not _wall_on)

func _on_restart_button_pressed() -> void:
	restart_pressed.emit()

func _on_menu_button_pressed() -> void:
	menu_pressed.emit()
