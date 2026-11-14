# 开局菜单：选「双人对战」或「人机对战 · 低 / 中 / 高」。
# 控件全部代码创建，样式与 HUD 一致（ui_kit.gd）；开着时挡住棋盘与底栏的点击。
extends Control

signal mode_chosen(level: String)     # "" = 双人对战；否则是 difficulty.gd 里的档位名

const KIT = preload("res://scripts/ui/ui_kit.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")

const PANEL_RECT := Rect2(200, 250, 560, 520)
const BUTTON_H := 54.0
const BUTTON_GAP := 72.0

var buttons: Dictionary = {}          # 档位名 → Button（"" = 双人对战）；测试脚本按它找按钮位置

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = KIT.make_theme()

	# 整屏压暗，突出中间的面板
	var dim := ColorRect.new()
	dim.color = Color(KIT.INK.r, KIT.INK.g, KIT.INK.b, 0.82)
	dim.size = Vector2(960, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := Panel.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.add_theme_stylebox_override("panel", KIT.make_box(KIT.PANEL, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var x: float = PANEL_RECT.position.x
	var w: float = PANEL_RECT.size.x
	KIT.make_label(self, Rect2(x, 290, w, 60), 44, KIT.TEXT, HORIZONTAL_ALIGNMENT_CENTER).text = "步步为营"
	KIT.make_label(self, Rect2(x, 352, w, 30), 20, KIT.MUTED, HORIZONTAL_ALIGNMENT_CENTER).text = "选择对战模式"

	var y: float = 410.0
	_add_mode_button("", "双人对战（同屏）", y)
	for level in DIFF.LEVELS:
		y += BUTTON_GAP
		_add_mode_button(level, "人机对战 · %s" % DIFF.label_of(level), y)

	var note: Label = KIT.make_label(self, Rect2(x, y + 72, w, 28), 18, KIT.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.text = "人机对战：你执蓝先手，电脑执橙"

func _add_mode_button(level: String, text: String, y: float) -> void:
	var rect := Rect2(PANEL_RECT.position.x + 110, y, PANEL_RECT.size.x - 220, BUTTON_H)
	var b: Button = KIT.make_button(self, rect, text, 24)
	b.pressed.connect(_on_mode_pressed.bind(level))
	buttons[level] = b

func _on_mode_pressed(level: String) -> void:
	mode_chosen.emit(level)
