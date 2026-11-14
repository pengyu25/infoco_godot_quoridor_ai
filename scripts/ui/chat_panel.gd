# 大模型对战的聊天：底栏下方的输入框 + 「对话记录」面板。
# 玩家的话不会立刻发出，跟着对手的下一步一起送过去（不额外花钱）；对手每一步都会主动说话，不依赖玩家输入。
# 所有文字按纯文本显示，模型输出的格式标记不会被解析。
extends Control

signal message_sent(text: String)

const KIT = preload("res://scripts/ui/ui_kit.gd")

const MAX_LINES := 14
const MAX_INPUT := 60

var input: LineEdit
var send_button: Button
var log_button: Button
var log_panel: Panel
var log_label: Label
var _lines: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = KIT.make_theme()

	input = KIT.make_line_edit(self, Rect2(40, 1026, 620, 44), "说点什么…（回车发送，对手下一步时回应）", 18)
	input.max_length = MAX_INPUT
	input.text_submitted.connect(_on_submitted)

	send_button = KIT.make_button(self, Rect2(672, 1026, 110, 44), "发送", 20)
	send_button.pressed.connect(_on_send_pressed)
	log_button = KIT.make_button(self, Rect2(794, 1026, 126, 44), "对话记录", 20)
	log_button.pressed.connect(_on_log_pressed)

	log_panel = Panel.new()
	log_panel.position = Vector2(60, 590)
	log_panel.size = Vector2(840, 360)
	log_panel.add_theme_stylebox_override("panel", KIT.make_box(KIT.PANEL, 12))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.visible = false
	add_child(log_panel)

	log_label = KIT.make_label(log_panel, Rect2(20, 14, 800, 332), 18, KIT.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.clip_text = true

func add_line(who: String, text: String) -> void:
	_lines.append("%s：%s" % [who, text])
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	log_label.text = "\n".join(_lines)

func clear() -> void:
	_lines = []
	log_label.text = ""
	input.text = ""
	log_panel.visible = false

func _on_submitted(text: String) -> void:
	var t: String = text.strip_edges()
	if t == "":
		return
	input.text = ""
	input.release_focus()
	add_line("你", t)
	message_sent.emit(t)

func _on_send_pressed() -> void:
	_on_submitted(input.text)

func _on_log_pressed() -> void:
	log_panel.visible = not log_panel.visible
