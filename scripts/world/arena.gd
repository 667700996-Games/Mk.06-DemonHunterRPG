class_name RiftArena
extends Node2D

signal run_finished(result: Dictionary)

const WorldRenderer = preload("res://scripts/world/world_renderer.gd")
const PlayerScript = preload("res://scripts/entities/player.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const ProjectileScript = preload("res://scripts/entities/projectile.gd")
const PickupScript = preload("res://scripts/entities/pickup.gd")
const BurstScript = preload("res://scripts/effects/impact_burst.gd")
const DamageNumberScript = preload("res://scripts/effects/damage_number.gd")
const DangerZoneScript = preload("res://scripts/effects/danger_zone.gd")
const ShrineScript = preload("res://scripts/world/shrine.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const DebugMenuScript = preload("res://scripts/ui/debug_menu.gd")
const SummonScript = preload("res://scripts/entities/summon.gd")
const AmbientMotesScript = preload("res://scripts/effects/ambient_motes.gd")

var world: Node2D
var player: RiftPlayer
var camera: Camera2D
var hud: RiftHUD
var flash_rect: ColorRect
var debug_menu: CanvasLayer
var ambient_motes: Node2D
var biome: Dictionary

var enemy_pool: Array[RiftEnemy] = []
var projectile_pool: Array[RiftProjectile] = []
var pickup_pool: Array[RiftPickup] = []
var burst_pool: Array[ImpactBurst] = []
var number_pool: Array[DamageNumber] = []
var zone_pool: Array[DangerZone] = []
var enemies: Array[RiftEnemy] = []
var projectiles: Array[RiftProjectile] = []
var pickups: Array[RiftPickup] = []
var bursts: Array[ImpactBurst] = []
var numbers: Array[DamageNumber] = []
var zones: Array[DangerZone] = []
var shrines: Array[RiftShrine] = []
var summons: Array[Node2D] = []

var frame_index := 0
var spawn_accumulator := 0.0
var elite_timer := 13.0
var rift_progress := 0.0
var rift_goal := 8000.0
var boss_started := false
var current_boss: RiftEnemy
var ending := false
var guaranteed_loot := false
var shrine_spawned := false
var chest_spawned := false
var cursed_event_timer := 0.0
var cursed_origin := Vector2.ZERO
var temporary_buffs: Dictionary = {}
var spatial_hash: Dictionary = {}
var cell_size := 128.0
var damage_numbers_this_frame := 0
var camera_shake := 0.0
var camera_zoom_pulse := 0.0
var latest_item: Dictionary = {}
var pending_level_ups := 0
var current_upgrade_options: Array[Dictionary] = []
var kill_xp_bank := 0.0
var god_mode := false
var summon_refresh_timer := 0.0
var passive_effect_timer := 0.0
var recent_hits: Array[float] = []
var banished_upgrade_ids: Array[String] = []
var locked_upgrade_ids: Array[String] = []
var favored_upgrade_tag := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	biome = DataRegistry.get_biome(Game.current_run.biome)
	rift_goal = 8000.0 + Game.current_run.tier * 400.0
	_build_scene()
	_build_pools()
	_connect_ui()
	AudioManager.play_music("combat_" + Game.current_run.biome)
	hud.announce("RIFT OPENED  •  HUNT", biome.accent, 1.2)

func _build_scene() -> void:
	world = WorldRenderer.new()
	add_child(world)
	world.setup(biome, Game.current_run.tier)
	ambient_motes = AmbientMotesScript.new()
	ambient_motes.z_index = 2
	add_child(ambient_motes)
	ambient_motes.setup(biome.accent, Game.current_run.biome)
	player = PlayerScript.new()
	player.z_index = 8
	add_child(player)
	player.setup(self)
	player.attack_fired.connect(_on_player_attack)
	player.ability_requested.connect(_on_player_ability)
	player.died.connect(_on_player_died)
	player.dash_started.connect(_on_player_dash)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = -3200
	camera.limit_right = 3200
	camera.limit_top = -3200
	camera.limit_bottom = 3200
	player.add_child(camera)
	camera.make_current()
	hud = HUDScript.new()
	add_child(hud)
	if OS.is_debug_build():
		debug_menu = DebugMenuScript.new()
		add_child(debug_menu)
		debug_menu.command_requested.connect(_debug_command)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash_rect)
	hud.move_child(flash_rect, 0)

func _build_pools() -> void:
	for index in 180: _create_enemy()
	for index in 180: _create_projectile()
	for index in 150: _create_pickup()
	for index in 56: _create_burst()
	for index in 72: _create_number()
	for index in 32: _create_zone()

func _connect_ui() -> void:
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.reroll_requested.connect(_on_reroll)
	hud.banish_requested.connect(_on_banish_upgrade)
	hud.lock_requested.connect(_on_lock_upgrade)
	hud.favor_requested.connect(_on_favor_upgrade)
	hud.interface_closed.connect(_resume_game)
	hud.return_to_menu.connect(_abandon_run)

func _process(delta: float) -> void:
	if ending: return
	_update_camera(delta)
	if get_tree().paused:
		return
	frame_index += 1
	damage_numbers_this_frame = 0
	Game.current_run.elapsed += delta
	ambient_motes.global_position = player.global_position
	_tick_buffs(delta)
	_simulate_summons(delta)
	_tick_passive_effects(delta)
	_spawn_director(delta)
	_rebuild_spatial_hash()
	_simulate_enemies(delta)
	_simulate_projectiles(delta)
	_simulate_pickups(delta)
	_simulate_effects(delta)
	_simulate_shrines(delta)
	_contact_damage()
	_event_director()
	hud.update_hud(player, rift_progress, rift_goal, current_boss, _danger_indicator(), temporary_buffs)
	if rift_progress >= rift_goal and not boss_started:
		_start_boss()

func _unhandled_input(event: InputEvent) -> void:
	if ending: return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		debug_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if hud.has_overlay(): hud.close_interface()
		else:
			get_tree().paused = true
			hud.show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character"):
		if hud.has_overlay(): hud.close_interface()
		else:
			get_tree().paused = true
			hud.show_character()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not latest_item.is_empty() and not get_tree().paused:
		Game.equip_item(latest_item)
		hud.announce("EQUIPPED  •  %s" % latest_item.name, latest_item.color, 0.8)
		latest_item = {}

func _spawn_director(delta: float) -> void:
	if boss_started: return
	var elapsed: float = Game.current_run.elapsed
	var tier: int = Game.current_run.tier
	var target := clampi(int(62.0 + elapsed * 0.7 + tier * 12.0), 70, 700)
	var deficit := target - enemies.size()
	if deficit <= 0: return
	var rate := minf(64.0, 10.0 + elapsed * 0.045 + tier * 1.8 + deficit * 0.04)
	spawn_accumulator += rate * delta
	var budget := mini(12, int(spawn_accumulator))
	spawn_accumulator -= budget
	for index in budget:
		_spawn_enemy(false)
	elite_timer -= delta
	if elite_timer <= 0.0:
		elite_timer = maxf(8.0, 27.0 - elapsed * 0.015 - tier * 0.6)
		var pack := 1 + int(tier >= 6)
		for index in pack: _spawn_enemy(true)

func _spawn_enemy(make_elite: bool, near_position := Vector2.INF, forced_data: Dictionary = {}) -> RiftEnemy:
	var enemy := _take_enemy()
	var angle := randf() * TAU
	var origin: Vector2
	if near_position != Vector2.INF:
		origin = near_position + Vector2.from_angle(angle) * randf_range(150.0, 320.0)
	else:
		origin = player.global_position + Vector2.from_angle(angle) * randf_range(720.0, 1120.0)
		if origin.length() > 2980.0: origin = origin.normalized() * 2980.0
	var record := forced_data if not forced_data.is_empty() else DataRegistry.enemy_for_biome(Game.current_run.biome, Game.current_run.elapsed)
	var affix_count := clampi(1 + int(Game.current_run.tier / 5), 1, 3)
	enemy.activate(record, origin, Game.current_run.tier, Game.current_run.elapsed, make_elite, affix_count)
	enemy.ai_group = randi_range(0, 7)
	enemies.append(enemy)
	if make_elite:
		_burst(origin, biome.accent, 1.8, "elite")
		hud.announce("ELITE HUNT  •  " + " + ".join(enemy.elite_affixes), Color("#ffc857"), 0.7)
	return enemy

func _start_boss() -> void:
	boss_started = true
	AudioManager.play_music("boss")
	hud.announce("RIFT GUARDIAN DESCENDS", Color("#ff416a"), 2.0)
	_flash(Color("#b02f66"), 0.36)
	_shake(18.0)
	AudioManager.play_sfx("boss", 0.82, 1.0)
	for enemy in enemies.duplicate():
		if not enemy.elite and randf() < 0.62:
			enemy.deactivate()
			enemies.erase(enemy)
	var boss_data := DataRegistry.boss_for_biome(Game.current_run.biome)
	current_boss = _take_enemy()
	var origin := player.global_position + Vector2(0, -720)
	current_boss.activate(boss_data, origin, Game.current_run.tier, Game.current_run.elapsed, false, 0, true)
	enemies.append(current_boss)
	_burst(origin, biome.accent, 4.0, "boss")

func _simulate_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not enemy.active:
			enemies.erase(enemy)
			continue
		enemy.simulate(delta, player.global_position, frame_index)

func _simulate_projectiles(delta: float) -> void:
	for projectile in projectiles.duplicate():
		if not projectile.active or not projectile.simulate(delta):
			projectile.deactivate()
			projectiles.erase(projectile)
			continue
		if projectile.enemy_owned:
			if projectile.global_position.distance_to(player.global_position) < projectile.radius + 21.0:
				player.take_damage(projectile.damage)
				_burst(projectile.global_position, RiftEnemy.ELEMENT_COLORS.get(projectile.element, Color.WHITE), 0.8)
				projectile.deactivate()
		else:
			for enemy in _nearby_enemies(projectile.global_position, projectile.radius + 42.0):
				if not enemy.active: continue
				if enemy.global_position.distance_to(projectile.global_position) > enemy.radius + projectile.radius: continue
				if not projectile.register_hit(enemy.get_instance_id()): continue
				_hit_enemy(enemy, projectile.damage, projectile.context)
				if int(projectile.context.get("chain", 0)) > 0:
					_chain_lightning(enemy, projectile.context, int(projectile.context.chain))
					projectile.context.chain = 0
				if randf() < float(projectile.context.get("lucky_hit", 0.0)):
					_trigger_lucky_hit(enemy, projectile.context)
				if not projectile.active and int(projectile.context.get("ricochet", 0)) > 0:
					_ricochet_from(enemy, projectile.context)
				if not projectile.active: break

func _simulate_pickups(delta: float) -> void:
	var radius := 115.0 + Game.stat_total("pickup_radius")
	for pickup in pickups.duplicate():
		if not pickup.active:
			pickups.erase(pickup)
			continue
		pickup.simulate(delta, player.global_position, radius)

func _simulate_summons(delta: float) -> void:
	summon_refresh_timer -= delta
	if summon_refresh_timer <= 0.0:
		summon_refresh_timer = 0.6
		_refresh_summons()
	for companion in summons: companion.simulate(delta)

func _refresh_summons() -> void:
	var effects := Game.legendary_effects()
	var desired := clampi(Game.build_tags().get("summon", 0) + int(effects.get("summon", 0)) + int(Game.current_run.get("bonus_summons", 0)), 0, 8)
	while summons.size() < desired:
		var companion: Node2D = SummonScript.new()
		add_child(companion)
		summons.append(companion)
		companion.setup(self, player, summons.size() - 1, desired)
	while summons.size() > desired:
		var companion: Node2D = summons.pop_back()
		companion.queue_free()
	for index in summons.size():
		summons[index].summon_index = index
		summons[index].summon_count = summons.size()

func _tick_passive_effects(delta: float) -> void:
	passive_effect_timer -= delta
	if passive_effect_timer > 0.0: return
	passive_effect_timer = 0.75
	var effects := Game.legendary_effects()
	var damage: float = player.get_attack_spec().damage
	if effects.has("orbit_power"):
		var blade_origin := player.global_position + Vector2.from_angle(Game.current_run.elapsed * 2.0) * 125.0
		_blast_area(blade_origin, 62.0, damage * effects.orbit_power / 200.0, "physical", false)
	if effects.has("barrier_burn") and player.barrier > 0.0:
		_blast_area(player.global_position, 145.0, damage * effects.barrier_burn / 100.0, "fire", false)

func _simulate_effects(delta: float) -> void:
	for burst in bursts.duplicate():
		if not burst.simulate(delta):
			burst.deactivate()
			bursts.erase(burst)
	for number in numbers.duplicate():
		if not number.simulate(delta):
			number.deactivate()
			numbers.erase(number)
	for zone in zones.duplicate():
		var was_triggered: bool = zone.triggered
		if not zone.simulate(delta, player):
			zone.deactivate()
			zones.erase(zone)
			continue
		if zone.get_meta("friendly", false) and zone.triggered and not was_triggered:
			for enemy in _nearby_enemies(zone.global_position, zone.radius + 100.0):
				if enemy.global_position.distance_to(zone.global_position) <= zone.radius + enemy.radius:
					_hit_enemy(enemy, zone.get_meta("friendly_damage", 100.0), {"element": zone.element, "critical": false, "effects": Game.legendary_effects()})
			_burst(zone.global_position, RiftEnemy.ELEMENT_COLORS.get(zone.element, Color.WHITE), zone.radius / 70.0, "explode")

func _simulate_shrines(delta: float) -> void:
	for shrine in shrines: shrine.simulate(delta, player.global_position)
	if cursed_event_timer > 0.0:
		cursed_event_timer -= delta
		if frame_index % 12 == 0:
			_spawn_enemy(randf() < 0.14, cursed_origin)
		if cursed_event_timer <= 0.0:
			hud.announce("CURSE BROKEN  •  TREASURE CLAIMED", Color("#d985ff"), 1.4)
			for index in 5: _drop_item(cursed_origin + Vector2.from_angle(TAU * index / 5.0) * 55.0, true)

func _contact_damage() -> void:
	if god_mode: return
	for enemy in enemies:
		if not enemy.active: continue
		if enemy.global_position.distance_to(player.global_position) <= enemy.radius + 23.0 and enemy.can_contact():
			enemy.mark_contact()
			player.take_damage(enemy.contact_damage)
			if enemy.elite and "Vampiric" in enemy.elite_affixes:
				enemy.health = minf(enemy.max_health, enemy.health + enemy.contact_damage * 4.0)
			if enemy.data.get("role", "") == "exploder":
				_spawn_zone(enemy.global_position, 105.0, enemy.contact_damage * 1.4, 0.16, "poison")
				enemy.take_damage(enemy.health + 1.0, {"element": "poison", "critical": false})

func _event_director() -> void:
	var elapsed: float = Game.current_run.elapsed
	if not guaranteed_loot and elapsed >= 24.0:
		guaranteed_loot = true
		_drop_item(player.global_position + Vector2(150, -40), false)
	if not shrine_spawned and elapsed >= 58.0:
		shrine_spawned = true
		_spawn_shrine(player.global_position + Vector2.from_angle(randf() * TAU) * 480.0)
	if not chest_spawned and elapsed >= 108.0:
		chest_spawned = true
		_spawn_shrine(player.global_position + Vector2.from_angle(randf() * TAU) * 540.0, "Cursed Chest")
	if elapsed > 160.0 and rift_progress / rift_goal > 0.68 and AudioManager.music_mood != "intense": AudioManager.play_music("intense")

func _on_player_attack(origin: Vector2, direction: Vector2, spec: Dictionary) -> void:
	var count: int = spec.projectiles
	var effects: Dictionary = spec.effects
	if effects.has("split_third") and int(spec.attack_index) % maxi(1, int(effects.split_third)) == 0: count += 2
	if spec.style == "melee":
		_melee_arc(origin, direction, spec)
		return
	var spread := minf(0.55, 0.09 * (count - 1))
	for index in count:
		var offset := 0.0 if count == 1 else lerpf(-spread, spread, float(index) / (count - 1))
		var shot := spec.duplicate(true)
		shot.critical = randf() < float(spec.crit_chance)
		if shot.critical and effects.has("blood_crit"):
			player.health = maxf(1.0, player.health - player.max_health * 0.025)
			shot.damage *= effects.blood_crit / 100.0
		if shot.critical: shot.damage *= float(spec.crit_mult)
		_spawn_projectile(origin, direction.rotated(offset), shot, false)
	if effects.has("fifth_lightning") and int(spec.attack_index) % int(effects.fifth_lightning) == 0:
		var target := get_nearest_enemy(origin)
		if is_instance_valid(target):
			_blast_area(target.global_position, 115.0, spec.damage * 1.4, "lightning", true)
	if temporary_buffs.has("thunder") and int(spec.attack_index) % 3 == 0:
		var target := get_nearest_enemy(origin)
		if is_instance_valid(target): _blast_area(target.global_position, 90.0, spec.damage, "lightning", false)

func _melee_arc(origin: Vector2, direction: Vector2, spec: Dictionary) -> void:
	var reach: float = 118.0 * float(spec.area)
	var hit_count := 0
	for enemy in _nearby_enemies(origin, reach + 100.0):
		var offset := enemy.global_position - origin
		if offset.length() <= reach + enemy.radius and direction.dot(offset.normalized()) > -0.05:
			var context := spec.duplicate(true)
			context.critical = randf() < float(spec.crit_chance)
			context.direction = direction
			var hit_damage: float = spec.damage * (spec.crit_mult if context.critical else 1.0)
			_hit_enemy(enemy, hit_damage, context)
			hit_count += 1
	_burst(origin + direction * 64.0, Color("#f5d3cc"), 1.8 + hit_count * 0.06, "hit")
	_shake(3.0 + hit_count * 0.15)

func _on_player_ability(kind: String, origin: Vector2, direction: Vector2) -> void:
	var damage: float = float(player.get_attack_spec().damage)
	match kind:
		"nova":
			for index in 18:
				var spec := player.get_attack_spec()
				spec.damage = damage * 0.82
				spec.penetration = 3
				spec.element = "ice"
				_spawn_projectile(player.global_position, Vector2.from_angle(TAU * index / 18.0), spec, false)
			_burst(player.global_position, Color("#7adfff"), 2.2, "level")
		"meteor":
			var zone := _spawn_zone(origin, 150.0, 0.0, 0.7, "fire")
			zone.set_meta("friendly", true)
			zone.set_meta("friendly_damage", damage * 4.2)
		"barrier":
			player.max_barrier = maxf(player.max_barrier, 70.0)
			player.add_barrier(70.0)
			_blast_area(player.global_position, 180.0, damage * 1.4, "lightning", false)
		"ultimate":
			hud.announce("R I F T F A L L", Color("#fff082"), 1.0)
			_flash(Color.WHITE, 0.58)
			_shake(24.0)
			for enemy in enemies.duplicate():
				if enemy.active: _hit_enemy(enemy, damage * (9.0 if enemy.boss else 14.0), {"element": "void", "critical": true, "effects": Game.legendary_effects()})
			_burst(player.global_position, Color("#d97bff"), 7.0, "boss")
		"phoenix":
			_flash(Color("#ff8a42"), 0.7)
			for enemy in enemies.duplicate():
				if enemy.active: _hit_enemy(enemy, damage * 18.0, {"element": "fire", "critical": true, "effects": {}})
		"potion":
			_burst(player.global_position, Color("#5ee39a"), 1.8, "level")
			AudioManager.play_sfx("level", 1.25, -7.0)
		"barrier_spears":
			var effects := Game.legendary_effects()
			var count := int(effects.get("barrier_spears", 4))
			for index in count:
				var spec := player.get_attack_spec()
				spec.damage = damage * 0.8
				spec.element = "ice"
				_spawn_projectile(player.global_position, Vector2.from_angle(TAU * index / count), spec, false)

func _on_player_dash() -> void:
	_burst(player.global_position, Color("#a66cff"), 1.2, "hit")
	var effects := Game.legendary_effects()
	var damage: float = player.get_attack_spec().damage
	if effects.has("dash_nova"): _blast_area(player.global_position, 145.0, damage * 1.3, "ice", false)
	if effects.has("dash_fire"):
		var zone := _spawn_zone(player.global_position, 85.0, 0.0, 0.08, "fire")
		zone.set_meta("friendly", true)
		zone.set_meta("friendly_damage", damage * 1.1)
	if effects.has("dash_strike"): _melee_arc(player.global_position, player.facing, player.get_attack_spec())

func _hit_enemy(enemy: RiftEnemy, amount: float, context: Dictionary) -> void:
	if not enemy.active: return
	var final_amount := amount
	if enemy.elite: final_amount *= 1.0 + Game.stat_total("elite_damage") / 100.0
	if enemy.boss: final_amount *= 1.0 + Game.stat_total("boss_damage") / 100.0
	if temporary_buffs.has("frenzy"): final_amount *= 1.45
	if temporary_buffs.has("blood"): final_amount *= 2.0
	var effects: Dictionary = context.get("effects", {})
	if effects.has("bleed_execute") and enemy.statuses.has("bleed") and enemy.health / maxf(enemy.max_health, 1.0) * 100.0 <= effects.bleed_execute:
		final_amount = enemy.health + 1.0
	if float(context.get("execute", 0.0)) > 0.0 and enemy.health / maxf(enemy.max_health, 1.0) * 100.0 <= float(context.execute):
		final_amount = enemy.health + 1.0
	if context.get("critical", false) and effects.has("crit_freeze"): context.force_freeze = true
	Game.current_run.damage += final_amount
	Game.current_run.highest_crit = maxf(Game.current_run.highest_crit, final_amount)
	var color: Color = RiftEnemy.ELEMENT_COLORS.get(context.get("element", "physical"), Color.WHITE)
	_burst(enemy.global_position, color, 1.3 if context.get("critical", false) else 0.75)
	_damage_number(enemy.global_position, final_amount, context.get("element", "physical"), context.get("critical", false))
	if context.get("critical", false):
		AudioManager.play_sfx("critical", randf_range(0.9, 1.1), -5.0)
		_shake(4.0)
	else: AudioManager.play_sfx("hit", randf_range(0.9, 1.12), -13.0)
	var knockback := 8.0 + Game.stat_total("knockback") * 0.45
	enemy.global_position += Vector2(context.get("direction", Vector2.ZERO)) * knockback * (0.18 if enemy.boss else 1.0)
	recent_hits.push_back(final_amount)
	if recent_hits.size() > 20: recent_hits.pop_front()
	if effects.has("hit_echo") and recent_hits.size() >= int(effects.hit_echo):
		var echoed := 0.0
		for hit in recent_hits: echoed += hit
		recent_hits.clear()
		final_amount += echoed * 0.55
	var overkill := maxf(0.0, final_amount - enemy.health)
	var killed := enemy.take_damage(final_amount, context)
	if killed and overkill > 0.0 and effects.has("overkill_wave"):
		var wave_context := context.duplicate(true)
		wave_context.effects = effects.duplicate()
		wave_context.effects.erase("overkill_wave")
		_burst(enemy.global_position, Color("#f2c66d"), 2.0, "explode")
		for nearby in _nearby_enemies(enemy.global_position, 105.0):
			if nearby.active: _hit_enemy(nearby, overkill * effects.overkill_wave / 100.0, wave_context)
	if context.get("critical", false): _hit_stop(0.018)

func _chain_lightning(source: RiftEnemy, context: Dictionary, remaining: int) -> void:
	var current := source
	var excluded := {source.get_instance_id(): true}
	for jump in mini(remaining, 12):
		var next: RiftEnemy
		var best := 290.0 * 290.0
		for enemy in _nearby_enemies(current.global_position, 300.0):
			if not enemy.active or excluded.has(enemy.get_instance_id()): continue
			var distance := current.global_position.distance_squared_to(enemy.global_position)
			if distance < best:
				best = distance
				next = enemy
		if not is_instance_valid(next): break
		excluded[next.get_instance_id()] = true
		_burst(next.global_position, Color("#ffe66d"), 0.75)
		var chained := context.duplicate(true)
		chained.chain = 0
		chained.element = "lightning"
		_hit_enemy(next, float(context.get("damage", player.get_attack_spec().damage)) * pow(0.82, jump + 1), chained)
		current = next
	if context.get("effects", {}).has("chain_nova"):
		_blast_area(current.global_position, 92.0, float(context.get("damage", 30.0)) * context.effects.chain_nova / 100.0, "lightning", false)

func _ricochet_from(source: RiftEnemy, context: Dictionary) -> void:
	var target: RiftEnemy
	for candidate in _nearby_enemies(source.global_position, 420.0):
		if candidate.active and candidate != source:
			target = candidate
			break
	if not is_instance_valid(target): return
	var spec := context.duplicate(true)
	spec.ricochet = int(spec.get("ricochet", 0)) - 1
	spec.penetration = 1
	_spawn_projectile(source.global_position, source.global_position.direction_to(target.global_position), spec, false)

func _trigger_lucky_hit(source: RiftEnemy, context: Dictionary) -> void:
	var effects: Dictionary = context.get("effects", {})
	if effects.has("lucky_fork"):
		for index in int(effects.lucky_fork):
			var spec := context.duplicate(true)
			spec.damage = float(context.get("damage", 25.0)) * 0.55
			spec.penetration = 1
			_spawn_projectile(source.global_position, Vector2.from_angle(randf() * TAU), spec, false)
	if effects.has("void_well"):
		var zone := _spawn_zone(source.global_position, 105.0, 0.0, 0.42, "void")
		zone.set_meta("friendly", true)
		zone.set_meta("friendly_damage", float(context.get("damage", 25.0)) * effects.void_well / 10.0)

func _on_enemy_attack(enemy: RiftEnemy, kind: String, payload: Dictionary) -> void:
	if not enemy.active: return
	match kind:
		"shot":
			var spec := {"damage": payload.damage, "speed": payload.speed, "radius": 9.0 if not payload.sniper else 6.0, "life": 2.5, "penetration": 1, "element": payload.element}
			_spawn_projectile(enemy.global_position, payload.direction, spec, true)
		"summon":
			for index in payload.count: _spawn_enemy(false, enemy.global_position, DataRegistry.by_enemy.get("thrall", {}))
		"buff":
			for ally in _nearby_enemies(enemy.global_position, payload.radius):
				ally.health = minf(ally.max_health, ally.health + ally.max_health * 0.08)
		"mortar": _spawn_zone(payload.target, 105.0, payload.damage, 0.9, "fire")
		"arcane":
			for index in payload.count:
				_spawn_projectile(enemy.global_position, Vector2.from_angle(TAU * index / payload.count), {"damage": payload.damage, "speed": 310.0, "radius": 11.0, "life": 3.0, "penetration": 1, "element": payload.get("element", "void")}, true)
		"affix_zone": _spawn_zone(payload.target, payload.radius, payload.damage, 0.75, payload.element)
		"waller":
			var across := enemy.global_position.direction_to(payload.target).rotated(PI * 0.5)
			for index in range(-2, 3): _spawn_zone(payload.target + across * index * 70.0, 42.0, payload.damage, 0.65, "physical")
		"status_tick":
			if payload.element == "bleed" and payload.effects.has("bleed_cdr"):
				player.reduce_cooldowns(float(payload.effects.bleed_cdr) * 0.035)
		"phase":
			hud.announce("PHASE %d  •  THE RIFT DEEPENS" % payload.phase, biome.accent, 0.8)
			_flash(biome.accent, 0.22)
			_shake(12.0)
		"boss_slam": _spawn_zone(enemy.global_position, payload.radius, payload.damage, 0.55, enemy.data.get("element", "void"))
		"boss_pattern": _execute_boss_pattern(enemy, payload)

func _execute_boss_pattern(boss_enemy: RiftEnemy, payload: Dictionary) -> void:
	var pattern: String = payload.pattern
	var element: String = boss_enemy.data.get("element", "void")
	var phase: int = payload.phase
	if pattern.contains("meteor") or pattern.contains("well") or pattern.contains("collapse") or pattern.contains("grid"):
		for index in 3 + phase * 2:
			var target := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 380.0)
			_spawn_zone(target, 82.0 + phase * 12.0, payload.damage, 0.9 - phase * 0.1, element)
	elif pattern.contains("spiral") or pattern.contains("orbit") or pattern.contains("cone") or pattern.contains("beam") or pattern.contains("nova"):
		for index in 10 + phase * 4:
			var angle := TAU * index / (10.0 + phase * 4.0) + boss_enemy.age * 0.4
			_spawn_projectile(boss_enemy.global_position, Vector2.from_angle(angle), {"damage": payload.damage, "speed": 300.0 + phase * 35.0, "radius": 11.0, "life": 4.0, "penetration": 1, "element": element}, true)
	else:
		for index in phase * 2:
			_spawn_enemy(index == 0, boss_enemy.global_position)
		var direction := boss_enemy.global_position.direction_to(player.global_position)
		for offset in [-0.32, -0.16, 0.0, 0.16, 0.32]:
			_spawn_projectile(boss_enemy.global_position, direction.rotated(offset), {"damage": payload.damage, "speed": 480.0, "radius": 12.0, "life": 3.0, "penetration": 1, "element": element}, true)

