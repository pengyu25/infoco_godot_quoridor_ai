# 开局菜单：双人对战 / 人机对战 · 低中高 / AI 对战（大模型）/ 设置。
# 控件全部代码创建，样式与 HUD 一致（ui_kit.gd）；开着时挡住棋盘与底栏的点击。
# 没配 API key 就点「AI 对战」时，弹出提示并引导去设置。
extends Control

signal mode_chosen(level: String)     # "" = 双人；easy / normal / hard；"llm" = 大模型
signal settings_requested()

const KIT = preload("res://scripts/ui/ui_kit.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")

const LLM := "llm"
const PANEL_RECT := Rect2(200, 170, 560, 640)
const BUTTON_H := 54.0
const BUTTON_GAP := 72.0

var settings = null                   # main.gd 注入（settings_store.gd）
var buttons: Dictionary = {}          # 档位名 → Button；测试脚本按它找按钮位置
var settings_button: Button
var notice: Panel                     # 「还没有配置 API key」提示
var notice_go: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = KIT.make_theme()
	KIT.make_overlay(self, PANEL_RECT, 0.82)

	var x: float = PANEL_RECT.position.x
	var w: float = PANEL_RECT.size.x
	KIT.make_label(self, Rect2(x, 205, w, 60), 44, KIT.TEXT, HORIZONTAL_ALIGNMENT_CENTER).text = "步步为营"
	KIT.make_label(self, Rect2(x, 267, w, 30), 20, KIT.MUTED, HORIZONTAL_ALIGNMENT_CENTER).text = "选择对战模式"

	var y: float = 320.0
	_add_mode_button("", "双人对战（同屏）", y)
	for level in DIFF.LEVELS:
		y += BUTTON_GAP
		_add_mode_button(level, "人机对战 · %s" % DIFF.label_of(level), y)
	y += BUTTON_GAP
	_add_mode_button(LLM, "AI 对战 · 大模型", y)
	y += BUTTON_GAP
	settings_button = KIT.make_button(self, _button_rect(y), "设置", 24)
	settings_button.pressed.connect(_on_settings_pressed)

	var note: Label = KIT.make_label(self, Rect2(x, y + 72, w, 28), 18, KIT.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.text = "人机 / AI 对战：你执蓝先手，对手执橙"
	_build_notice()

func _button_rect(y: float) -> Rect2:
	return Rect2(PANEL_RECT.position.x + 110, y, PANEL_RECT.size.x - 220, BUTTON_H)

func _add_mode_button(level: String, text: String, y: float) -> void:
	var b: Button = KIT.make_button(self, _button_rect(y), text, 24)
	b.pressed.connect(_on_mode_pressed.bind(level))
	buttons[level] = b

func _build_notice() -> void:
	notice = Panel.new()
	notice.position = Vector2(230, 430)
	notice.size = Vector2(500, 230)
	notice.add_theme_stylebox_override("panel", KIT.make_box(KIT.PANEL2, 14))
	notice.visible = false
	add_child(notice)
	var msg: Label = KIT.make_label(notice, Rect2(20, 24, 460, 100), 22, KIT.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	msg.text = "还没有配置 API key，\n不能开始 AI 对战。\n请先到「设置」里填写。"
	notice_go = KIT.make_button(notice, Rect2(60, 150, 180, 50), "去设置", 22)
	notice_go.pressed.connect(_on_notice_go)
	var close: Button = KIT.make_button(notice, Rect2(260, 150, 180, 50), "取消", 22)
	close.pressed.connect(_on_notice_close)

func _on_mode_pressed(level: String) -> void:
	if level == LLM and (settings == null or not settings.has_key()):
		notice.visible = true
		return
	notice.visible = false
	mode_chosen.emit(level)

func _on_settings_pressed() -> void:
	notice.visible = false
	settings_requested.emit()

func _on_notice_go() -> void:
	notice.visible = false
	settings_requested.emit()

func _on_notice_close() -> void:
	notice.visible = false
