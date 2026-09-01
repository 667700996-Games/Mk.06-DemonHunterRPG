class_name RiftPlayer
extends Node2D

signal attack_fired(origin: Vector2, direction: Vector2, spec: Dictionary)
signal ability_requested(kind: String, origin: Vector2, direction: Vector2)
signal died
signal health_changed
signal dash_started

var arena: Node
var max_health := 140.0
var health := 140.0
var max_barrier := 0.0
var barrier := 0.0
var move_speed := 330.0
var dash_speed := 980.0
var dash_duration := 0.17
var dash_timer := 0.0
var dash_cooldown := 1.25
var dash_ready := 0.0
var invulnerable := 0.0
var attack_timer := 0.0
var secondary_timer := 0.0
var q_timer := 0.0
var e_timer := 0.0
var ultimate_charge := 0.0
var attack_counter := 0
var facing := Vector2.RIGHT
var velocity := Vector2.ZERO
var walk_phase := 0.0
var flash := 0.0
var dead := false

func setup(owner_arena: Node) -> void:
	arena = owner_arena
	max_health = 140.0 * (1.0 + Game.stat_total("max_health") / 100.0)
	max_barrier = Game.stat_total("barrier")
	health = max_health
	barrier = max_barrier
	move_speed = 330.0 * (1.0 + Game.stat_total("move_speed") / 100.0)
	dash_cooldown = 1.25 * (1.0 - minf(Game.stat_total("dash_cooldown") / 100.0, 0.65))
	queue_redraw()

func _process(delta: float) -> void:
	if dead or get_tree().paused: return
	invulnerable = maxf(0.0, invulnerable - delta)
	attack_timer -= delta
	secondary_timer -= delta
	q_timer -= delta
	e_timer -= delta
	dash_ready -= delta
	flash = maxf(0.0, flash - delta * 7.0)
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var joy_aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down") if InputMap.has_action("aim_left") else Vector2.ZERO
	var aim := joy_aim if joy_aim.length() > 0.25 else (get_global_mouse_position() - global_position).normalized()
	if aim.length_squared() > 0.1: facing = aim.normalized()
	if Input.is_action_just_pressed("dash") and dash_ready <= 0.0:
		dash_timer = dash_duration
		dash_ready = dash_cooldown
		invulnerable = dash_duration + 0.08
		velocity = (move_input.normalized() if move_input.length() > 0.1 else facing) * dash_speed
		dash_started.emit()
		AudioManager.play_sfx("dash")
	if dash_timer > 0.0:
		dash_timer -= delta
		global_position += velocity * delta
	else:
		velocity = velocity.lerp(move_input * move_speed, minf(1.0, delta * 13.0))
		global_position += velocity * delta
	global_position = global_position.limit_length(3040.0)
	walk_phase += delta * (4.0 + velocity.length() * 0.028)
	var auto_target: Node2D = arena.get_nearest_enemy(global_position) if is_instance_valid(arena) else null
	if Game.settings.auto_attack and is_instance_valid(auto_target): facing = global_position.direction_to(auto_target.global_position)
	var wants_attack := Input.is_action_pressed("attack") or (Game.settings.auto_attack and is_instance_valid(auto_target))
	if wants_attack and attack_timer <= 0.0:
		fire_attack()
	if Input.is_action_just_pressed("secondary") and secondary_timer <= 0.0:
		secondary_timer = 3.4 * (1.0 - minf(Game.stat_total("cooldown") / 100.0, 0.65))
		ability_requested.emit("nova", global_position, facing)
	if Input.is_action_just_pressed("skill_q") and q_timer <= 0.0:
		q_timer = 5.5 * (1.0 - minf(Game.stat_total("cooldown") / 100.0, 0.65))
		ability_requested.emit("meteor", get_global_mouse_position(), facing)
	if Input.is_action_just_pressed("skill_e") and e_timer <= 0.0:
		e_timer = 7.0 * (1.0 - minf(Game.stat_total("cooldown") / 100.0, 0.65))
		ability_requested.emit("barrier", global_position, facing)
	if Input.is_action_just_pressed("ultimate") and ultimate_charge >= 1.0:
		ultimate_charge = 0.0
		ability_requested.emit("ultimate", global_position, facing)
	queue_redraw()

func fire_attack() -> void:
	attack_counter += 1
	var speed_bonus := Game.stat_total("attack_speed")
	attack_timer = 0.24 / (1.0 + speed_bonus / 100.0)
	var spec := get_attack_spec()
	spec.attack_index = attack_counter
	attack_fired.emit(global_position + facing * 30.0, facing, spec)
	AudioManager.play_sfx("shoot", randf_range(0.92, 1.08), -8.0)

