# 设置页（大模型对战）：API key、角色名、性格提示词、开场白开关，以及高级选项（接口地址、模型名）。
# 隐私：key 输入框默认遮挡；已保存的 key 不会回填到输入框，只在占位文字里显示首尾几位。
# 规则和下棋方法已内置在 scripts/llm/prompts.gd，玩家这里只写性格。
extends Control

signal closed()

const KIT = preload("res://scripts/ui/ui_kit.gd")
const SETTINGS = preload("res://scripts/llm/settings_store.gd")
const CLIENT = preload("res://scripts/llm/llm_client.gd")

const X := 110.0                      # 内容左边距
const W := 740.0                      # 内容宽度

var settings = null                   # main.gd 注入（settings_store.gd）
var key_edit: LineEdit
var show_key: CheckBox
var remember: CheckBox
var name_edit: LineEdit
var persona_edit: TextEdit
var counter: Label
var chatty: CheckBox
var url_edit: LineEdit
var model_edit: LineEdit
var status: Label
var save_button: Button
var cancel_button: Button
var _client = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = KIT.make_theme()
	KIT.make_overlay(self, Rect2(70, 50, 820, 980), 0.92)
	KIT.make_label(self, Rect2(X, 70, W, 50), 32, KIT.TEXT, HORIZONTAL_ALIGNMENT_CENTER).text = "设置 · AI 对战（大模型）"

	_label("DeepSeek API key", 136)
	key_edit = KIT.make_line_edit(self, Rect2(X, 168, 580, 46), "")
	key_edit.secret = true
	show_key = KIT.make_check(self, Rect2(X + 600, 172, 140, 40), "显示")
	show_key.toggled.connect(_on_show_toggled)
	remember = KIT.make_check(self, Rect2(X, 222, 420, 42), "保存到本机（公用电脑请取消）")
	KIT.make_button(self, Rect2(X + 440, 222, 140, 42), "测试连接", 18).pressed.connect(_on_test_pressed)
	KIT.make_button(self, Rect2(X + 600, 222, 140, 42), "清除 key", 18).pressed.connect(_on_clear_pressed)
	status = KIT.make_label(self, Rect2(X, 270, W, 28), 17, KIT.MUTED, HORIZONTAL_ALIGNMENT_LEFT)

	_label("角色名（显示在棋盘上，最多 %d 个字）" % SETTINGS.MAX_NAME, 310)
	name_edit = KIT.make_line_edit(self, Rect2(X, 342, 360, 46), SETTINGS.DEFAULT_NAME)
	name_edit.max_length = SETTINGS.MAX_NAME

	_label("性格提示词（可不填；规则和下法已内置，这里只写性格和说话风格）", 404)
	persona_edit = TextEdit.new()
	persona_edit.position = Vector2(X, 436)
	persona_edit.size = Vector2(W, 250)
	persona_edit.placeholder_text = "例如：你是大肥鱼，说话慢吞吞、爱打哈欠，被将军时会假装睡着。"
	persona_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	persona_edit.add_theme_font_size_override("font_size", 18)
	persona_edit.add_theme_stylebox_override("normal", KIT.make_box(KIT.PANEL2, 8))
	persona_edit.text_changed.connect(_update_counter)
	add_child(persona_edit)
	counter = KIT.make_label(self, Rect2(X, 690, W, 26), 16, KIT.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	chatty = KIT.make_check(self, Rect2(X, 720, W, 42), "开场打招呼、终局说感想（每局多 2 次小请求）")

	_label("接口地址（高级）", 772)
	url_edit = KIT.make_line_edit(self, Rect2(X, 802, W, 44), SETTINGS.DEFAULT_BASE_URL, 18)
	_label("模型名（高级）", 854)
	model_edit = KIT.make_line_edit(self, Rect2(X, 884, W, 44), SETTINGS.DEFAULT_MODEL, 18)

	save_button = KIT.make_button(self, Rect2(X + 160, 954, 200, 50), "保存", 22)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button = KIT.make_button(self, Rect2(X + 380, 954, 200, 50), "取消", 22)
	cancel_button.pressed.connect(_on_cancel_pressed)

	_client = CLIENT.new()
	add_child(_client)
	_client.completed.connect(_on_test_done)

func _label(text: String, y: float) -> void:
	KIT.make_label(self, Rect2(X, y, W, 28), 18, KIT.TEXT, HORIZONTAL_ALIGNMENT_LEFT).text = text

# 打开时从 settings 回填（key 除外：只显示遮挡后的首尾几位）
func open() -> void:
	key_edit.text = ""
	key_edit.secret = true
	show_key.button_pressed = false
	_refresh_key_placeholder()
	remember.button_pressed = settings.remember_key
	name_edit.text = settings.persona_name
	persona_edit.text = settings.persona_prompt
	chatty.button_pressed = settings.chatty
	url_edit.text = settings.base_url
	model_edit.text = settings.model
	status.text = ""
	_update_counter()
	visible = true

func _refresh_key_placeholder() -> void:
	if settings.has_key():
		key_edit.placeholder_text = "已保存：%s（留空则不修改）" % SETTINGS.mask_key(settings.api_key)
	else:
		key_edit.placeholder_text = "粘贴 DeepSeek API key（sk-…）"

func _apply_fields() -> void:
	if key_edit.text.strip_edges() != "":
		settings.api_key = key_edit.text.strip_edges()
	settings.remember_key = remember.button_pressed
	settings.persona_name = name_edit.text.strip_edges().left(SETTINGS.MAX_NAME)
	settings.persona_prompt = persona_edit.text.strip_edges().left(SETTINGS.MAX_PERSONA)
	settings.chatty = chatty.button_pressed
	settings.base_url = SETTINGS.or_default(url_edit.text, SETTINGS.DEFAULT_BASE_URL)
	settings.model = SETTINGS.or_default(model_edit.text, SETTINGS.DEFAULT_MODEL)

func _on_save_pressed() -> void:
	_apply_fields()
	if settings.save_to_disk() != OK:
		status.text = "保存失败：写不进设置文件"
		return
	_on_cancel_pressed()

func _on_cancel_pressed() -> void:
	visible = false
	closed.emit()

func _on_clear_pressed() -> void:
	settings.clear_key()
	settings.save_to_disk()
	key_edit.text = ""
	_refresh_key_placeholder()
	status.text = "已清除 key"

func _on_test_pressed() -> void:
	var key: String = key_edit.text.strip_edges()
	if key == "":
		key = settings.api_key
	if key == "":
		status.text = "请先填 API key"
		return
	status.text = "测试中…"
	_client.request_models(SETTINGS.or_default(url_edit.text, SETTINGS.DEFAULT_BASE_URL), key)

func _on_test_done(r: Dictionary) -> void:
	status.text = "连接成功，key 可用" if r["ok"] else "连接失败：" + str(r["error"])

func _on_show_toggled(on: bool) -> void:
	key_edit.secret = not on

func _update_counter() -> void:
	counter.text = "%d / %d" % [persona_edit.text.length(), SETTINGS.MAX_PERSONA]