func _on_enemy_killed(enemy: RiftEnemy, context: Dictionary) -> void:
	if not enemy.active: return
	enemy.active = false
	enemy.visible = false
	enemies.erase(enemy)
	var origin := enemy.global_position
	var was_boss := enemy.boss
	var was_elite := enemy.elite
	var death_affixes := enemy.elite_affixes.duplicate()
	if was_boss:
		Game.current_run.boss_kills += 1
		Game.statistics.boss_kills += 0 # merged on run completion
		_burst(origin, biome.accent, 7.0, "boss")
		_flash(Color.WHITE, 0.8)
		_shake(30.0)
		_hit_stop(0.16)
		AudioManager.play_sfx("boss", 0.6, 2.0)
		for index in 12: _drop_item(origin + Vector2.from_angle(TAU * index / 12.0) * randf_range(60.0, 180.0), index < 5)
		for index in 18: _spawn_gold(origin + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 180.0), 8 + Game.current_run.tier)
		end_run(true, 2.3)
		return
	Game.current_run.kills += 1
	if was_elite:
		Game.current_run.elite_kills += 1
		rift_progress += 38.0 + Game.current_run.tier * 2.0
		Game.meta.pity += 2
		AudioManager.play_sfx("explode", 0.72, -2.0)
		_burst(origin, Color("#ffc857"), 3.0, "elite")
		_hit_stop(0.055)
		var elite_effects := Game.legendary_effects()
		if elite_effects.has("elite_summon"):
			Game.current_run.bonus_summons = mini(8, int(Game.current_run.get("bonus_summons", 0)) + int(elite_effects.elite_summon))
		for index in 3 + int(randf() < 0.45): _drop_item(origin + Vector2.from_angle(randf() * TAU) * randf_range(24.0, 80.0), index == 0)
		for index in 6: _spawn_gold(origin, 3 + Game.current_run.tier)
	else:
		rift_progress += float(enemy.data.get("progress", 2.0))
	player.register_kill()
	kill_xp_bank += 1.0 + Game.current_run.tier * 0.08
	if Game.current_run.kills % 3 == 0:
		_spawn_xp(origin, kill_xp_bank)
		kill_xp_bank = 0.0
	var loot_chance: float = 0.012 + Game.current_run.tier * 0.0012
	if temporary_buffs.has("greed"): loot_chance *= 3.0
	if randf() < loot_chance: _drop_item(origin, false)
	if randf() < 0.05: _spawn_gold(origin, 1 + Game.current_run.tier * 0.25)
	if "Explosive" in death_affixes: _spawn_zone(origin, 125.0, enemy.contact_damage * 1.8, 0.45, "fire")
	_apply_death_synergies(origin, context, enemy)

