# 大模型接口的最小客户端（DeepSeek / OpenAI 兼容格式）。一次只处理一个请求，结果从 completed 信号拿。
# 用 HTTPRequest：异步、不卡画面，桌面版和 Web 版都能用（DeepSeek 允许浏览器跨域直连，2026-11 实测）。
# 隐私：不打印、不保存 API key；错误信息里如果出现 key 也会被抹掉。
extends Node

signal completed(result: Dictionary)      # {"ok", "message", "error", "fatal", "code"}

const TIMEOUT_S := 20.0
const KEY_MASK := "sk-****"

var _http: HTTPRequest
var _busy: bool = false
var _key: String = ""

func _ready() -> void:
	_ensure_http()

# 节点刚加进场景树、_ready 还没跑时也可能被调用，所以按需创建
func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_S
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

# 调 chat/completions；body 是 OpenAI 兼容格式的请求体
func request_chat(base_url: String, api_key: String, body: Dictionary) -> void:
	_send(_join(base_url, "/chat/completions"), api_key, HTTPClient.METHOD_POST, JSON.stringify(body))

# 调 GET /models 测试 key 能不能用（不产生费用）
func request_models(base_url: String, api_key: String) -> void:
	_send(_join(base_url, "/models"), api_key, HTTPClient.METHOD_GET, "")

# 放弃进行中的请求；等待中的一方会收到「已取消」
func cancel() -> void:
	if not _busy:
		return
	_http.cancel_request()
	_busy = false
	completed.emit(failure("已取消", 0, false))

func _send(url: String, api_key: String, method: int, data: String) -> void:
	if _busy:
		call_deferred("emit_signal", "completed", failure("上一个请求还没结束", 0, false))
		return
	_ensure_http()
	_key = api_key.strip_edges()
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _key])
	_busy = true
	var err: int = _http.request(url, headers, method, data)
	if err != OK:
		_busy = false
		call_deferred("emit_signal", "completed", failure("请求没发出去（%s）" % error_string(err), 0, false))

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _busy:
		return                                # 已被 cancel()，结果作废
	_busy = false
	completed.emit(parse_response(result, code, body.get_string_from_utf8(), _key))

static func _join(base_url: String, path: String) -> String:
	return base_url.strip_edges().trim_suffix("/") + path

static func failure(msg: String, code: int, fatal: bool) -> Dictionary:
	return {"ok": false, "message": {}, "error": msg, "fatal": fatal, "code": code}

# 把 HTTP 结果翻译成统一格式。fatal = key 无效 / 余额不足这类重试也没用的错误
static func parse_response(result: int, code: int, text: String, key: String) -> Dictionary:
	if result == HTTPRequest.RESULT_TIMEOUT:
		return failure("等了太久没有回应", 0, false)
	if result != HTTPRequest.RESULT_SUCCESS:
		return failure("网络连接失败", 0, false)
	if code == 401:
		return failure("API key 无效", code, true)
	if code == 402:
		return failure("账户余额不足", code, true)
	if code == 429:
		return failure("请求太频繁，稍后再试", code, false)
	if code >= 500:
		return failure("服务暂时不可用（HTTP %d）" % code, code, false)
	var data = JSON.parse_string(text)
	if code != 200:
		return failure(_redact("请求出错（HTTP %d）%s" % [code, _api_message(data)], key), code, false)
	if typeof(data) != TYPE_DICTIONARY:
		return failure("回复格式看不懂", code, false)
	var message: Dictionary = {}
	var choices = data.get("choices")
	if typeof(choices) == TYPE_ARRAY and not choices.is_empty() and typeof(choices[0]) == TYPE_DICTIONARY:
		var m = choices[0].get("message")
		if typeof(m) == TYPE_DICTIONARY:
			message = m
	return {"ok": true, "message": message, "error": "", "fatal": false, "code": code}

static func _api_message(data) -> String:
	if typeof(data) == TYPE_DICTIONARY and typeof(data.get("error")) == TYPE_DICTIONARY:
		return "：" + str(data["error"].get("message", "")).left(80)
	return ""

static func _redact(text: String, key: String) -> String:
	if key.length() >= 8:
		return text.replace(key, KEY_MASK)
	return text
