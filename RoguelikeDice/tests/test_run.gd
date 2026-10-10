extends SceneTree
## Автотест: прогоняем ключевые механики без GUI (headless).
## Запуск: godot --headless --path . -s res://tests/test_run.gd

func _init() -> void:
	var fails := 0

	# 1) Оружие: урон всегда в диапазоне
	for i in 200:
		var w := Weapon.new()
		w.dmg_min = 10; w.dmg_max = 20
		var d := w.roll_damage()
		if d < 10 or d > 20:
			prints("FAIL weapon dmg", d); fails += 1
	print("Weapon damage range: OK")

	# 2) Броня: блок всегда в диапазоне
	for i in 200:
		var a := Armor.new()
		a.block_min = 5; a.block_max = 10
		var b := a.roll_block()
		if b < 5 or b > 10:
			prints("FAIL armor block", b); fails += 1
	print("Armor block range: OK")

	# 3) Игрок: уворот = ловкость * коэффициент
	var p := Player.new()
	p.agility = 10
	var dodges := 0
	for i in 1000:
		if p.try_dodge():
			dodges += 1
	# ожидаемо ~30% (10 * 0.03)
	if dodges < 180 or dodges > 420:
		prints("FAIL dodge rate", dodges); fails += 1
	else:
		print("Dodge chance ~ agility*coef: OK (", dodges, "/1000)")

	var atk := p.attack()
	if not atk.has("dmg") or atk["dmg"] <= 0:
		prints("FAIL attack", atk); fails += 1
	else:
		print("Player attack roll: OK -> ", atk)

	# 4) Опыт и повышение уровня
	var lv := p.level
	p.gain_xp(100)
	if p.level <= lv:
		print("FAIL level up"); fails += 1
	else:
		print("Level up works: lvl ", p.level, " STR ", p.strength, " AGI ", p.agility)

	# 5) Враги: генерация и симуляция полного боя
	var e := Enemy.make_random(1)
	if e.hp <= 0 or e.dmg_min > e.dmg_max:
		print("FAIL enemy gen"); fails += 1
	else:
		print("Enemy generated: ", e.name, " hp=", e.hp)

	var guard := 0
	while not p.is_dead() and guard < 10000:
		guard += 1
		var raw := randi_range(e.dmg_min, e.dmg_max)
		if not p.try_dodge():
			var blocked := mini(p.roll_block(), raw)
			p.hp = maxi(0, p.hp - (raw - blocked))
		e.hp = maxi(0, e.hp - p.attack()["dmg"])
		if e.hp == 0:
			e = Enemy.make_random(guard / 50 + 1)
	print("Combat loop simulated %d rounds without crash" % guard)

	if fails == 0:
		print("ALL TESTS PASSED")
	else:
		print("TEST FAILURES: ", fails)
	quit(1 if fails > 0 else 0)