func _apply_death_synergies(origin: Vector2, context: Dictionary, dead_enemy: RiftEnemy) -> void:
	var effects: Dictionary = context.get("effects", {})
	if context.get("critical", false) and effects.has("crit_explode"):
		_blast_area(origin, 110.0, context.get("damage", player.get_attack_spec().damage) * effects.crit_explode / 100.0, "fire", false)
	if context.get("element", "") == "fire" and effects.has("burn_explode"):
		_blast_area(origin, 90.0, player.get_attack_spec().damage, "fire", false)
	if dead_enemy.statuses.has("ice") and effects.has("frost_shatter"):
		for index in int(effects.frost_shatter):
			_spawn_projectile(origin, Vector2.from_angle(TAU * index / effects.frost_shatter), {"damage": player.get_attack_spec().damage * 0.6, "speed": 720.0, "radius": 6.0, "life": 0.8, "penetration": 2, "element": "ice", "critical": false, "effects": effects}, false)
	if dead_enemy.statuses.has("poison") and effects.has("poison_spread"):
		var spread_count := 0
		for target in _nearby_enemies(origin, 230.0):
			if target.active:
				target.take_damage(0.1, {"element": "poison", "critical": false, "effects": effects, "damage": player.get_attack_spec().damage * 0.2})
				spread_count += 1
				if spread_count >= int(effects.poison_spread): break
	if effects.has("kill_split"):
		for index in 3:
			_spawn_projectile(origin, Vector2.from_angle(TAU * index / 3.0 + randf()), {"damage": player.get_attack_spec().damage * 0.45, "speed": 690.0, "radius": 6.0, "life": 0.7, "penetration": 1, "element": context.get("element", "physical"), "critical": false, "effects": effects}, false)
	if context.get("summon", false) and effects.has("summon_reform"):
		_blast_area(origin, 95.0, player.get_attack_spec().damage * effects.summon_reform / 100.0, "void", false)
	if dead_enemy.statuses.has("bleed") and effects.has("bleed_cdr"):
		player.reduce_cooldowns(float(effects.bleed_cdr) * 0.08)

