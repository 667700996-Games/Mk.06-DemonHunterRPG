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
	var original_language: String = Game.settings.language
	Game.settings.language = "ko"
	Game.apply_settings()
	_assert_true(UIFactory.localize("SETTINGS") == "설정", "Korean locale translates interface text")
	_assert_true(UIFactory.localize("THE HORDE BREAKS THROUGH") == "괴물의 군세가 밀려옵니다", "Korean locale translates the late-horde warning")
	_assert_true(UIFactory.localize("AUTO POTION  •  HP ≤ 35%  •  BARRIER INDEPENDENT").contains("베리어 무관"), "auto-potion setting explains that barrier does not block healing")
	var melee_item_probe := {"slot": "weapon", "tags": ["melee", "bleed"]}
	var ranged_item_probe := {"slot": "weapon", "tags": ["projectile", "lightning"]}
	var armor_item_probe := {"slot": "chest", "tags": ["barrier", "physical"]}
	_assert_true(Game.localized_item_slot(melee_item_probe) == "무기" and Game.localized_item_type(melee_item_probe) == "근접 무기", "item descriptions identify melee weapons and their equip slot")
	_assert_true(Game.localized_item_type(ranged_item_probe) == "원거리 무기", "item descriptions identify ranged weapons")
	_assert_true(Game.localized_item_slot(armor_item_probe) == "흉갑" and Game.localized_item_type(armor_item_probe) == "방어구", "item descriptions identify armor slots and categories")
	_assert_true(Game.localized_affix_description({"name": "Keen", "stat": "crit_chance", "value": 12.5}).contains("치명타 확률 +12.5"), "item affixes explain the affected mechanical stat")
	Game.settings.language = "en"
	Game.apply_settings()
	_assert_true(UIFactory.localize("SETTINGS") == "SETTINGS", "English locale restores source interface text")
	_assert_true(Game.localized_item_type(ranged_item_probe) == "RANGED WEAPON" and Game.localized_item_slot(armor_item_probe) == "CHEST", "English item descriptions expose type and slot")
	Game.settings.language = original_language
	Game.apply_settings()
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
	var saved_weapon: Dictionary = Game.equipment.weapon
	var equipped_weapon_probe := {"uid": "comparison-equipped", "base_name": "Rift Repeater", "name": "Rift Repeater", "slot": "weapon", "tags": ["projectile"], "base_power": 10.0, "affixes": [{"name": "Brutal", "stat": "damage", "value": 5.0}], "legendary": {}}
	var candidate_weapon_probe := {"uid": "comparison-candidate", "base_name": "Stormneedle", "name": "Stormneedle", "slot": "weapon", "rarity": "LEGENDARY", "rarity_index": 4, "color": Color("#ff9d45"), "item_level": 25, "tags": ["projectile", "lightning"], "base_power": 35.0, "affixes": [{"name": "Brutal", "stat": "damage", "value": 18.0}], "legendary": {"description": "Chain lightning erupts from critical hits.", "tags": ["lightning"]}}
	Game.equipment.weapon = equipped_weapon_probe
	var comparison_panel := arena.hud._item_comparison_panel(candidate_weapon_probe, Game.build_tags())
	var comparison_box := comparison_panel.get_child(0) as VBoxContainer
	var comparison_heading := comparison_box.get_child(0) as Label
	var comparison_metrics := comparison_box.get_child(1) as HFlowContainer
	var comparison_score := comparison_metrics.get_child(0) as Label
	_assert_true(comparison_heading.text.contains(Game.localized_item_name(equipped_weapon_probe)), "inventory comparison names the currently equipped item")
	_assert_true(comparison_score.text.contains("▲"), "inventory comparison marks an equipment upgrade")
	comparison_panel.free()
	arena.hud.show_loot(candidate_weapon_probe, equipped_weapon_probe)
	var compact_toast := arena.hud.toast_layer.get_child(arena.hud.toast_layer.get_child_count() - 1) as PanelContainer
	var toast_box := compact_toast.get_child(0) as VBoxContainer
	var toast_text := ""
	for child in toast_box.get_children():
		if child is Label: toast_text += (child as Label).text + "\n"
	_assert_true(arena.hud.MAX_LOOT_TOASTS == 3 and compact_toast.custom_minimum_size.y <= 100.0, "pickup notifications are capped at three compact cards")
	_assert_true(toast_box.get_child_count() == 3 and toast_text.contains(UIFactory.localize("SCORE")), "pickup notification keeps only name, item summary, and score comparison")
	_assert_true(not toast_text.contains(Game.localized_affix_description(candidate_weapon_probe.affixes[0])) and not toast_text.contains(UIFactory.localize(str(candidate_weapon_probe.legendary.description))), "pickup notification defers affix and legendary details to inventory")
	arena.hud.toast_layer.remove_child(compact_toast)
	compact_toast.free()
	Game.equipment.weapon = saved_weapon
	var saved_ring_one: Dictionary = Game.equipment.ring_1
	var saved_ring_two: Dictionary = Game.equipment.ring_2
	Game.equipment.ring_1 = {"uid": "ring-low", "slot": "ring", "tags": [], "base_power": 5.0, "affixes": [], "legendary": {}}
	Game.equipment.ring_2 = {"uid": "ring-high", "slot": "ring", "tags": [], "base_power": 20.0, "affixes": [], "legendary": {}}
	_assert_true(Game.equipment_slot_for_item({"slot": "ring", "tags": []}) == "ring_1", "ring comparison and equip target the weaker occupied slot")
	Game.equipment.ring_1 = saved_ring_one
	Game.equipment.ring_2 = saved_ring_two
	var health_probe: RiftEnemy = load("res://scripts/entities/enemy.gd").new()
	get_tree().root.add_child(health_probe)
	var probe_record: Dictionary = DataRegistry.enemies[0]
	health_probe.activate(probe_record, Vector2.ZERO, Game.current_run.tier, Game.current_run.elapsed, false, 0, false)
	var normal_health: float = health_probe.max_health
	var normal_damage: float = health_probe.contact_damage
	health_probe.activate(probe_record, Vector2.ZERO, Game.current_run.tier, Game.current_run.elapsed, true, 1, false)
	_assert_true(health_probe.max_health >= normal_health * 20.0, "elite health is substantially higher than normal enemy health")
	_assert_true(is_equal_approx(health_probe.contact_damage, normal_damage * 1.8), "elite attack damage remains on the existing formula")
	var level_one_elite_health: float = health_probe.max_health
	var original_level: int = Game.current_run.level
	Game.current_run.level = 30
	health_probe.activate(probe_record, Vector2.ZERO, Game.current_run.tier, Game.current_run.elapsed, true, 1, false)
	_assert_true(health_probe.max_health >= level_one_elite_health * 10.0, "elite health keeps pace with hunter level damage growth")
	Game.current_run.level = original_level
	var boss_record: Dictionary = DataRegistry.bosses[0]
	var boss_base_health: float = boss_record.hp * pow(1.18, maxf(0.0, Game.current_run.tier - 1.0))
	var expected_boss_damage: float = boss_record.damage * pow(1.1, maxf(0.0, Game.current_run.tier - 1.0))
	health_probe.activate(boss_record, Vector2.ZERO, Game.current_run.tier, 900.0, false, 0, true)
	_assert_true(health_probe.max_health >= boss_base_health * 18.0, "boss health sustains multi-phase combat")
	_assert_true(is_equal_approx(health_probe.contact_damage, expected_boss_damage), "boss attack damage remains unchanged")
	health_probe.free()
	var original_elapsed: float = Game.current_run.elapsed
	var original_progress: float = arena.rift_progress
	var density_targets: Array[int] = []
	for checkpoint in [0.0, 0.25, 0.5, 0.75, 1.0]:
		arena.rift_progress = arena.rift_goal * checkpoint
		density_targets.append(arena._spawn_target(arena.HORDE_TIME_TO_MAX_PRESSURE * checkpoint))
	_assert_true(density_targets[0] < density_targets[1] and density_targets[1] < density_targets[2] and density_targets[2] < density_targets[3] and density_targets[3] < density_targets[4], "horde density rises throughout rift progress")
	_assert_true(density_targets[2] - density_targets[1] > density_targets[1] - density_targets[0] and density_targets[3] - density_targets[2] > density_targets[2] - density_targets[1], "horde density follows an accelerating exponential curve")
	_assert_true(density_targets[4] >= 630, "final rift pressure fills the arena")
	arena.rift_progress = arena.rift_goal * 0.75
	var seventy_five_target := arena._spawn_target(0.0)
	arena.rift_progress = arena.rift_goal * 0.90
	var ninety_target := arena._spawn_target(0.0)
	arena.rift_progress = arena.rift_goal * 0.96
	var peak_target := arena._spawn_target(0.0)
	_assert_true(seventy_five_target < peak_target * 0.2, "horde stays restrained through 75 percent progress")
	_assert_true(ninety_target > seventy_five_target * 4, "horde count erupts between 75 and 90 percent progress")
	_assert_true(peak_target >= 630, "horde reaches screen-filling pressure before the boss threshold")
	arena.rift_progress = arena.rift_goal * 0.70
	var early_progress_gain := arena._rift_progress_gain_multiplier()
	arena.rift_progress = arena.rift_goal * 0.98
	var finale_progress_gain := arena._rift_progress_gain_multiplier()
	_assert_true(finale_progress_gain <= early_progress_gain * 0.15, "finale progress is slowed long enough to sustain the horde scene")
	arena.rift_progress = 0.0
	var opening_target := arena._spawn_target(0.0)
	var timed_target := arena._spawn_target(arena.HORDE_TIME_TO_MAX_PRESSURE)
	_assert_true(timed_target > opening_target * 3, "elapsed time independently raises spawn pressure")
	var opening_rate := arena._normal_spawn_rate(0.0, 100)
	var opening_elite_interval := arena._elite_spawn_interval(0.0)
	arena.rift_progress = arena.rift_goal
	var final_rate := arena._normal_spawn_rate(arena.HORDE_TIME_TO_MAX_PRESSURE, 100)
	var final_elite_interval := arena._elite_spawn_interval(arena.HORDE_TIME_TO_MAX_PRESSURE)
	_assert_true(final_rate > opening_rate * 5.0, "normal enemy spawn frequency accelerates into the finale")
	_assert_true(final_elite_interval < opening_elite_interval * 0.25 and arena._elite_pack_size(arena.HORDE_TIME_TO_MAX_PRESSURE) >= 3, "elite packs become larger and more frequent")
	arena.rift_progress = original_progress
	Game.current_run.elapsed = original_elapsed
	var previous_auto_potion: bool = Game.settings.auto_potion
	var previous_auto_barrier: bool = Game.settings.auto_barrier
	arena.god_mode = true
	Game.settings.auto_potion = true
	arena.player.max_barrier = 100.0
	arena.player.barrier = 100.0
	arena.player.health = 1.0
	arena.player.potion_charges = 2
	arena.player.potion_timer = 0.0
	arena.player.potion_recharge_timer = 0.0
	arena.player._process(1.0 / 60.0)
	_assert_true(arena.player.potion_charges == 1 and arena.player.health > 1.0, "auto-potion heals one health even behind a full barrier")
	_assert_true(is_equal_approx(arena.player.barrier, 100.0), "potion healing is independent of barrier amount")
	arena.player.health = 1.0
	arena.player.potion_charges = 0
	arena.player.potion_timer = 0.0
	arena.player.potion_recharge_timer = 0.01
	arena.player._process(0.02)
	_assert_true(arena.player.health > 1.0 and arena.player.potion_charges == 0 and arena.player.potion_recharge_timer > 0.0, "an exhausted potion charge automatically recovers and heals critical health")
	arena.hud.update_hud(arena.player, arena.rift_progress, arena.rift_goal)
	var potion_status: Label = arena.hud.skill_titles.get("potion") as Label
	_assert_true(is_instance_valid(potion_status) and potion_status.text.contains("×0"), "HUD shows the remaining potion charge count")
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

	Engine.time_scale = 1.0
	arena._hit_stop(0.01)
	get_tree().paused = true
	await get_tree().create_timer(0.03, true, false, true).timeout
	_assert_true(is_equal_approx(Engine.time_scale, 1.0), "hit stop restores normal speed while an overlay pause is active")
	get_tree().paused = false
	var before_level: int = Game.current_run.level
	var level_xp: float = arena.hud.xp_needed(before_level)
	var xp_multiplier := 1.0 + Game.stat_total("xp_gain") / 100.0
	Game.current_run.xp = 0.0
	arena._hit_stop(0.5)
	arena._add_xp((level_xp + 0.1) / xp_multiplier)
	await get_tree().process_frame
	_assert_true(Game.current_run.level > before_level, "XP triggers level-up")
	_assert_true(arena.hud.has_overlay(), "level-up choice UI opens")
	_assert_true(is_equal_approx(Engine.time_scale, 1.0), "level-up entry cancels an overlapping hit stop")
	var splinter_upgrade: Dictionary = {}
	for upgrade in DataRegistry.upgrades:
		if upgrade.id == "splinter_kill":
			splinter_upgrade = upgrade
			break
	_assert_true(not splinter_upgrade.is_empty(), "Splinter Kill upgrade is available")
	if not splinter_upgrade.is_empty(): arena._on_upgrade_selected(splinter_upgrade)
	arena.hud.close_interface()
	_assert_true(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "selecting Splinter Kill resumes combat at normal speed")
	_assert_true(Game.legendary_effects().get("kill_split", 0.0) > 0.0, "Splinter Kill only enables projectile splitting")

	var collected_items_before: int = Game.current_run.items
	arena._drop_item(arena.player.global_position, true)
	for pickup in arena.pickups.duplicate():
		if pickup.kind == "item": arena._on_pickup_collected(pickup)
	await get_tree().process_frame
	_assert_true(Game.current_run.items > collected_items_before, "loot collection is registered even when inventory is capped")
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
