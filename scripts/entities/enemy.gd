class_name RiftEnemy
extends Node2D

signal attack_requested(enemy: RiftEnemy, kind: String, payload: Dictionary)
signal killed(enemy: RiftEnemy, context: Dictionary)

const ELITE_AFFIXES := ["Arcane", "Mortar", "Frozen", "Poison", "Teleporter", "Waller", "Shielding", "Vampiric", "Explosive", "Lightning", "Fire Trail", "Summoner", "Berserker"]
const ELEMENT_COLORS := {
	"physical": Color("#d7d3c8"), "fire": Color("#ff6b35"), "ice": Color("#79d8ff"),
	"lightning": Color("#ffe066"), "poison": Color("#7ee34d"), "bleed": Color("#ef476f"),
	"void": Color("#ad68ff")
}

var data: Dictionary = {}
var max_health := 1.0
var health := 1.0
var contact_damage := 1.0
var speed := 60.0
var radius := 22.0
var active := false
var elite := false
var boss := false
var elite_affixes: Array[String] = []
var ai_group := 0
var move_direction := Vector2.ZERO
var attack_cooldown := 0.0
var special_timer := 0.0
var contact_cooldown := 0.0
var age := 0.0
var phase := 0
var flash := 0.0
var statuses: Dictionary = {}
var last_source: Dictionary = {}
var pending_charge := 0.0
var charge_direction := Vector2.ZERO
var boss_modifier := ""

func activate(record: Dictionary, spawn_position: Vector2, tier: int, elapsed: float, make_elite := false, affix_count := 0, make_boss := false) -> void:
	data = record
	global_position = spawn_position
	elite = make_elite
	boss = make_boss
	active = true
	visible = true
	age = 0.0
	phase = 0
	statuses.clear()
	last_source.clear()
	attack_cooldown = randf_range(0.4, 1.8)
	special_timer = randf_range(2.0, 4.0)
	contact_cooldown = 0.0
	pending_charge = 0.0
	var tier_scale := pow(1.18, maxf(0.0, tier - 1.0))
	var time_scale := 1.0 + elapsed / 240.0
	max_health = float(data.get("hp", 50.0)) * tier_scale * time_scale
	contact_damage = float(data.get("damage", 10.0)) * pow(1.12, maxf(0.0, tier - 1.0))
	speed = float(data.get("speed", 70.0)) * minf(1.0 + tier * 0.008, 1.35)
	radius = 21.0 * float(data.get("scale", 1.0))
	if elite:
		max_health *= 6.0 + tier * 0.2
		contact_damage *= 1.8
		radius *= 1.35
		elite_affixes.clear()
		var choices: Array = ELITE_AFFIXES.duplicate()
		choices.shuffle()
		for index in mini(affix_count, choices.size()): elite_affixes.append(choices[index])
		if "Berserker" in elite_affixes: speed *= 1.25
	if boss:
		max_health = float(data.get("hp", 15000.0)) * tier_scale
		contact_damage = float(data.get("damage", 30.0)) * pow(1.1, maxf(0.0, tier - 1.0))
		speed = 74.0
		radius = 78.0
		elite_affixes.clear()
		boss_modifier = ["Relentless", "Volcanic", "Stormbound", "Graveborn"][(tier - 1) % 4]
		if boss_modifier == "Relentless": speed *= 1.22
	else: boss_modifier = ""
	health = max_health
	modulate = Color.WHITE
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false
	statuses.clear()
	elite_affixes.clear()

func simulate(delta: float, player_position: Vector2, frame_index: int) -> void:
	if not active: return
	age += delta
	attack_cooldown -= delta
	special_timer -= delta
	contact_cooldown -= delta
	flash = maxf(0.0, flash - delta * 8.0)
	_tick_statuses(delta)
	if health <= 0.0: return
	var distance := global_position.distance_to(player_position)
	var stride := 2 if distance < 650.0 else (4 if distance < 1300.0 else 8)
	if (frame_index + ai_group) % stride == 0:
		move_direction = global_position.direction_to(player_position)
		if data.get("role", "chaser") in ["ranged", "sniper", "summoner"] and distance < 460.0:
			move_direction = -move_direction * 0.65
	if pending_charge > 0.0:
		pending_charge -= delta
		global_position += charge_direction * speed * 4.2 * delta
	else:
		global_position += move_direction * speed * delta
	_process_role(distance, player_position)
	if boss: _process_boss(distance, player_position)
	queue_redraw()

