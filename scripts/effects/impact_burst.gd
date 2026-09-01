class_name ImpactBurst
extends Node2D

var active := false
var age := 0.0
var duration := 0.35
var color := Color.WHITE
var size_scale := 1.0
var style := "hit"
var particles: Array[Dictionary] = []

func activate(origin: Vector2, burst_color: Color, strength := 1.0, burst_style := "hit") -> void:
	global_position = origin
	color = burst_color
	size_scale = strength
	style = burst_style
	age = 0.0
	duration = 0.55 if style in ["elite", "boss", "level"] else 0.32
	particles.clear()
	var count := clampi(int(8 * strength), 7, 26)
	for i in count:
		particles.append({"dir": Vector2.from_angle(randf() * TAU), "speed": randf_range(70.0, 270.0) * strength, "length": randf_range(5.0, 16.0)})
	active = true
	visible = true
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false
	particles.clear()

func simulate(delta: float) -> bool:
	if not active: return false
	age += delta
	queue_redraw()
	return age < duration

func _draw() -> void:
	if not active: return
	var t := clampf(age / duration, 0.0, 1.0)
	var fade := 1.0 - t
	if style in ["elite", "boss", "level"]:
		draw_arc(Vector2.ZERO, lerpf(15.0, 125.0 * size_scale, t), 0.0, TAU, 42, Color(color, fade * 0.75), 8.0 * fade + 2.0)
		draw_arc(Vector2.ZERO, lerpf(5.0, 80.0 * size_scale, t), 0.0, TAU, 32, Color.WHITE * Color(1, 1, 1, fade * 0.5), 3.0)
	for particle in particles:
		var p: Vector2 = particle.dir * particle.speed * age
		var tail: Vector2 = p - particle.dir * particle.length * size_scale * fade
		draw_line(tail, p, Color(color, fade), maxf(2.0, 5.0 * fade))
	if style == "explode":
		draw_circle(Vector2.ZERO, 38.0 * size_scale * sin(t * PI), Color(color, fade * 0.42))

