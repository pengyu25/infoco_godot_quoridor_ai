# 界面小工具：站点配色（InfoCo / GitHub Dark）+ 代码创建 Label / Button / 面板样式。
# HUD 与开局菜单共用，保证两处长得一样。
extends RefCounted

const FONT_PATH := "res://assets/fonts/zpix.ttf"

const TEXT := Color(0.902, 0.929, 0.953)      # #e6edf3
const MUTED := Color(0.604, 0.643, 0.698)     # #9aa4b2
const P0 := Color(0.345, 0.651, 1.000)        # #58a6ff（玩家1 / 蓝）
const P1 := Color(0.824, 0.600, 0.133)        # #d29922（玩家2 / 橙）
const ACID := Color(0.247, 0.725, 0.314)      # #3fb950
const INK := Color(0.051, 0.067, 0.090)       # #0d1117
const PANEL := Color(0.086, 0.106, 0.133)     # #161b22
const PANEL2 := Color(0.110, 0.129, 0.157)    # #1c2128
const PRESSED := Color(0.055, 0.071, 0.094)
const LINE := Color(0.941, 0.965, 0.988, 0.16)
const BORDER := Color(0.941, 0.965, 0.988, 0.12)

# 全局中文字体（zpix）；字体缺失时退回引擎默认字体
static func make_theme() -> Theme:
	var th := Theme.new()
	var f = load(FONT_PATH)
	if f != null:
		th.default_font = f
	return th

static func make_label(parent: Control, rect: Rect2, font_size: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# 扁平暗面板 + 1px 描边 + 圆角（网站的面板语言，不用拟物材质）
static func make_box(bg: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box

static func make_button(parent: Control, rect: Rect2, text: String, font_size: int) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", make_box(PANEL, 12))
	b.add_theme_stylebox_override("hover", make_box(PANEL2, 12))
	b.add_theme_stylebox_override("pressed", make_box(PRESSED, 12))
	parent.add_child(b)
	return b