func _blast_area(origin: Vector2, radius: float, damage: float, element: String, critical: bool) -> void:
	_burst(origin, RiftEnemy.ELEMENT_COLORS.get(element, Color.WHITE), radius / 65.0, "explode")
	for enemy in _nearby_enemies(origin, radius + 100.0):
		if enemy.active and enemy.global_position.distance_to(origin) <= radius + enemy.radius:
			_hit_enemy(enemy, damage, {"element": element, "critical": critical, "effects": Game.legendary_effects(), "damage": damage})

func _on_pickup_collected(pickup: RiftPickup) -> void:
	if not pickup.active: return
	match pickup.kind:
		"xp": _add_xp(pickup.value)
		"gold": Game.current_run.gold += int(pickup.value)
		"item":
			var item := pickup.item.duplicate(true)
			var equipped := _equipped_for_item(item)
			var kept := Game.register_item(item)
			if kept:
				latest_item = item
				hud.show_loot(item, equipped)
			else:
				latest_item = {}
				hud.announce("AUTO-SALVAGED  •  %s" % item.rarity.to_upper(), item.color, 0.55)
			AudioManager.play_sfx("legendary" if item.rarity_index >= 4 else "loot", 1.35 if item.rarity_index == 5 else 1.0, 1.0 if item.rarity_index == 5 else (-2.0 if item.rarity_index >= 4 else -7.0))
			if item.rarity_index >= 4:
				_flash(item.color, 0.48 if item.rarity_index == 5 else 0.26)
				if item.rarity_index == 5: _shake(10.0)
				hud.announce("%s DROP  •  %s" % [item.rarity.to_upper(), item.name.to_upper()], item.color, 1.1)
	pickup.deactivate()
	pickups.erase(pickup)

