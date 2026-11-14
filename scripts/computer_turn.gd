# 电脑回合调度：在不卡死画面的前提下让电脑算一步，算完发 move_ready。
#   Web 版不能开线程，计算会占住主线程 → 先等两帧，让「电脑思考中…」画出来再算
#   算得太快就补足 MIN_THINK_MS（秒下显得突兀）
#   中途调 cancel()（玩家点了重开 / 菜单）→ 这次结果作废，不会落到新局上
# 对外只认「给局面、返回一步棋」：以后换别的对手（例如接大模型）只需改 _compute()。
extends Node

signal move_ready(move: Dictionary)

const AI = preload("res://scripts/ai/ai_player.gd")

const MIN_THINK_MS := 400

var _token: int = 0                    # 每次 start / cancel +1；算完发现对不上就丢弃
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

# 协程：调用方不用 await，结果从 move_ready 信号拿。state 只读，不会被修改
func start(state, preset: Dictionary) -> void:
	_token += 1
	var my_token: int = _token
	var started: int = Time.get_ticks_msec()

	await get_tree().process_frame
	await get_tree().process_frame
	if my_token != _token:
		return

	var mv: Dictionary = _compute(state, preset)

	var wait_ms: int = MIN_THINK_MS - (Time.get_ticks_msec() - started)
	if wait_ms > 0:
		await get_tree().create_timer(wait_ms / 1000.0).timeout
	if my_token != _token:
		return
	move_ready.emit(mv)

func cancel() -> void:
	_token += 1

func _compute(state, preset: Dictionary) -> Dictionary:
	return AI.choose_move(state, preset, _rng)
