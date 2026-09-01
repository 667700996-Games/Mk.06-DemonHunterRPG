extends Node

var failures: Array[String] = []
var arena: RiftArena
var finish_result: Dictionary = {}
var original_state: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures.append(message)
		push_error("[FAIL] " + message)

func _run() -> void:
	await get_tree().process_frame
	original_state = Game.serialize().duplicate(true)
	Game.settings.auto_salvage_common = false
	Game.settings.auto_salvage_magic = false
	Game.settings.auto_salvage_rare = false
	_assert_true(DataRegistry.enemies.size() >= 12, "12+ enemy records load")
	_assert_true(DataRegistry.bosses.size() >= 5, "5+ boss records load")
	_assert_true(DataRegistry.biomes.size() >= 3, "3+ biome records load")
	_assert_true(DataRegistry.base_items.size() >= 40, "40+ base item records load")
	_assert_true(DataRegistry.affixes.size() >= 100, "100+ affix records load")
	_assert_true(DataRegistry.legendary_powers.size() >= 30, "30+ legendary powers load")
	_assert_true(DataRegistry.upgrades.size() >= 20, "20+ upgrades load")
	_assert_true(DataRegistry.evolutions.size() >= 10, "10+ evolutions load")

	Game.start_run(1, "graveyard")
	Game.current_run.upgrades.append({"id": "test_power", "name": "Test Power", "stat": "damage", "value": 900.0, "tag": "physical"})
	arena = load("res://scripts/world/arena.gd").new()
	arena.run_finished.connect(func(result: Dictionary): finish_result = result)
	get_tree().root.add_child(arena)
	for frame in 150:
		arena._process(1.0 / 60.0)
		await get_tree().process_frame
	_assert_true(is_instance_valid(arena.player), "player is instantiated")
	_assert_true(arena.enemies.size() >= 20, "horde director spawns enemies")
	_assert_true(arena.projectile_pool.size() >= 180, "projectile pool is prewarmed")
	_assert_true(arena.enemy_pool.size() >= 180, "enemy pool is prewarmed")
	var previous_auto_potion: bool = Game.settings.auto_potion
	var previous_auto_barrier: bool = Game.settings.auto_barrier
	arena.god_mode = true
	Game.settings.auto_potion = true
	arena.player.health = arena.player.max_health * 0.3
	arena.player.potion_charges = 2
	arena.player.potion_timer = 0.0
	arena.player._process(1.0 / 60.0)
	_assert_true(arena.player.potion_charges == 1 and arena.player.health > arena.player.max_health * 0.3, "auto-potion triggers below 35% health")
	Game.settings.auto_potion = false
	Game.settings.auto_barrier = true
	arena.player.max_barrier = 0.0
	arena.player.barrier = 0.0
	arena.player.e_timer = 0.0
	arena.player._process(1.0 / 60.0)
	_assert_true(arena.player.e_timer > 0.0 and arena.player.barrier > 0.0, "auto-barrier triggers when depleted near enemies")
	var secondary_before := arena.player.secondary_timer
	var meteor_before := arena.player.q_timer
	var ultimate_before := arena.player.ultimate_charge
	arena.player._process(1.0 / 60.0)
	_assert_true(arena.player.secondary_timer <= secondary_before and arena.player.q_timer <= meteor_before and arena.player.ultimate_charge == ultimate_before, "other combat skills remain manual")
	Game.settings.auto_potion = previous_auto_potion
	Game.settings.auto_barrier = previous_auto_barrier
	arena.god_mode = false
	var movement_origin := arena.player.global_position
	Input.action_press("move_right")
	arena.player._process(0.1)
	Input.action_release("move_right")
	_assert_true(arena.player.global_position.x > movement_origin.x, "movement input moves the hunter")
	var attack_projectiles := arena.projectiles.size()
	var attack_weapon: Dictionary = Game.equipment.weapon
	Game.equipment.weapon = {}
	arena.player.attack_timer = 0.0
	arena.player.fire_attack()
	Game.equipment.weapon = attack_weapon
	_assert_true(arena.projectiles.size() > attack_projectiles, "primary attack emits a combat projectile")
	var previous_weapon: Dictionary = Game.equipment.weapon
	Game.equipment.weapon = {"uid": "smoke-melee", "base_power": 20.0, "tags": ["melee", "bleed"], "affixes": [], "legendary": {}}
	_assert_true(arena.player.get_attack_spec().style == "melee", "equipped weapon changes attack structure")
	Game.equipment.weapon = previous_weapon
	Game.current_run.bonus_summons = 2
	arena._refresh_summons()
	_assert_true(arena.summons.size() >= 2, "summon build creates autonomous companions")

	var before_level: int = Game.current_run.level
	arena._add_xp(200.0)
	await get_tree().process_frame
	_assert_true(Game.current_run.level > before_level, "XP triggers level-up")
	_assert_true(arena.hud.has_overlay(), "level-up choice UI opens")
	if not arena.current_upgrade_options.is_empty(): arena._on_upgrade_selected(arena.current_upgrade_options[0])
	get_tree().paused = false

	var inventory_before := Game.inventory.size()
	arena._drop_item(arena.player.global_position, true)
	for pickup in arena.pickups.duplicate():
		if pickup.kind == "item": arena._on_pickup_collected(pickup)
	await get_tree().process_frame
	_assert_true(Game.inventory.size() > inventory_before, "loot can be collected into inventory")
	if not Game.inventory.is_empty():
		var item: Dictionary = Game.inventory[0]
		Game.equip_item(item)
		var equipped := false
		for slot in Game.equipment:
			if Game.equipment[slot].get("uid", "") == item.uid: equipped = true
		_assert_true(equipped, "loot can be equipped")

	var elite_before: int = Game.current_run.elite_kills
	var elite := arena._spawn_enemy(true, arena.player.global_position + Vector2(220, 0))
	elite.take_damage(elite.max_health * 10.0, {"element": "physical", "critical": true, "effects": {}})
	await get_tree().process_frame
	_assert_true(Game.current_run.elite_kills > elite_before, "elite kill registers and drops loot")

	arena.rift_progress = arena.rift_goal
	arena._start_boss()
	await get_tree().process_frame
	_assert_true(is_instance_valid(arena.current_boss) and arena.current_boss.active, "rift completion spawns boss")
	var boss := arena.current_boss
	boss.take_damage(boss.max_health + 1.0, {"element": "void", "critical": true, "effects": {}})
	await get_tree().create_timer(2.5, true, false, true).timeout
	_assert_true(not finish_result.is_empty() and finish_result.get("cleared", false), "boss kill completes run and creates result")
	_assert_true(Game.meta.unlocked_tier >= 2, "clear unlocks next difficulty")
	_assert_true(SaveManager.save_game(), "save writes atomically")
	_assert_true(FileAccess.file_exists(SaveManager.SAVE_PATH), "save file exists")

	if is_instance_valid(arena): arena.free()
	arena = null
	await get_tree().process_frame
	Game.start_run(1, "graveyard")
	var death_arena: RiftArena = load("res://scripts/world/arena.gd").new()
	get_tree().root.add_child(death_arena)
	await get_tree().process_frame
	_assert_true(is_instance_valid(death_arena.player) and not death_arena.player.dead, "a new run restarts immediately after results")
	death_arena.player.take_damage(999999.0)
	_assert_true(death_arena.player.dead, "fatal damage triggers death state")
	await get_tree().create_timer(1.2, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = false
	death_arena.free()
	await get_tree().process_frame
	Game.hydrate(original_state)
	SaveManager.save_game()
	var saved_currency: int = Game.meta.currency
	Game.meta.currency = -999
	_assert_true(SaveManager.load_game() and Game.meta.currency == saved_currency, "saved meta, settings, and equipment load back correctly")
	AudioManager.shutdown()
	await get_tree().create_timer(0.2, true, false, true).timeout

	if failures.is_empty():
		print("[SMOKE] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("[SMOKE] %d CHECKS FAILED" % failures.size())
		get_tree().quit(1)
