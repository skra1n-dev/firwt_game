class_name Armor
extends Resource
## Броня: в свой ход она блокирует случайный объём урона из диапазона [block_min .. block_max].
## (Вместо «умножения на фиксированное число» проще и нагляднее сразу задавать диапазон блока —
##  при желании легко вернуть умножение: block_value = randi_range(min,max) * MULT.)

@export var armor_name: String = "Тряпьё"
@export var block_min: int = 1
@export var block_max: int = 3
@export var price: int = 15


## Сколько урона броня способна заблокировать в этом ходу.
func roll_block() -> int:
	return randi_range(block_min, block_max)