func _add_xp(amount: float) -> void:
	Game.current_run.xp += amount * (1.0 + Game.stat_total("xp_gain") / 100.0)
	var needed := hud.xp_needed(Game.current_run.level)
	while Game.current_run.xp >= needed:
		Game.current_run.xp -= needed
		Game.current_run.level += 1
		pending_level_ups += 1
		needed = hud.xp_needed(Game.current_run.level)
	if pending_level_ups > 0 and not hud.has_overlay(): _open_level_up()

func _open_level_up() -> void:
	get_tree().paused = true
	current_upgrade_options.clear()
	var candidates := DataRegistry.upgrades.duplicate()
	var tags := Game.build_tags()
	# Smart choices gently favor established build tags while preserving variance.
	for upgrade in DataRegistry.upgrades:
		if upgrade.id in banished_upgrade_ids: continue
		for index in int(tags.get(upgrade.tag, 0)): candidates.append(upgrade)
		if upgrade.tag == favored_upgrade_tag:
			for index in 5: candidates.append(upgrade)
	candidates.shuffle()
	for locked_id in locked_upgrade_ids:
		for upgrade in DataRegistry.upgrades:
			if upgrade.id == locked_id and upgrade not in current_upgrade_options: current_upgrade_options.append(upgrade)
	for upgrade in candidates:
		if current_upgrade_options.size() >= 3: break
		if upgrade.id not in banished_upgrade_ids and upgrade not in current_upgrade_options: current_upgrade_options.append(upgrade)
	AudioManager.play_sfx("level", 1.0, -2.0)
	hud.show_level_up(current_upgrade_options, Game.current_run.rerolls)