func _process_role(distance: float, player_position: Vector2) -> void:
	var role: String = data.get("role", "chaser")
	if role in ["ranged", "sniper"] and attack_cooldown <= 0.0 and distance < 900.0:
		attack_cooldown = 2.4 if role == "ranged" else 3.6
		attack_requested.emit(self, "shot", {"direction": global_position.direction_to(player_position), "speed": 370.0 if role == "ranged" else 680.0, "damage": contact_damage, "element": data.get("element", "physical"), "sniper": role == "sniper"})
	elif role in ["charger", "rammer"] and special_timer <= 0.0 and distance < 680.0:
		special_timer = 4.2
		pending_charge = 0.55
		charge_direction = global_position.direction_to(player_position)
	elif role == "summoner" and special_timer <= 0.0:
		special_timer = 6.0
		attack_requested.emit(self, "summon", {"count": 3})
	elif role == "teleporter" and special_timer <= 0.0:
		special_timer = 4.8
		global_position = player_position - global_position.direction_to(player_position) * 150.0 + Vector2.from_angle(randf() * TAU) * 90.0
	elif role == "buffer" and special_timer <= 0.0:
		special_timer = 4.0
		attack_requested.emit(self, "buff", {"radius": 260.0})
	if elite and special_timer <= 0.0:
		special_timer = randf_range(3.0, 5.0)
		for affix in elite_affixes:
			match affix:
				"Mortar": attack_requested.emit(self, "mortar", {"target": player_position, "damage": contact_damage * 1.4})
				"Arcane": attack_requested.emit(self, "arcane", {"count": 6, "damage": contact_damage, "element": "void"})
				"Summoner": attack_requested.emit(self, "summon", {"count": 4})
				"Frozen": attack_requested.emit(self, "affix_zone", {"target": player_position, "radius": 115.0, "damage": contact_damage, "element": "ice"})
				"Poison": attack_requested.emit(self, "affix_zone", {"target": global_position, "radius": 135.0, "damage": contact_damage * 0.7, "element": "poison"})
				"Teleporter": global_position = player_position + Vector2.from_angle(randf() * TAU) * 190.0
				"Waller": attack_requested.emit(self, "waller", {"target": player_position, "damage": contact_damage})
				"Lightning": attack_requested.emit(self, "arcane", {"count": 4, "damage": contact_damage * 0.8, "element": "lightning"})
				"Fire Trail": attack_requested.emit(self, "affix_zone", {"target": global_position, "radius": 82.0, "damage": contact_damage * 0.8, "element": "fire"})

func _process_boss(distance: float, player_position: Vector2) -> void:
	var ratio := health / max_health
	var new_phase := 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if new_phase != phase:
		phase = new_phase
		attack_requested.emit(self, "phase", {"phase": phase})
	if special_timer <= 0.0:
		special_timer = maxf(1.1, 3.4 - phase * 0.48) * (0.72 if boss_modifier == "Relentless" else 1.0)
		var patterns: PackedStringArray = data.get("patterns", PackedStringArray(["nova", "lanes", "charge"]))
		attack_requested.emit(self, "boss_pattern", {"pattern": patterns[(phase - 1) % patterns.size()], "phase": phase, "target": player_position, "damage": contact_damage})
		if boss_modifier == "Volcanic": attack_requested.emit(self, "mortar", {"target": player_position, "damage": contact_damage})
		elif boss_modifier == "Stormbound": attack_requested.emit(self, "arcane", {"count": 5 + phase, "damage": contact_damage * 0.7, "element": "lightning"})
		elif boss_modifier == "Graveborn": attack_requested.emit(self, "summon", {"count": phase})
	if distance < 180.0 and attack_cooldown <= 0.0:
		attack_cooldown = 1.6
		attack_requested.emit(self, "boss_slam", {"radius": 210.0, "damage": contact_damage * 1.2})

