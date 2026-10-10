extends Control
## Главная сцена прототипа: пошаговый бой с бросками кубика (d20).
## Каждое действие игрока проходит через «проверку ловкости/силы» — бросок d20,
## как в DnD. Исход атаки зависит от того, насколько высок бросок.

enum State { EXPLORE, COMBAT, SHOP, GAME_OVER }

const D20_CRIT := 20   # натуральная 20 — всегда лучший исход
const D20_FUMBLE := 1  # натуральная 1 — промах/невезение

var state: State = State.EXPLORE
var player := Player.new()
var enemy: RefCounted  # Enemy (см. scripts/enemy.gd)
var depth := 1              # «глубина подземелья», растёт с победой
var combat_turn := "player"
var shield_value := 0       # временный щит от действия «Защититься» (сбрасывается в конце хода)


# ---------- UI ----------
var log_label: RichTextLabel
var stats_label: Label
var dice_label: Label
var hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var action_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	_set_state(State.EXPLORE)
	_log("Добро пожаловать в RoguelikeDice! Здесь всё решает рандом.")
	_log("Нажмите [Исследовать], чтобы найти врага, сокровище или лавку.")


func _build_ui() -> void:
	# Фон
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16; root.offset_top = 12
	root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	root.add_child(stats_label)

	var bars := HBoxContainer.new()
	root.add_child(bars)
	hp_bar = _make_bar(Color(0.8, 0.2, 0.2))
	bars.add_child(hp_bar)
	enemy_hp_bar = _make_bar(Color(0.7, 0.3, 0.8))
	bars.add_child(enemy_hp_bar)

	dice_label = Label.new()
	dice_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	dice_label.text = "Кубик: —"
	root.add_child(dice_label)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	root.add_child(log_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	root.add_child(hbox)

	_add_button(hbox, "Исследовать", _on_explore)
	_add_button(hbox, "Атаковать", _on_attack)
	_add_button(hbox, "Защититься", _on_defend)
	_add_button(hbox, "Отступить", _on_flee)
	_add_button(hbox, "Лавка: купить оружие", _on_buy_weapon)
	_add_button(hbox, "Лавка: купить броню", _on_buy_armor)
	_add_button(hbox, "Лавка: выйти", _on_leave_shop)
	_add_button(hbox, "Начать заново", _on_restart)

	_refresh_ui()


func _make_bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(460, 22)
	b.show_percentage = false
	b.modulate = col
	return b


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	parent.add_child(btn)
	action_buttons.append(btn)
	return btn


# ---------- Логика состояний ----------

func _set_state(s: State) -> void:
	state = s
	_refresh_ui()


func _refresh_ui() -> void:
	var stats_text := "HP: %d/%d | Ур.: %d (%d/%d XP) | Золото: %d | Оружие: %s (%d-%d) | Броня: %s (блок %d-%d) | Уворот: %d%% | Глубина: %d"
	stats_label.text = stats_text % [player.hp, player.max_hp, player.level, player.xp, player.xp_needed, player.gold,
			player.weapon.weapon_name, player.weapon.dmg_min, player.weapon.dmg_max,
			player.armor.armor_name, player.armor.block_min, player.armor.block_max,
			int(player.dodge_chance() * 100), depth]
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	if enemy:
		enemy_hp_bar.visible = true
		enemy_hp_bar.max_value = enemy.max_hp
		enemy_hp_bar.value = enemy.hp
	else:
		enemy_hp_bar.visible = false

	for btn in action_buttons:
		btn.visible = _button_allowed(btn.text)


func _button_allowed(text: String) -> bool:
	match state:
		State.EXPLORE:
			return text == "Исследовать"
		State.COMBAT:
			return text in ["Атаковать", "Защититься", "Отступить"]
		State.SHOP:
			return text.begins_with("Лавка")
		State.GAME_OVER:
			return text == "Начать заново"
	return false


# ---------- Броски ----------

func roll_d20() -> int:
	var r := randi_range(1, 20)
	dice_label.text = "🎲 Выпало: %d%s" % [r,
			"  — КРИТ!" if r == D20_CRIT else ("  — ПРОВАЛ!" if r == D20_FUMBLE else "")]
	return r


# ---------- События кнопок ----------

func _on_explore() -> void:
	var roll := roll_d20()
	# Ищем приключение: чем глубже, тем чаще враги
	if roll >= 6 or depth > 3:
		spawn_enemy()
		_set_state(State.COMBAT)
	elif roll >= 3:
		var loot := randi_range(5, 20) + depth * 2
		player.gold += loot
		_log("Вы нашли свиток с золотом: +%d 💰" % loot)
	else:
		var heal := randi_range(5, 15)
		player.hp = mini(player.max_hp, player.hp + heal)
		_log("Вы нашли зелье: +%d ❤" % heal)
	_refresh_ui()


func spawn_enemy() -> void:
	enemy = Enemy.make_random(depth)
	combat_turn = "player"
	_log("⚔ Появился враг: %s (HP %d, урон %d-%d)" % [enemy.name, enemy.hp, enemy.dmg_min, enemy.dmg_max])


func _on_attack() -> void:
	if state != State.COMBAT or combat_turn != "player":
		return
	var roll := roll_d20()
	if roll == D20_FUMBLE:
		_log("💥 Провал! Вы споткнулись и уронили оружие. Ход потерян.")
		_enemy_turn()
		_check_end()
		_refresh_ui()
		return

	var atk := player.attack()
	# Модификатор броска: натуральная 20 — крит ×2; попадание = d20 + ловкость/2 против уклонения врага.
	var hit_roll := roll + int(player.agility / 2)
	var enemy_evasion := randi_range(1, 10) + int(enemy.dodge_stat / 2)
	if hit_roll < enemy_evasion and roll != D20_CRIT:
		_log("Ваш удар (%d+%d=%d) не достигает цели: враг уклонился (защита %d)."
				% [roll, int(player.agility / 2), hit_roll, enemy_evasion])
	else:
		var dmg: int = atk["dmg"]
		var mult := ""
		if roll == D20_CRIT:
			dmg *= 2
			mult = " ✦ КРИТИЧЕСКИЙ УДАР (натуральная 20) ×2"
		enemy.hp = maxi(0, enemy.hp - dmg)
		_log("Вы бьёте '%s': бросок урона %d-%d → %d ед.%s"
				% [atk["weapon"], player.weapon.dmg_min, player.weapon.dmg_max, dmg, mult])
		if enemy.hp <= 0:
			_on_victory()
			_refresh_ui()
			return
	_enemy_turn()
	_check_end()
	_refresh_ui()


func _on_defend() -> void:
	if state != State.COMBAT or combat_turn != "player":
		return
	roll_d20()
	# В защите вы получаете щит: случайный блок брони ×2 (фиксированный множитель защиты).
	shield_value = player.roll_block() * 2
	player.hp = mini(player.max_hp, player.hp + randi_range(1, 4))
	_log("🛡 Вы встаёте в оборону: щит на %d ед. урона и немного HP." % shield_value)
	_enemy_turn()
	_check_end()
	_refresh_ui()


func _on_flee() -> void:
	roll_d20()
	var chance := clampf(0.3 + player.agility * 0.02, 0.1, 0.8)
	if randf() < chance:
		_log("🏃 Вы сбежали из боя!")
		enemy = null
		_set_state(State.EXPLORE)
	else:
		_log("Сбежать не удалось!")
		_enemy_turn()
		_check_end()
	_refresh_ui()


func _enemy_turn() -> void:
	if enemy == null or enemy.hp <= 0:
		return
	var raw := randi_range(enemy.dmg_min, enemy.dmg_max)
	_enemy_strike(raw)
	shield_value = 0   # щит действует только один ход
	combat_turn = "player"


func _enemy_strike(raw_damage: int) -> void:
	# Очередность защиты как в вашей идее: сначала уворот (ловкость × коэф.),
	# затем случайный блок брони (+ щит, если встали в оборону).
	if player.try_dodge():
		_log("%s атакует на %d, но вы УКЛОНЯЕТЕСЬ! 🌀" % [enemy.name, raw_damage])
		return
	var block := player.roll_block() + shield_value
	var blocked := mini(block, raw_damage)
	var dealt := raw_damage - blocked
	player.hp = maxi(0, player.hp - dealt)
	_log("%s бьёт на %d → броня блокирует %d → вам -%d ❤"
			% [enemy.name, raw_damage, blocked, dealt])


func _on_victory() -> void:
	_log("☠ %s повержен! Опыт +%d, золото +%d" % [enemy.name, enemy.xp_reward, enemy.gold_reward])
	player.gold += enemy.gold_reward
	if player.gain_xp(enemy.xp_reward):
		_log("⭐ НОВЫЙ УРОВЕНЬ! Сила %d, Ловкость %d, Max HP %d"
				% [player.strength, player.agility, player.max_hp])
	# Лут: иногда выпадает предмет
	if randf() < 0.35:
		var w := Player.WeaponsDB.random_for_level(depth)
		_log("🎁 Враг обронил: %s (%d-%d)! Нажмите [Подобрать]... пока просто меняем оружие."
				% [w.weapon_name, w.dmg_min, w.dmg_max])
		player.weapon = w
	depth += 1
	enemy = null
	_set_state(State.SHOP if randf() < 0.5 else State.EXPLORE)
	if state == State.SHOP:
		_log("🏪 По пути вы встречаете лавку странного торговца!")


func _check_end() -> void:
	if player.is_dead():
		_log("💀 ВЫ ПОГИБЛИ на глубине %d. Игра окончена." % depth)
		enemy = null
		_set_state(State.GAME_OVER)


# ---------- Лавка ----------

func _on_buy_weapon() -> void:
	var w := Player.WeaponsDB.random_for_level(depth)
	var price: int = w.price + depth * 10
	if player.gold >= price:
		player.gold -= price
		player.weapon = w
		_log("🛒 Куплено: %s (%d-%d) за %d золота" % [w.weapon_name, w.dmg_min, w.dmg_max, price])
	else:
		_log("Не хватает золота: %s стоит %d, у вас %d" % [w.weapon_name, price, player.gold])
	_refresh_ui()


func _on_buy_armor() -> void:
	var a := Player.ArmorsDB.random_for_level(depth)
	var price: int = a.price + depth * 10
	if player.gold >= price:
		player.gold -= price
		player.armor = a
		_log("🛒 Куплено: %s (блок %d-%d) за %d золота" % [a.armor_name, a.block_min, a.block_max, price])
	else:
		_log("Не хватает золота: %s стоит %d, у вас %d" % [a.armor_name, price, player.gold])
	_refresh_ui()


func _on_leave_shop() -> void:
	_log("Вы уходите из лавки и идёте дальше...")
	_set_state(State.EXPLORE)


func _on_restart() -> void:
	player = Player.new()
	enemy = null
	depth = 1
	shield_value = 0
	combat_turn = "player"
	log_label.clear()
	_log("Новая игра. Всё решает рандом!")
	_set_state(State.EXPLORE)


# ---------- Служебное ----------

func _log(msg: String) -> void:
	log_label.append_text(msg + "\n")
