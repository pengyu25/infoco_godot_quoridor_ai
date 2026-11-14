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

# 弹层底板：整屏压暗 + 中间一块面板（菜单、设置页共用）。返回面板
static func make_overlay(parent: Control, panel_rect: Rect2, dim_alpha: float) -> Panel:
	var dim := ColorRect.new()
	dim.color = Color(INK.r, INK.g, INK.b, dim_alpha)
	dim.size = Vector2(960, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)
	var panel := Panel.new()
	panel.position = panel_rect.position
	panel.size = panel_rect.size
	panel.add_theme_stylebox_override("panel", make_box(PANEL, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

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

static func make_line_edit(parent: Control, rect: Rect2, placeholder: String, font_size: int = 20) -> LineEdit:
	var e := LineEdit.new()
	e.position = rect.position
	e.size = rect.size
	e.placeholder_text = placeholder
	e.add_theme_font_size_override("font_size", font_size)
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", MUTED)
	e.add_theme_stylebox_override("normal", make_box(PANEL2, 8))
	e.add_theme_stylebox_override("focus", make_box(PRESSED, 8))
	parent.add_child(e)
	return e

static func make_check(parent: Control, rect: Rect2, text: String, font_size: int = 18) -> CheckBox:
	var c := CheckBox.new()
	c.position = rect.position
	c.size = rect.size
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", font_size)
	c.add_theme_color_override("font_color", TEXT)
	# 引擎默认的空心框在深色底上几乎看不见，换成自己画的高对比方框
	c.add_theme_icon_override("unchecked", _box_icon(false))
	c.add_theme_icon_override("checked", _box_icon(true))
	parent.add_child(c)
	return c

# 20×20 的勾选框图标：浅色描边；勾选时中间填站点绿
static func _box_icon(checked: bool) -> ImageTexture:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := Color(TEXT.r, TEXT.g, TEXT.b, 0.75)
	for i in range(1, 19):
		for w in [1, 2, 17, 18]:
			img.set_pixel(i, w, edge)
			img.set_pixel(w, i, edge)
	if checked:
		img.fill_rect(Rect2i(5, 5, 10, 10), ACID)
	return ImageTexture.create_from_image(img)

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