func take_damage(amount: float, context: Dictionary) -> bool:
	if not active: return false
	var actual := amount
	if elite and "Shielding" in elite_affixes and age < 2.5: actual *= 0.2
	health -= actual
	last_source = context
	flash = 1.0
	if context.get("element", "") in ["fire", "poison", "bleed"]:
		var element: String = context.element
		var status_time: float = 9999.0 if element == "poison" and context.get("effects", {}).has("eternal_poison") else 3.5
		var stack_scale: float = float(context.get("effects", {}).get("eternal_poison", 1.0)) if element == "poison" else 1.0
		statuses[element] = {"time": status_time, "damage": actual * 0.12 * stack_scale, "tick": 0.45, "source": context}
	if context.get("element", "") == "ice" and randf() < 0.28:
		statuses.ice = {"time": 1.4, "damage": 0.0, "tick": 1.0, "source": context}
	if context.get("force_freeze", false):
		statuses.ice = {"time": 2.2, "damage": 0.0, "tick": 1.0, "source": context}
	if health <= 0.0:
		killed.emit(self, context)
		return true
	queue_redraw()
	return false

func _tick_statuses(delta: float) -> void:
	var expired: Array[String] = []
	var slow := 1.0
	for key in statuses:
		var status: Dictionary = statuses[key]
		status.time -= delta
		status.tick -= delta
		if key == "ice": slow = 0.55
		if status.tick <= 0.0 and status.damage > 0.0:
			status.tick = 0.5
			health -= status.damage
			if key == "bleed": attack_requested.emit(self, "status_tick", {"element": key, "effects": status.source.get("effects", {})})
			if health <= 0.0:
				killed.emit(self, status.source)
				return
		if status.time <= 0.0: expired.append(key)
	for key in expired: statuses.erase(key)
	if slow < 1.0: global_position -= move_direction * speed * delta * (1.0 - slow)

func can_contact() -> bool:
	return contact_cooldown <= 0.0

func mark_contact() -> void:
	contact_cooldown = 0.75

