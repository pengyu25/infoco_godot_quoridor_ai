# 人的回合：把棋盘点击 / 「放墙模式」按钮翻译成着法。只在 begin() 之后、stop() 之前响应。
# 自己不改局面：选好一步就发 move_chosen，由 main.gd 去执行。
extends Node

signal move_chosen(move: Dictionary)
signal changed()                          # 选中格 / 可走点 / 放墙模式变了，需要重绘
signal hint(text: String)

const RM = preload("res://scripts/rules/rule_moves.gd")
const NONE := Vector2i(-1, -1)

var state = null
var active: bool = false
var selected: Vector2i = NONE
var legal_targets: Array = []
var wall_mode: bool = false
var pawn_hint: String = "先点自己的棋子"    # 没选中棋子就点了别处时的提示（main 按模式设置）

func begin(new_state) -> void:
	state = new_state
	active = true
	_clear_selection()

func stop() -> void:
	active = false
	wall_mode = false
	_clear_selection()

func on_cell_clicked(cell: Vector2i) -> void:
	if not active:
		return
	if wall_mode:
		hint.emit("放墙模式开着：关掉它才能走子")
		return

	# 点自己的棋子 → 选中并显示可走位置
	if cell == state.pawns[state.turn]:
		selected = cell
		legal_targets = []
		for m in RM.pawn_moves(state, state.turn):
			legal_targets.append(m["to"])
		changed.emit()
		return

	# 已选中棋子，再点目标格
	if selected != NONE:
		var mv := {"type": "move", "to": cell}
		if RM.is_legal(state, mv):
			move_chosen.emit(mv)
			return
		_clear_selection()
		changed.emit()
		hint.emit("那格走不过去")
		return

	hint.emit(pawn_hint)

func on_wall_clicked(kind: String, x: int, y: int) -> void:
	if not active:
		return
	if not wall_mode:
		hint.emit("想放墙请先点「放墙模式」")
		return
	var mv := {"type": kind, "x": x, "y": y}
	if RM.is_legal(state, mv):
		move_chosen.emit(mv)
	else:
		hint.emit("这里不能放墙（重叠／交叉／墙数不足／会封死通路）")

func on_wall_mode_toggled(on: bool) -> void:
	if not active:
		return
	wall_mode = on
	_clear_selection()
	changed.emit()
	hint.emit("放墙模式：点格线附近放墙" if on else "")

func _clear_selection() -> void:
	selected = NONE
	legal_targets = []
