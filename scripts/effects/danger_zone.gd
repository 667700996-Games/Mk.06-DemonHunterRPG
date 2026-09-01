class_name DangerZone
extends Node2D

var active := false
var age := 0.0
var warning_time := 0.8
var linger_time := 0.22
var radius := 90.0
var damage := 10.0
var element := "fire"
var triggered := false
var already_hit := false

func activate(origin: Vector2, zone_radius: float, zone_damage: float, delay := 0.8, zone_element := "fire") -> void:
	global_position = origin
	radius = zone_radius
	damage = zone_damage
	warning_time = delay
	linger_time = 0.22
	element = zone_element
	age = 0.0
	triggered = false
	already_hit = false
	active = true
	visible = true
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false

func simulate(delta: float, player: RiftPlayer) -> bool:
	if not active: return false
	age += delta
	if age >= warning_time and not triggered:
		triggered = true
		AudioManager.play_sfx("explode", 0.8, -4.0)
	if triggered and not already_hit and global_position.distance_to(player.global_position) <= radius:
		already_hit = true
		player.take_damage(damage)
	queue_redraw()
	return age < warning_time + linger_time

func _draw() -> void:
	if not active: return
	var color := RiftEnemy.ELEMENT_COLORS.get(element, Color("#ff5c4d"))
	if not triggered:
		var ratio := clampf(age / warning_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.08 + ratio * 0.08))
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, Color(color, 0.86), 7.0)
		for index in 8:
			var a := TAU * index / 8.0
			draw_line(Vector2.from_angle(a) * radius * 0.76, Vector2.from_angle(a) * radius, Color(color, 0.38), 4.0)
	else:
		var fade := 1.0 - (age - warning_time) / linger_time
		draw_circle(Vector2.ZERO, radius, Color(color, fade * 0.5))
		draw_arc(Vector2.ZERO, radius * (1.0 + (1.0 - fade) * 0.3), 0.0, TAU, 42, Color.WHITE * Color(1, 1, 1, fade), 8.0)
