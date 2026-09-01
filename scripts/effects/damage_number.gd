class_name DamageNumber
extends Node2D

var active := false
var age := 0.0
var duration := 0.7
var amount := 0.0
var color := Color.WHITE
var critical := false
var drift := Vector2.ZERO

func activate(origin: Vector2, value: float, element: String, is_critical := false) -> void:
	global_position = origin + Vector2(randf_range(-12, 12), randf_range(-8, 4))
	amount = value
	critical = is_critical
	color = RiftEnemy.ELEMENT_COLORS.get(element, Color.WHITE)
	if critical: color = Color("#fff082")
	age = 0.0
	duration = 0.82 if critical else 0.58
	drift = Vector2(randf_range(-18.0, 18.0), -76.0 if critical else -52.0)
	active = true
	visible = true
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false

func simulate(delta: float) -> bool:
	if not active: return false
	age += delta
	global_position += drift * delta
	drift *= 0.97
	queue_redraw()
	return age < duration

func _draw() -> void:
	if not active: return
	var fade := 1.0 - age / duration
	var font := ThemeDB.fallback_font
	var text := _compact(amount)
	var size := 29 if critical else 19
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.03, 0.02, 0.08, fade))
	draw_string(font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, fade))

func _compact(value: float) -> String:
	if value >= 1000000.0: return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0: return "%.1fK" % (value / 1000.0)
	return str(int(value))