func _on_upgrade_selected(upgrade: Dictionary) -> void:
	Game.current_run.upgrades.append(upgrade)
	locked_upgrade_ids.clear()
	pending_level_ups -= 1
	_burst(player.global_position, RiftEnemy.ELEMENT_COLORS.get(_tag_element(upgrade.tag), UIFactory.CYAN), 2.7, "level")
	if upgrade.stat == "barrier":
		player.max_barrier += upgrade.value
		player.add_barrier(upgrade.value)
	_check_evolutions()
	if pending_level_ups > 0:
		call_deferred("_open_level_up")
	else:
		_resume_game()

func _on_reroll() -> void:
	if Game.current_run.rerolls > 0: Game.current_run.rerolls -= 1
	elif Game.current_run.gold >= 100: Game.current_run.gold -= 100
	else: return
	_open_level_up()

func _on_banish_upgrade(upgrade: Dictionary) -> void:
	if upgrade.id not in banished_upgrade_ids: banished_upgrade_ids.append(upgrade.id)
	locked_upgrade_ids.erase(upgrade.id)
	hud.announce("BANISHED  •  %s" % upgrade.name.to_upper(), UIFactory.CRIMSON, 0.45)
	_open_level_up()

func _on_lock_upgrade(upgrade: Dictionary) -> void:
	if upgrade.id in locked_upgrade_ids: locked_upgrade_ids.erase(upgrade.id)
	else: locked_upgrade_ids.append(upgrade.id)
	hud.announce(("LOCKED  •  " if upgrade.id in locked_upgrade_ids else "UNLOCKED  •  ") + upgrade.name.to_upper(), UIFactory.CYAN, 0.45)
	hud.show_level_up(current_upgrade_options, Game.current_run.rerolls)

