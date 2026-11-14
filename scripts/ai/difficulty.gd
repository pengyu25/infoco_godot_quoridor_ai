# 难度参数表：改难度只动这里（技术骨架第 7 节）。
# 分数单位：100 分 = 一步路（见 ai_eval.gd 的 STEP）。
extends RefCounted

const LEVELS := ["easy", "normal", "hard"]     # 菜单按这个顺序列出

const PRESETS := {
	"easy": {
		"label": "低",
		"search_depth": 0,       # 0 = 不往后看：只挑走完离终点最近的一步
		"random": 0.35,          # 有这么大概率随便走一步
		"use_walls": false,      # 不放墙
		"wall_candidates": 0,    # 每个局面最多考虑几个墙位
		"wall_weight": 0,        # 手里每多一堵墙加几分（防止乱花墙）
		"time_budget_ms": 0,     # 每步思考上限（搜索档才有用）
	},
	"normal": {
		"label": "中",
		"search_depth": 2,       # 我走一步 + 你回一步
		"random": 0.10,          # 有这么大概率改走次优（只在次优差距不到一步时）
		"use_walls": true,
		"wall_candidates": 6,
		"wall_weight": 15,
		"time_budget_ms": 500,
	},
	"hard": {
		"label": "高",
		"search_depth": 3,       # 逐层加深到 3 层；超时就用已算完的那层
		"random": 0.0,
		"use_walls": true,
		"wall_candidates": 10,
		"wall_weight": 15,
		"time_budget_ms": 1000,
	},
}

static func get_preset(level: String) -> Dictionary:
	if PRESETS.has(level):
		return PRESETS[level]
	return PRESETS["normal"]

static func label_of(level: String) -> String:
	return String(get_preset(level)["label"])
