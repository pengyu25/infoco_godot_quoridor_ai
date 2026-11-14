# 截图目检工具：跑 20 帧后把画面存成 PNG（交付前用它确认字体/棋盘/墙都画对了）
# 用法：godot --path "<项目>" --script res://tests/shot.gd
extends SceneTree

const OUT_PATH := "res://tmp_shot.png"

var _frames: int = 0

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 20:
		var img: Image = root.get_texture().get_image()
		img.save_png(OUT_PATH)
		print("saved: ", OUT_PATH)
		quit(0)
	return false
