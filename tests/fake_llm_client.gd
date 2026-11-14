# 假的大模型客户端：按预设顺序回复，并记下收到的每个请求体。接口与 scripts/llm/llm_client.gd 相同。
# hold = true 时先不回复，等测试调 release()（用来模拟「回复还在路上」）。
extends Node

signal completed(result: Dictionary)

const CLIENT = preload("res://scripts/llm/llm_client.gd")

var replies: Array = []               # 依次弹出的回复（格式同 llm_client 的 completed 结果）
var bodies: Array = []                # 收到的请求体（深拷贝）
var hold: bool = false
var _pending: bool = false

func request_chat(_base_url: String, _api_key: String, body: Dictionary) -> void:
	bodies.append(body.duplicate(true))
	_pending = true
	if not hold:
		call_deferred("_reply")

func request_models(_base_url: String, _api_key: String) -> void:
	_pending = true
	call_deferred("_reply")

func release() -> void:
	hold = false
	if _pending:
		call_deferred("_reply")

func cancel() -> void:
	if not _pending:
		return
	_pending = false
	completed.emit(CLIENT.failure("已取消", 0, false))

func _reply() -> void:
	if not _pending:
		return
	_pending = false
	var r: Dictionary = replies.pop_front() if not replies.is_empty() else text_reply("")
	completed.emit(r)

# ---- 造回复 ----

# 一次调用一个工具
static func tool_reply(tool_name: String, args: Dictionary) -> Dictionary:
	return calls_reply([[tool_name, args]])

# 一次调用多个工具：calls = [[名字, 参数字典], ...]；参数也可以直接给字符串（模拟坏 JSON）
static func calls_reply(calls: Array) -> Dictionary:
	var tool_calls: Array = []
	for i in range(calls.size()):
		var args = calls[i][1]
		var arg_text: String = args if typeof(args) == TYPE_STRING else JSON.stringify(args)
		tool_calls.append({"id": "call_%d" % i, "type": "function",
			"function": {"name": calls[i][0], "arguments": arg_text}})
	return {"ok": true, "message": {"role": "assistant", "content": "", "tool_calls": tool_calls},
		"error": "", "fatal": false, "code": 200}

static func text_reply(text: String) -> Dictionary:
	return {"ok": true, "message": {"role": "assistant", "content": text},
		"error": "", "fatal": false, "code": 200}

static func error_reply(msg: String, fatal: bool) -> Dictionary:
	return CLIENT.failure(msg, 401 if fatal else 500, fatal)
