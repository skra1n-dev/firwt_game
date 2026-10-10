class_name Player
extends RefCounted
## Игрок. Ключевые рандом-механики:
##  - урон оружия: случайное число из диапазона оружия;
##  - блок брони: случайное число из диапазона брони (каждый ход по-новому);
##  - вероятность уворота = ловкость * DODGE_COEF (фиксированное число из вашей идеи);
##  - каждое действие тоже проверяется броском d20 (см. main.gd).

const DODGE_COEF := 0.03   # фиксированный множитель ловкости -> шанс уворота (10 лк = 30%)
const MAX_DODGE := 0.60    # но не больше 60%, иначе игра сломается

var name: String = "Герой"
var level: int = 1
var xp: int = 0
var xp_needed: int = 20
var gold: int = 30

var max_hp: int = 50
var hp: int = 50
var strength: int = 5      # влияет на урон (плюс к броску) и HP при повышении уровня
var agility: int = 5       # влияет на уворот

var weapon: Resource  # Weapon (см. scripts/weapon.gd)
var armor: Resource  # Armor (см. scripts/armor.gd)


func _init() -> void:
	weapon = WeaponsDB.fists()
	armor = ArmorsDB.rags()
	hp = max_hp


## Шанс уворота игрока (0..MAX_DODGE).
func dodge_chance() -> float:
	return minf(agility * DODGE_COEF, MAX_DODGE)


## Попытка уклониться — чистый рандом.
func try_dodge() -> bool:
	return randf() < dodge_chance()


## Атака: бросок урона оружия + прибавка за силу + проверка крита.
func attack() -> Dictionary:
	var res := weapon.attack()          # [урон, крит]
	var dmg: int = res[0] + strength / 2    # сила даёт плоскую прибавку к броску (int-деление)
	return {"dmg": dmg, "crit": res[1], "weapon": weapon.weapon_name}


## Сколько брони заблокирует в этом ходу.
func roll_block() -> int:
	return armor.roll_block()


func gain_xp(amount: int) -> bool:
	## Возвращает true, если произошёл повышение уровня.
	xp += amount
	var leveled := false
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = int(xp_needed * 1.5)
		strength += randi_range(1, 3)     # прокачка тоже через рандом!
		agility += randi_range(1, 3)
		max_hp += randi_range(5, 10)
		hp = mini(max_hp, hp + randi_range(8, 15))
		leveled = true
	return leveled


func is_dead() -> bool:
	return hp <= 0


# ---------- Небольшая база предметов (для инвентаря/лутования) ----------

class WeaponsDB:
	static func fists() -> Weapon:
		return _w("Кулаки", 2, 5, 0.05, 20)
	static func dagger() -> Weapon:
		return _w("Кинжал", 4, 9, 0.20, 40)
	static func sword() -> Weapon:
		return _w("Меч", 8, 14, 0.10, 90)
	static func axe() -> Weapon:
		return _w("Боевой топор", 10, 20, 0.12, 130)
	static func greatsword() -> Weapon:
		return _w("Двуручный меч", 14, 26, 0.08, 200)

	static func random_for_level(depth: int) -> Weapon:
		var pool := [dagger(), sword(), axe(), greatsword()]
		var w: Resource = pool.pick_random()
		# с глубиной подкручиваем диапазон вверх
		w.dmg_min += depth
		w.dmg_max += depth + randi_range(0, 3)
		return w

	static func _w(n: String, mn: int, mx: int, crit: float, p: int) -> Weapon:
		var w := Weapon.new()
		w.weapon_name = n; w.dmg_min = mn; w.dmg_max = mx
		w.crit_chance = crit; w.price = p
		return w


class ArmorsDB:
	static func rags() -> Armor:
		return _a("Тряпьё", 1, 3, 10)
	static func leather() -> Armor:
		return _a("Кожаная броня", 3, 7, 50)
	static func chain() -> Armor:
		return _a("Кольчуга", 5, 10, 110)
	static func plate() -> Armor:
		return _a("Латы", 8, 15, 200)

	static func random_for_level(depth: int) -> Armor:
		var a: Resource = [leather(), chain(), plate()].pick_random()
		a.block_min += depth
		a.block_max += depth + randi_range(0, 3)
		return a

	static func _a(n: String, mn: int, mx: int, p: int) -> Armor:
		var a := Armor.new()
		a.armor_name = n; a.block_min = mn; a.block_max = mx; a.price = p
		return a
