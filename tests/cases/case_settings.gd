# 用例：设置存储 —— 不勾「保存到本机」时 key 不落盘、读写往返、key 遮挡、默认角色名
# 用临时文件，不碰玩家真实的设置。
extends RefCounted

const SETTINGS = preload("res://scripts/llm/settings_store.gd")

const PATH := "user://test_llm_settings.cfg"
const KEY := "sk-test-abcdefghijklmnop"

static func run(t) -> void:
	var s = SETTINGS.new()
	s.path = PATH
	s.api_key = KEY
	s.remember_key = false
	s.persona_name = "大肥鱼"
	s.persona_prompt = "慢吞吞"
	t.eq(s.save_to_disk(), OK, "settings saved")
	t.check(not FileAccess.get_file_as_string(PATH).contains("abcdefgh"), "key not written when remember is off")

	var loaded = SETTINGS.new()
	loaded.path = PATH
	loaded.load_from_disk()
	t.eq(loaded.api_key, "", "no key after reload when remember is off")
	t.eq(loaded.persona_name, "大肥鱼", "persona name reloaded")
	t.eq(loaded.persona_prompt, "慢吞吞", "persona prompt reloaded")
	t.eq(loaded.model, SETTINGS.DEFAULT_MODEL, "default model is deepseek-flash")

	s.remember_key = true
	s.save_to_disk()
	var again = SETTINGS.new()
	again.path = PATH
	again.load_from_disk()
	t.eq(again.api_key, KEY, "key reloaded when remember is on")

	t.eq(SETTINGS.mask_key(KEY), "sk-****mnop", "mask shows only the ends")
	t.eq(SETTINGS.mask_key("short"), "****", "short key fully masked")
	var blank = SETTINGS.new()
	t.eq(blank.display_name(), SETTINGS.DEFAULT_NAME, "default name when empty")
	blank.persona_name = "一二三四五六七八九十"
	t.eq(blank.display_name().length(), SETTINGS.MAX_NAME, "long name clipped")
	t.check(not blank.has_key(), "no key by default")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