func _on_favor_upgrade(tag: String) -> void:
	favored_upgrade_tag = tag
	hud.announce("FATE FAVORS  •  %s" % tag.to_upper(), UIFactory.GOLD, 0.55)

func _check_evolutions() -> void:
	var evolved: Array = Game.current_run.get("evolutions", [])
	var tags := Game.build_tags()
	for evolution in DataRegistry.evolutions:
		if evolution.id in evolved: continue
		var qualifies := true
		for tag in evolution.tags:
			if tags.get(tag, 0) < 3: qualifies = false
		if qualifies:
			evolved.append(evolution.id)
			Game.current_run.evolutions = evolved
			Game.current_run.upgrades.append({"id": evolution.id, "name": evolution.name, "stat": "damage", "value": 55.0, "tag": evolution.tags[0], "description": evolution.description})
			hud.announce("SKILL EVOLVED  •  %s" % evolution.name.to_upper(), Color("#ff4fd8"), 1.8)
			_flash(Color("#ff4fd8"), 0.35)
			break

func _spawn_shrine(origin: Vector2, type := "") -> void:
	var shrine := ShrineScript.new()
	shrine.z_index = 2
	add_child(shrine)
	shrine.setup(origin, type)
	shrine.activated.connect(_on_shrine_activated)
	shrines.append(shrine)
	hud.announce("%s DISCOVERED" % shrine.shrine_type.to_upper(), biome.accent, 0.9)

func _on_shrine_activated(shrine: RiftShrine, type: String) -> void:
	AudioManager.play_sfx("level", 0.75, -1.0)
	_burst(shrine.global_position, biome.accent, 2.5, "level")
	match type:
		"Frenzy": temporary_buffs.frenzy = 20.0
		"Greed": temporary_buffs.greed = 24.0
		"Thunder": temporary_buffs.thunder = 24.0
		"Blood":
			player.take_damage(player.health * 0.35)
			temporary_buffs.blood = 24.0
		"Cursed Chest":
			cursed_event_timer = 30.0
			cursed_origin = shrine.global_position
			for index in 4: _spawn_enemy(true, cursed_origin)
			hud.announce("CURSED ONSLAUGHT  •  SURVIVE 30 SECONDS", Color("#cf72ff"), 1.5)

func _tick_buffs(delta: float) -> void:
	var expired: Array[String] = []
	for key in temporary_buffs:
		temporary_buffs[key] -= delta
		if temporary_buffs[key] <= 0.0: expired.append(key)
	for key in expired: temporary_buffs.erase(key)

func _on_player_died() -> void:
	if ending: return
	ending = true
	AudioManager.play_sfx("death", 0.72, 0.0)
	AudioManager.play_music("menu")
	_flash(Color("#ad183f"), 0.6)
	_shake(22.0)
	Engine.time_scale = 0.22
	hud.announce("THE HUNTER HAS FALLEN", Color("#ff496e"), 1.3)
	var timer := get_tree().create_timer(1.1, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0; end_run(false, 0.0))

func end_run(cleared: bool, delay: float) -> void:
	if ending and not player.dead and not cleared: return
	ending = true
	var finish := func():
		get_tree().paused = false
		Engine.time_scale = 1.0
		var result := Game.finish_run(cleared)
		run_finished.emit(result)
	if delay > 0.0:
		get_tree().create_timer(delay, true, false, true).timeout.connect(finish)
	else: finish.call()

func _abandon_run() -> void:
	get_tree().paused = false
	ending = false
	end_run(false, 0.0)

func _resume_game() -> void:
	get_tree().paused = false

func get_nearest_enemy(origin: Vector2) -> RiftEnemy:
	var nearest: RiftEnemy
	var best := INF
	for enemy in enemies:
		if not enemy.active: continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance < best:
			best = distance
			nearest = enemy
	return nearest

func _danger_indicator() -> String:
	var target: RiftEnemy = current_boss if is_instance_valid(current_boss) and current_boss.active else null
	var best := INF
	if not is_instance_valid(target):
		for enemy in enemies:
			if not enemy.active or not enemy.elite: continue
			var distance := player.global_position.distance_squared_to(enemy.global_position)
			if distance < best:
				best = distance
				target = enemy
	if not is_instance_valid(target): return ""
	var offset := target.global_position - player.global_position
	var cardinal := "E" if absf(offset.x) > absf(offset.y) and offset.x > 0 else ("W" if absf(offset.x) > absf(offset.y) else ("S" if offset.y > 0 else "N"))
	return "%s  •  %s  •  %dm" % ["BOSS" if target.boss else "ELITE", cardinal, int(offset.length() / 10.0)]

func _rebuild_spatial_hash() -> void:
	spatial_hash.clear()
	for enemy in enemies:
		if not enemy.active: continue
		var cell := Vector2i(floori(enemy.global_position.x / cell_size), floori(enemy.global_position.y / cell_size))
		if not spatial_hash.has(cell): spatial_hash[cell] = []
		spatial_hash[cell].append(enemy)

func _nearby_enemies(origin: Vector2, radius: float) -> Array[RiftEnemy]:
	var output: Array[RiftEnemy] = []
	var center := Vector2i(floori(origin.x / cell_size), floori(origin.y / cell_size))
	var cells := ceili(radius / cell_size)
	for x in range(center.x - cells, center.x + cells + 1):
		for y in range(center.y - cells, center.y + cells + 1):
			for enemy in spatial_hash.get(Vector2i(x, y), []): output.append(enemy)
	return output

func _spawn_projectile(origin: Vector2, direction: Vector2, spec: Dictionary, enemy_owned: bool) -> RiftProjectile:
	var projectile := _take_projectile()
	projectile.activate(origin, direction, spec, enemy_owned)
	projectile.z_index = 7
	projectiles.append(projectile)
	return projectile

func _spawn_xp(origin: Vector2, value: float) -> void:
	var pickup := _take_pickup()
	pickup.activate_xp(origin, value)
	pickups.append(pickup)

func _spawn_gold(origin: Vector2, value: float) -> void:
	var pickup := _take_pickup()
	pickup.activate_gold(origin, value)
	pickups.append(pickup)

