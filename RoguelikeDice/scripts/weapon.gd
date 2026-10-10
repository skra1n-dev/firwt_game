class_name Weapon
extends Resource
## Оружие: урон определяется броском в диапазоне [dmg_min .. dmg_max].
## Крит тоже решает рандом: chance_crit — вероятность (0..1), crit_mult — множитель урона.

@export var weapon_name: String = "Кулаки"
@export var dmg_min: int = 2
@export var dmg_max: int = 5
@export var crit_chance: float = 0.05   # 5% шанс крита
@export var crit_mult: float = 2.0      # крит удваивает урон
@export var price: int = 20             # примерная цена для магазина


## Бросок урона оружия (случайное число из диапазона).
func roll_damage() -> int:
	return randi_range(dmg_min, dmg_max)


## Проверка крита. Возвращает [итоговый_урон, был_крит].
func attack() -> Array:
	var dmg := roll_damage()
	if randf() < crit_chance:
		return [int(round(dmg * crit_mult)), true]
	return [dmg, false]
