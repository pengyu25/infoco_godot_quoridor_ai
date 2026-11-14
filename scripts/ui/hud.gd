# HUD：回合提示 / 剩余墙数 / 提示语 / 两个按钮。
# 配色对齐 InfoCo 网站（GitHub Dark）：ink #0d1117 / panel #161b22 / text #e6edf3 / acid #3fb950
extends Control

signal wall_mode_toggled(on: bool)
signal restart_pressed()

const FONT_PATH := "res://assets/fonts/zpix.ttf"

const TEXT := Color(0.902, 0.929, 0.953)      # #e6edf3
const MUTED := Color(0.604, 0.643, 0.698)     # #9aa4b2
const P0 := Color(0.345, 0.651, 1.000)        # #58a6ff
const P1 := Color(0.824, 0.600, 0.133)        # #d29922
const ACID := Color(0.247, 0.725, 0.314)      # #3fb950
const PANEL := Color(0.086, 0.106, 0.133)     # #161b22
const PANEL2 := Color(0.110, 0.129, 0.157)    # #1c2128
const LINE := Color(0.941, 0.965, 0.988, 0.16)

var turn_label: Label
var hint_label: Label
var wall_p0_label: Label
var wall_p1_label: Label
var wall_button: Button
var restart_button: Button

var _wall_on: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var f = load(FONT_PATH)
	if f != null:
		var th := Theme.new()
		th.default_font = f
		theme = th

	# 底部状态条：面板色 + 一条 1px 分隔线（网站的面板语言）
	var bar := ColorRect.new()
	bar.color = Color(PANEL.r, PANEL.g, PANEL.b, 0.96)
	bar.position = Vector2(0, 958)
	bar.size = Vector2(960, 122)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	move_child(bar, 0)

	var top_line := ColorRect.new()
	top_line.color = LINE
	top_line.position = Vector2(0, 958)
	top_line.size = Vector2(960, 1)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_line)
	move_child(top_line, 1)

	turn_label = _make_label(Rect2(0, 16, 960, 52), 32, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label = _make_label(Rect2(0, 70, 960, 28), 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	wall_p0_label = _make_label(Rect2(68, 976, 180, 40), 22, P0, HORIZONTAL_ALIGNMENT_LEFT)
	wall_p1_label = _make_label(Rect2(712, 976, 180, 40), 22, P1, HORIZONTAL_ALIGNMENT_RIGHT)

	wall_button = _make_button(Rect2(260, 972, 220, 46), "放墙模式：关", 22)
	wall_button.pressed.connect(_on_wall_button_pressed)

	restart_button = _make_button(Rect2(496, 972, 200, 46), "重开一局", 22)
	restart_button.pressed.connect(_on_restart_button_pressed)

# ---- 对外更新接口 ----

func set_turn(player: int, is_over: bool) -> void:
	if is_over:
		turn_label.text = "对局结束"
		turn_label.add_theme_color_override("font_color", TEXT)
		return
	turn_label.text = "玩家 %d 回合" % (player + 1)
	turn_label.add_theme_color_override("font_color", P0 if player == 0 else P1)

func set_walls(left: Array) -> void:
	wall_p0_label.text = "玩家1 墙 %d" % left[0]
	wall_p1_label.text = "玩家2 墙 %d" % left[1]

func set_wall_mode(on: bool) -> void:
	_wall_on = on
	wall_button.text = "放墙模式：开" if on else "放墙模式：关"
	wall_button.add_theme_color_override("font_color", ACID if on else TEXT)

func set_hint(text: String) -> void:
	hint_label.text = text

# ---- 内部 ----

func _on_wall_button_pressed() -> void:
	wall_mode_toggled.emit(not _wall_on)

func _on_restart_button_pressed() -> void:
	restart_pressed.emit()

func _make_label(rect: Rect2, font_size: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _make_button(rect: Rect2, text: String, font_size: int) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	# 扁平暗面板 + 1px 描边（网站按钮语言，不用拟物材质）
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL
	normal.border_color = Color(0.941, 0.965, 0.988, 0.12)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 14
	normal.content_margin_right = 14

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PANEL2

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.055, 0.071, 0.094)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)

	add_child(b)
	return b