func get_attack_spec() -> Dictionary:
	var weapon: Dictionary = Game.equipment.get("weapon", {})
	var base_damage := 24.0 + float(weapon.get("base_power", 0.0))
	base_damage *= 1.0 + (Game.stat_total("damage") + Game.stat_total("all_damage") + Game.meta.passive_power) / 100.0
	var tags := Game.build_tags()
	var element := "physical"
	for candidate in ["lightning", "fire", "ice", "poison", "bleed", "void"]:
		if tags.get(candidate, 0) > tags.get(element, 0): element = candidate
	var projectiles := 1 + int(Game.stat_total("projectiles"))
	var crit_chance := 0.08 + Game.stat_total("crit_chance") / 100.0
	return {
		"damage": base_damage, "speed": 850.0 * (1.0 + Game.stat_total("projectile_speed") / 100.0),
		"radius": 8.0 * (1.0 + Game.stat_total("projectile_size") / 100.0), "life": 1.25,
		"penetration": 1 + int(Game.stat_total("penetration")), "projectiles": projectiles,
		"crit_chance": crit_chance, "crit_mult": 1.75 + Game.stat_total("crit_damage") / 100.0,
		"element": element, "chain": int(Game.stat_total("chain")), "effects": Game.legendary_effects()
	}

func take_damage(amount: float) -> void:
	if dead or invulnerable > 0.0: return
	var reduction := clampf(Game.stat_total("damage_reduction") / 100.0, 0.0, 0.7)
	var actual := amount * (1.0 - reduction)
	if barrier > 0.0:
		var blocked := minf(barrier, actual)
		barrier -= blocked
		actual -= blocked
	if actual > 0.0:
		health -= actual
		Game.current_run.damage_taken += actual
	flash = 1.0
	invulnerable = 0.22
	health_changed.emit()
	AudioManager.play_sfx("hurt")
	if health <= 0.0:
		var powers := Game.legendary_effects()
		if powers.has("phoenix") and not Game.current_run.get("phoenix_used", false):
			Game.current_run.phoenix_used = true
			health = max_health
			barrier = max_barrier + 50.0
			ability_requested.emit("phoenix", global_position, facing)
		else:
			dead = true
			died.emit()
	queue_redraw()

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit()

func add_barrier(amount: float) -> void:
	barrier = minf(maxf(max_barrier, 50.0), barrier + amount)
	health_changed.emit()

func register_kill() -> void:
	ultimate_charge = minf(1.0, ultimate_charge + 0.012)
	if Game.current_run.kills % 25 == 0 and Game.stat_total("kill_heal") > 0.0:
		heal(max_health * Game.stat_total("kill_heal") / 100.0)

func cooldown_ratios() -> Dictionary:
	return {
		"dash": clampf(1.0 - dash_ready / maxf(dash_cooldown, 0.01), 0.0, 1.0),
		"secondary": clampf(1.0 - secondary_timer / 3.4, 0.0, 1.0),
		"q": clampf(1.0 - q_timer / 5.5, 0.0, 1.0),
		"e": clampf(1.0 - e_timer / 7.0, 0.0, 1.0), "r": ultimate_charge
	}

func _draw() -> void:
	var bob := sin(walk_phase) * 2.0 if velocity.length() > 20.0 else 0.0
	var flip := -1.0 if facing.x < 0.0 else 1.0
	# shadow
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# coat silhouette and boots
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -8 + bob), Vector2(17, -8 + bob), Vector2(25, 24 + bob), Vector2(-23, 24 + bob)]), Color("#211d35"))
	draw_rect(Rect2(Vector2(-16, 19 + bob), Vector2(11, 17)), Color("#111524"))
	draw_rect(Rect2(Vector2(7, 19 + bob), Vector2(11, 17)), Color("#111524"))
	# plated torso, crimson scarf, pale head
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -16 + bob), Vector2(13, -20 + bob), Vector2(20, 12 + bob), Vector2(-18, 13 + bob)]), Color("#33496a"))
	draw_rect(Rect2(Vector2(-17, -9 + bob), Vector2(33, 6)), Color("#a82955"))
	draw_rect(Rect2(Vector2(-11, -35 + bob), Vector2(21, 19)), Color("#d8c9c1"))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -37 + bob), Vector2(12, -37 + bob), Vector2(8, -47 + bob), Vector2(-10, -45 + bob)]), Color("#15182a"))
	# bright eye and oversized weapon silhouette
	draw_rect(Rect2(Vector2(1 * flip - 3, -30 + bob), Vector2(6, 3)), Color("#72e6ff"))
	draw_line(Vector2(12 * flip, -5 + bob), Vector2(37 * flip, -19 + bob), Color("#17192a"), 9.0)
	draw_line(Vector2(30 * flip, -17 + bob), Vector2(43 * flip, -25 + bob), Color("#ff4d78"), 5.0)
	if barrier > 0.0:
		draw_arc(Vector2.ZERO, 38.0, -2.6, 2.6, 18, Color(0.3, 0.85, 1.0, 0.55), 4.0)
	if flash > 0.0:
		draw_circle(Vector2(0, -6), 34.0, Color(1, 1, 1, flash * 0.5))

