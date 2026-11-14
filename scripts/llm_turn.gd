# 大模型回合调度：把局面交给 llm_agent.gd 去问大模型，拿到着法和台词后发信号。
# 出错就由本地「中」档电脑代下这一步，对局不会卡住；key 无效 / 余额不足时，本局后面不再请求。
# 开场白 / 终局感言走另一个客户端，不和下棋请求抢通道。
extends Node

signal move_ready(move: Dictionary)
signal said(text: String, is_system: bool)

const AGENT = preload("res://scripts/llm/llm_agent.gd")
const CLIENT = preload("res://scripts/llm/llm_client.gd")
const P = preload("res://scripts/llm/prompts.gd")
const N = preload("res://scripts/llm/notation.gd")
const AI = preload("res://scripts/ai/ai_player.gd")
const DIFF = preload("res://scripts/ai/difficulty.gd")

const FALLBACK_LEVEL := "normal"
const MAX_RECENT := 8                   # 提示词里带最近几句对话

var settings = null
var client = null                       # 下棋用；测试脚本可在加入场景树前换成假客户端
var chat_client = null                  # 开场白 / 终局感言用
var _agent = AGENT.new()
var _turn_token: int = 0                # 每回合 / 每次作废 +1；回复到了发现对不上就丢弃
var _game_token: int = 0                # 每局 +1；开场白 / 感言用
var _offline: bool = false
var _recent: Array = []                 # 「玩家：…」「你：…」
var _pending_chat: Array = []           # 玩家这期间在聊天框说的话，跟着下一次请求发出去
var _last_player_move: String = ""
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if client == null:
		client = CLIENT.new()
		add_child(client)
	if chat_client == null:
		chat_client = CLIENT.new()
		add_child(chat_client)

# 开新局 / 回菜单：作废进行中的请求，清空对话
func reset() -> void:
	_turn_token += 1
	_game_token += 1
	client.cancel()
	chat_client.cancel()
	_offline = false
	_recent = []
	_pending_chat = []
	_last_player_move = ""

func add_player_chat(text: String) -> void:
	_pending_chat.append(text)

func note_player_move(move: Dictionary) -> void:
	_last_player_move = N.describe(move)

# 协程：调用方不用 await，结果从 move_ready / said 信号拿。state 只读
func start(state, me: int) -> void:
	_turn_token += 1
	var my_token: int = _turn_token
	await get_tree().process_frame            # 先让「思考中…」画出来
	if my_token != _turn_token:
		return
	if _offline:
		move_ready.emit(_fallback_move(state))
		return

	var msg: String = P.turn_message(state, me, _last_player_move, _pending_chat, _recent)
	for line in _pending_chat:
		_remember("玩家：" + line)
	_pending_chat = []

	var r: Dictionary = await _agent.play_turn(client, settings, state, me, msg)
	if my_token != _turn_token:
		return
	if r["move"].is_empty():
		_offline = r["fatal"]
		var tail: String = "，本局后面都由电脑代下，请到设置里检查" if _offline else "，这步由电脑代下"
		said.emit("（%s走神了：%s%s）" % [settings.display_name(), r["error"], tail], true)
		move_ready.emit(_fallback_move(state))
		return
	_remember("你：" + r["say"])
	said.emit(r["say"], false)
	move_ready.emit(r["move"])

func greet() -> void:
	_chatter(P.greeting_message())

func farewell(ai_won: bool) -> void:
	_chatter(P.ending_message(ai_won))

# 不下棋、只说一句（设置里关掉就不说）
func _chatter(prompt: String) -> void:
	if not settings.chatty or _offline:
		return
	var my_game: int = _game_token
	var text: String = await _agent.speak(chat_client, settings, prompt)
	if my_game != _game_token or text == "":
		return
	_remember("你：" + text)
	said.emit(text, false)

func _fallback_move(state) -> Dictionary:
	return AI.choose_move(state, DIFF.get_preset(FALLBACK_LEVEL), _rng)

func _remember(line: String) -> void:
	_recent.append(line)
	while _recent.size() > MAX_RECENT:
		_recent.pop_front()
