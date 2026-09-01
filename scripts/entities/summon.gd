class_name RiftSummon
extends Node2D

var arena: Node
var player: RiftPlayer
var summon_index := 0
var summon_count := 1
var orbit_angle := 0.0
var attack_timer := 0.0
var reform_timer := 4.0

func setup(owner_arena: Node, owner_player: RiftPlayer, index: int, count: int) -> void:
	arena = owner_arena
	player = owner_player
	summon_index = index
	summon_count = count
	orbit_angle = TAU * index / maxf(count, 1)
	attack_timer = index * 0.12
	reform_timer = 3.5 + index * 0.3
	z_index = 7
	queue_redraw()

func simulate(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(arena): return
	orbit_angle += delta * (1.25 + summon_index * 0.035)
	var desired := player.global_position + Vector2.from_angle(orbit_angle + TAU * summon_index / maxf(summon_count, 1)) * (92.0 + summon_index % 2 * 24.0)
	global_position = global_position.lerp(desired, minf(1.0, delta * 9.0))
	attack_timer -= delta
	reform_timer -= delta
	var effects := Game.legendary_effects()
	if reform_timer <= 0.0 and effects.has("summon_reform"):
		reform_timer = 4.0
		arena._blast_area(global_position, 100.0, arena.player.get_attack_spec().damage * effects.summon_reform / 100.0, "void", false)
		arena._burst(global_position, Color("#b06cff"), 1.8, "explode")
	if attack_timer <= 0.0:
		var target: RiftEnemy = arena.get_nearest_enemy(global_position)
		if is_instance_valid(target):
			attack_timer = maxf(0.24, 0.78 - Game.build_tags().get("summon", 0) * 0.055)
			var damage: float = arena.player.get_attack_spec().damage * (0.32 + Game.stat_total("summon_damage") / 100.0)
			arena._spawn_projectile(global_position, global_position.direction_to(target.global_position), {
				"damage": damage, "speed": 620.0, "radius": 6.0, "life": 1.4,
				"penetration": 1, "element": "void", "critical": false,
				"crit_chance": 0.0, "effects": effects, "chain": 0, "ricochet": 0, "summon": true
			}, false)
	queue_redraw()

func _draw() -> void:
	var pulse := 0.78 + sin(orbit_angle * 3.0) * 0.16
	draw_circle(Vector2.ZERO, 20.0, Color(0.5, 0.35, 1.0, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 7), Vector2(-9, -9), Vector2(0, -16), Vector2(10, -8), Vector2(12, 8), Vector2(5, 14), Vector2(-5, 14)]), Color("#d8d0c1"))
	draw_rect(Rect2(-7, -7, 5, 4), Color("#8d5cff"))
	draw_rect(Rect2(3, -7, 5, 4), Color("#8d5cff"))
	draw_line(Vector2(-9, 13), Vector2(-13, 23), Color(0.55, 0.35, 1.0, pulse), 4.0)
	draw_line(Vector2(8, 13), Vector2(13, 22), Color(0.55, 0.35, 1.0, pulse), 4.0)
