class_name Enemy
extends RefCounted
## Враг. Все его характеристики тоже живут на рандоме.

var name: String
var max_hp: int
var hp: int
var dmg_min: int
var dmg_max: int
var dodge_stat: int          # «ловкость» врага
var xp_reward: int
var gold_reward: int


func _init(p_name: String, p_hp: int, p_dmin: int, p_dmax: int, p_dodge: int, p_xp: int, p_gold: int) -> void:
	name = p_name
	max_hp = p_hp
	hp = p_hp
	dmg_min = p_dmin
	dmg_max = p_dmax
	dodge_stat = p_dodge
	xp_reward = p_xp
	gold_reward = p_gold


static func make_random(depth: int) -> Enemy:
	## Генерирует случайного врага, чуть более сильного с глубиной.
	var pool := [
		["Гоблин", 18, 3, 7],
		["Крыса-переросток", 12, 2, 5],
		["Скелет", 24, 4, 9],
		["Орк", 30, 5, 11],
		["Тёмный маг", 20, 6, 14],
		["Каменный голем", 40, 3, 8],
	]
	var pick: Array = pool.pick_random()
	var scale := 1.0 + depth * 0.15   # враги усиливаются с глубиной
	var hp := int(pick[1] * scale)
	var e := Enemy.new(pick[0] + " (Ур.%d)" % (depth + 1), hp,
			int(pick[2] * scale), int(pick[3] * scale),
			randi_range(2, 8),                      # случайная ловкость
			5 + depth * 3,                           # опыт
			randi_range(5, 15) + depth * 2)          # золото
	return e
