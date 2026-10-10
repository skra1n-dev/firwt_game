extends SceneTree
## Автотест: прогоняем ключевые механики без GUI (headless).
## Запуск: godot --headless --path . -s res://tests/test_run.gd
## ВАЖНО: классы загружаем через load() и храним в переменных типа Object —
## в режиме --script глобальный реестр class_name ещё не готов, а такой
## способ работает одинаково и с кэшем .godot/, и с чистой копией проекта.

func _init() -> void:
	var fails := 0
	var weapon_cls: Object = load("res://scripts/weapon.gd")
	var armor_cls: Object = load("res://scripts/armor.gd")
	var player_cls: Object = load("res://scripts/player.gd")
	var enemy_cls: Object = preload("res://scripts/enemy.gd")  # preload: сам регистрирует class_name Enemy

	# 1) Оружие: урон всегда в диапазоне min..max
	for i in 200:
		var w: Object = weapon_cls.new()
		w.set("dmg_min", 10); w.set("dmg_max", 20)
		var d: int = w.call("roll_damage")
		if d < 10 or d > 20:
			prints("FAIL weapon dmg", d); fails += 1
	print("Weapon damage range: OK")

	# 2) Броня: блок всегда в диапазоне min..max
	for i in 200:
		var a: Object = armor_cls.new()
		a.set("block_min", 5); a.set("block_max", 10)
		var b: int = a.call("roll_block")
		if b < 5 or b > 10:
			prints("FAIL armor block", b); fails += 1
	print("Armor block range: OK")

	# 3) Игрок: шанс уворота = ловкость * фиксированный коэффициент
	var p: Object = player_cls.new()
	p.set("agility", 10)
	var dodges := 0
	for i in 1000:
		if p.call("try_dodge"):
			dodges += 1
	# ожидаемо ~30% (10 * 0.03), допускаем разброс
	if dodges < 180 or dodges > 420:
		prints("FAIL dodge rate", dodges); fails += 1
	else:
		print("Dodge chance ~ agility*coef: OK (", dodges, "/1000)")

	var atk: Dictionary = p.call("attack")
	if not atk.has("dmg") or atk["dmg"] <= 0:
		prints("FAIL attack", atk); fails += 1
	else:
		print("Player attack roll: OK -> ", atk)

	# 4) Опыт и повышение уровня
	var lv: int = p.get("level")
	p.call("gain_xp", 100)
	if p.get("level") <= lv:
		print("FAIL level up"); fails += 1
	else:
		print("Level up works: lvl ", p.get("level"), " STR ", p.get("strength"), " AGI ", p.get("agility"))

	# 5) Враги: генерация и симуляция полного боя до победы/смерти
	var e: Object = enemy_cls.call("make_random", 1)
	if e.get("hp") <= 0 or e.get("dmg_min") > e.get("dmg_max"):
		print("FAIL enemy gen"); fails += 1
	else:
		print("Enemy generated: ", e.get("name"), " hp=", e.get("hp"))

	var guard := 0
	while not p.call("is_dead") and guard < 10000:
		guard += 1
		var raw: int = randi_range(e.get("dmg_min"), e.get("dmg_max"))
		if not p.call("try_dodge"):
			var blocked: int = mini(p.call("roll_block"), raw)
			p.set("hp", maxi(0, p.get("hp") - (raw - blocked)))
		e.set("hp", maxi(0, e.get("hp") - p.call("attack")["dmg"]))
		if e.get("hp") == 0:
			e = enemy_cls.call("make_random", guard / 50 + 1)
	print("Combat loop simulated %d rounds without crash" % guard)

	if fails == 0:
		print("ALL TESTS PASSED")
	else:
		print("TEST FAILURES: ", fails)
	quit(1 if fails > 0 else 0)
