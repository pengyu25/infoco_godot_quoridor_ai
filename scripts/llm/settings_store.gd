# 大模型对战的设置：API key、角色名、性格提示词、开场白开关、接口地址、模型名。
# 存在 user://（桌面版 = 系统用户目录，Web 版 = 浏览器本地存储），不进仓库。
# 注意：这只是本地明文保存，不是加密；取消「保存到本机」时 key 只留在内存里，关掉游戏就没了。
extends RefCounted

const DEFAULT_PATH := "user://llm_settings.cfg"
const DEFAULT_BASE_URL := "https://api.deepseek.com"
const DEFAULT_MODEL := "deepseek-flash"
const DEFAULT_NAME := "AI 棋友"
const MAX_NAME := 8
const MAX_PERSONA := 1000

var path: String = DEFAULT_PATH
var api_key: String = ""
var remember_key: bool = true
var persona_name: String = ""
var persona_prompt: String = ""
var chatty: bool = true                  # 开场打招呼 + 终局说感想
var base_url: String = DEFAULT_BASE_URL
var model: String = DEFAULT_MODEL

func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	api_key = String(cfg.get_value("llm", "api_key", ""))
	remember_key = bool(cfg.get_value("llm", "remember_key", true))
	persona_name = String(cfg.get_value("llm", "persona_name", ""))
	persona_prompt = String(cfg.get_value("llm", "persona_prompt", ""))
	chatty = bool(cfg.get_value("llm", "chatty", true))
	base_url = String(cfg.get_value("llm", "base_url", DEFAULT_BASE_URL))
	model = String(cfg.get_value("llm", "model", DEFAULT_MODEL))

# 不勾「保存到本机」时，文件里的 key 会被清空（内存里的仍可用到关掉游戏）
func save_to_disk() -> int:
	var cfg := ConfigFile.new()
	cfg.set_value("llm", "api_key", api_key if remember_key else "")
	cfg.set_value("llm", "remember_key", remember_key)
	cfg.set_value("llm", "persona_name", persona_name)
	cfg.set_value("llm", "persona_prompt", persona_prompt)
	cfg.set_value("llm", "chatty", chatty)
	cfg.set_value("llm", "base_url", base_url)
	cfg.set_value("llm", "model", model)
	return cfg.save(path)

func has_key() -> bool:
	return api_key.strip_edges() != ""

func clear_key() -> void:
	api_key = ""

func display_name() -> String:
	var n: String = persona_name.strip_edges()
	if n == "":
		return DEFAULT_NAME
	return n.left(MAX_NAME)

# 输入框留空就用默认值（接口地址、模型名用）
static func or_default(text: String, fallback: String) -> String:
	var t: String = text.strip_edges()
	return t if t != "" else fallback

# 只露首 3 位和尾 4 位，例如 sk-****ab12；太短就全遮
static func mask_key(key: String) -> String:
	var k: String = key.strip_edges()
	if k.length() <= 8:
		return "****"
	return k.left(3) + "****" + k.right(4)