func _drop_item(origin: Vector2, force_high: bool) -> void:
	var favored := Game.build_tags().keys()
	var item := DataRegistry.roll_item(Game.current_run.level + Game.current_run.tier * 2, Game.current_run.tier + (8 if force_high else 0), favored)
	if force_high and item.rarity_index < 2:
		# Elite/boss loot has a floor while remaining random above it.
		item = DataRegistry.roll_item(Game.current_run.level + Game.current_run.tier * 2, Game.current_run.tier + 18, favored)
	var pickup := _take_pickup()
	pickup.z_index = 5
	pickup.activate_item(origin, item)
	pickups.append(pickup)

func _spawn_zone(origin: Vector2, radius: float, damage: float, delay: float, element: String) -> DangerZone:
	var zone := _take_zone()
	zone.z_index = 1
	zone.activate(origin, radius, damage, delay, element)
	zones.append(zone)
	return zone

func _burst(origin: Vector2, color: Color, strength := 1.0, style := "hit") -> void:
	var burst := _take_burst()
	burst.z_index = 10
	burst.activate(origin, color, strength, style)
	bursts.append(burst)

func _damage_number(origin: Vector2, amount: float, element: String, critical: bool) -> void:
	var max_per_frame := int(4 + Game.settings.damage_numbers * 18.0)
	if damage_numbers_this_frame >= max_per_frame: return
	if not critical and randf() > Game.settings.damage_numbers: return
	damage_numbers_this_frame += 1
	var number := _take_number()
	number.z_index = 18
	number.activate(origin, amount, element, critical)
	numbers.append(number)

func _flash(color: Color, alpha: float) -> void:
	if Game.settings.flash_intensity <= 0.0: return
	flash_rect.color = Color(color, alpha * Game.settings.flash_intensity)
	var tween := flash_rect.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.24)

func _shake(amount: float) -> void:
	camera_shake = maxf(camera_shake, amount * Game.settings.screen_shake)
	camera_zoom_pulse = maxf(camera_zoom_pulse, amount * 0.004)

func _hit_stop(seconds: float) -> void:
	if ending or get_tree().paused or Engine.time_scale < 0.9: return
	Engine.time_scale = 0.16
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func():
		if not ending and not get_tree().paused: Engine.time_scale = 1.0
	)

func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera): return
	if camera_shake > 0.05:
		camera.offset = Vector2.from_angle(randf() * TAU) * camera_shake
		camera_shake = lerpf(camera_shake, 0.0, minf(1.0, delta * 12.0))
	else: camera.offset = camera.offset.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
	var look := player.facing * 70.0
	camera.position = camera.position.lerp(look, minf(1.0, delta * 3.0))
	if camera_zoom_pulse > 0.001:
		camera.zoom = Vector2.ONE * (1.0 - camera_zoom_pulse)
		camera_zoom_pulse = lerpf(camera_zoom_pulse, 0.0, minf(1.0, delta * 10.0))
	else: camera.zoom = camera.zoom.lerp(Vector2.ONE, minf(1.0, delta * 8.0))

func _equipped_for_item(item: Dictionary) -> Dictionary:
	var slot: String = item.slot
	if slot == "ring":
		var one: Dictionary = Game.equipment.ring_1
		var two: Dictionary = Game.equipment.ring_2
		return one if Game.item_score(one) < Game.item_score(two) else two
	return Game.equipment.get(slot, {})

func _tag_element(tag: String) -> String:
	return tag if tag in RiftEnemy.ELEMENT_COLORS else "void"

func _debug_command(command: String) -> void:
	match command:
		"god":
			god_mode = not god_mode
			hud.announce("GOD MODE " + ("ON" if god_mode else "OFF"), UIFactory.GOLD, 0.6)
		"enemy": _spawn_enemy(false, player.global_position + Vector2(280, 0))
		"elite": _spawn_enemy(true, player.global_position + Vector2(300, 0))
		"boss":
			if not boss_started: _start_boss()
		"item": _drop_item(player.global_position + Vector2(80, 0), true)
		"xp": _add_xp(hud.xp_needed(Game.current_run.level) + 1.0)
		"gold": Game.current_run.gold += 1000
		"tier": Game.current_run.tier += 1
		"kill_all":
			for enemy in enemies.duplicate():
				if enemy.active and not enemy.boss: enemy.take_damage(enemy.max_health * 20.0, {"element": "void", "critical": true, "effects": {}})
		"stress":
			for index in 250: _spawn_enemy(index % 40 == 0)

func _take_enemy() -> RiftEnemy:
	for enemy in enemy_pool:
		if not enemy.active: return enemy
	return _create_enemy()

func _create_enemy() -> RiftEnemy:
	var enemy := EnemyScript.new()
	enemy.visible = false
	enemy.z_index = 4
	add_child(enemy)
	enemy.attack_requested.connect(_on_enemy_attack)
	enemy.killed.connect(_on_enemy_killed)
	enemy_pool.append(enemy)
	return enemy

func _take_projectile() -> RiftProjectile:
	for projectile in projectile_pool:
		if not projectile.active: return projectile
	return _create_projectile()

func _create_projectile() -> RiftProjectile:
	var projectile := ProjectileScript.new()
	projectile.visible = false
	add_child(projectile)
	projectile_pool.append(projectile)
	return projectile

func _take_pickup() -> RiftPickup:
	for pickup in pickup_pool:
		if not pickup.active: return pickup
	return _create_pickup()

func _create_pickup() -> RiftPickup:
	var pickup := PickupScript.new()
	pickup.visible = false
	pickup.z_index = 3
	add_child(pickup)
	pickup.collected.connect(_on_pickup_collected)
	pickup_pool.append(pickup)
	return pickup

func _take_burst() -> ImpactBurst:
	for burst in burst_pool:
		if not burst.active: return burst
	return _create_burst()

func _create_burst() -> ImpactBurst:
	var burst := BurstScript.new()
	burst.visible = false
	add_child(burst)
	burst_pool.append(burst)
	return burst

func _take_number() -> DamageNumber:
	for number in number_pool:
		if not number.active: return number
	return _create_number()

func _create_number() -> DamageNumber:
	var number := DamageNumberScript.new()
	number.visible = false
	add_child(number)
	number_pool.append(number)
	return number

func _take_zone() -> DangerZone:
	for zone in zone_pool:
		if not zone.active:
			if zone.has_meta("friendly"): zone.remove_meta("friendly")
			if zone.has_meta("friendly_damage"): zone.remove_meta("friendly_damage")
			return zone
	return _create_zone()

func _create_zone() -> DangerZone:
	var zone := DangerZoneScript.new()
	zone.visible = false
	add_child(zone)
	zone_pool.append(zone)
	return zone