func _draw() -> void:
	if not active: return
	var element_color: Color = ELEMENT_COLORS.get(data.get("element", "physical"), Color.WHITE)
	var base := Color("#7c3147").lerp(element_color, 0.24)
	if elite: base = Color("#d3a43b").lerp(element_color, 0.28)
	if boss: _draw_boss(base, element_color); return
	var role: String = data.get("role", "chaser")
	var s := radius / 22.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	# Pixel-art silhouettes by combat role.
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(s, s * 0.34))
	draw_circle(Vector2.ZERO, 23.0, Color(0, 0, 0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	match role:
		"charger":
			draw_colored_polygon(PackedVector2Array([Vector2(-29, 14), Vector2(-18, -11), Vector2(15, -17), Vector2(31, 3), Vector2(17, 17)]), base)
			draw_colored_polygon(PackedVector2Array([Vector2(12, -13), Vector2(29, -23), Vector2(22, -8)]), element_color)
		"ranged":
			draw_colored_polygon(PackedVector2Array([Vector2(-18, 20), Vector2(-15, -18), Vector2(0, -30), Vector2(17, -16), Vector2(20, 20)]), base.darkened(0.12))
			draw_arc(Vector2(13, 0), 20, -1.7, 1.7, 9, element_color, 4.0)
		"tank", "shield":
			draw_rect(Rect2(-25, -24, 46, 47), base)
			draw_colored_polygon(PackedVector2Array([Vector2(-34, -25), Vector2(-10, -35), Vector2(-7, 28), Vector2(-34, 18)]), element_color.darkened(0.35))
		"exploder":
			draw_colored_polygon(PackedVector2Array([Vector2(-20, 14), Vector2(-26, -5), Vector2(-12, -27), Vector2(13, -25), Vector2(28, -4), Vector2(18, 19)]), base)
			draw_rect(Rect2(-11, -15, 8, 8), element_color)
			draw_rect(Rect2(6, -10, 7, 13), element_color)
		"swarm":
			draw_colored_polygon(PackedVector2Array([Vector2(-27, 4), Vector2(-11, -15), Vector2(15, -14), Vector2(29, 7), Vector2(8, 14), Vector2(-10, 13)]), base)
			draw_rect(Rect2(15, -9, 10, 5), element_color)
		"buffer", "summoner":
			draw_colored_polygon(PackedVector2Array([Vector2(-21, 22), Vector2(-16, -18), Vector2(0, -31), Vector2(17, -17), Vector2(23, 22)]), base.darkened(0.18))
			draw_rect(Rect2(-7, -20, 14, 14), Color("#090b18"))
			draw_rect(Rect2(-2, -16, 4, 7), element_color)
		"teleporter":
			draw_colored_polygon(PackedVector2Array([Vector2(-22, 18), Vector2(-13, -25), Vector2(4, -34), Vector2(21, -4), Vector2(14, 21)]), base)
			draw_line(Vector2(-17, -4), Vector2(14, 9), element_color, 5.0)
		"rammer":
			draw_rect(Rect2(-27, -18, 49, 38), base)
			draw_colored_polygon(PackedVector2Array([Vector2(12, -17), Vector2(36, -26), Vector2(24, -4)]), element_color)
		"sniper":
			draw_colored_polygon(PackedVector2Array([Vector2(-15, 22), Vector2(-8, -30), Vector2(10, -30), Vector2(16, 22)]), base.darkened(0.25))
			draw_line(Vector2(0, -20), Vector2(32, 0), element_color, 6.0)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(-19, 19), Vector2(-22, -12), Vector2(-9, -30), Vector2(12, -26), Vector2(22, -6), Vector2(17, 20)]), base)
			draw_line(Vector2(11, -5), Vector2(29, -22), Color("#c9c1ae"), 5.0)
	# eyes and elite marker
	draw_rect(Rect2(-8, -14, 6, 4), element_color)
	draw_rect(Rect2(5, -14, 6, 4), element_color)
	if elite:
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 18, Color(element_color, 0.65), 4.0)
		for index in elite_affixes.size():
			draw_rect(Rect2(-elite_affixes.size() * 5 + index * 10, -43, 7, 7), Color("#ffc857"))
	if flash > 0.0: draw_circle(Vector2.ZERO, 26.0, Color(1, 1, 1, flash * 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if elite:
		var ratio := clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(-radius, -radius - 15, radius * 2.0, 6), Color("#170c14"))
		draw_rect(Rect2(-radius, -radius - 15, radius * 2.0 * ratio, 6), Color("#ffc857"))

func _draw_boss(base: Color, element_color: Color) -> void:
	var pulse := 1.0 + sin(age * 3.0) * 0.04
	draw_set_transform(Vector2(0, 30), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.52))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * pulse)
	# Crown, mantle, weapon, and phase halo create an unmistakable silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(-65, 55), Vector2(-52, -23), Vector2(-27, -58), Vector2(30, -60), Vector2(59, -18), Vector2(70, 58)]), base.darkened(0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(-35, -54), Vector2(-27, -91), Vector2(-9, -72), Vector2(4, -101), Vector2(18, -69), Vector2(39, -89), Vector2(35, -51)]), element_color.darkened(0.18))
	draw_rect(Rect2(-29, -50, 58, 42), base.lightened(0.08))
	draw_rect(Rect2(-18, -39, 10, 6), element_color)
	draw_rect(Rect2(9, -39, 10, 6), element_color)
	draw_line(Vector2(48, -30), Vector2(93, 56), Color("#131525"), 16.0)
	draw_line(Vector2(45, -39), Vector2(101, 50), element_color, 5.0)
	for ring in phase:
		draw_arc(Vector2.ZERO, radius + ring * 11.0, age * (0.3 + ring * 0.1), age * (0.3 + ring * 0.1) + 4.5, 30, Color(element_color, 0.38), 5.0)
	if flash > 0.0: draw_circle(Vector2(0, -15), radius, Color(1, 1, 1, flash * 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
