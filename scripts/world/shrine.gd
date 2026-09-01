class_name RiftShrine
extends Node2D

signal activated(shrine: RiftShrine, shrine_type: String)

const SHRINES := ["Frenzy", "Greed", "Thunder", "Blood", "Cursed Chest"]

var shrine_type := "Frenzy"
var active := false
var used := false
var age := 0.0
var nearby := false

func setup(origin: Vector2, forced_type := "") -> void:
	global_position = origin
	shrine_type = forced_type if not forced_type.is_empty() else SHRINES.pick_random()
	active = true
	used = false
	age = 0.0
	visible = true
	queue_redraw()

func simulate(delta: float, player_position: Vector2) -> void:
	if not active: return
	age += delta
	nearby = not used and global_position.distance_to(player_position) < 105.0
	if nearby and Input.is_action_just_pressed("interact"):
		used = true
		activated.emit(self, shrine_type)
	queue_redraw()

func _draw() -> void:
	if not active: return
	var pulse := 0.65 + sin(age * 3.0) * 0.2
	var color := {
		"Frenzy": Color("#ff466c"), "Greed": Color("#ffc857"), "Thunder": Color("#6ee7ff"),
		"Blood": Color("#d91f48"), "Cursed Chest": Color("#b970ff")
	}.get(shrine_type, Color.WHITE)
	if used: color = color.darkened(0.65)
	draw_set_transform(Vector2(0, 18), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 58.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shrine_type == "Cursed Chest":
		draw_rect(Rect2(-35, -15, 70, 42), Color("#311e42"))
		draw_rect(Rect2(-39, -29, 78, 22), color.darkened(0.28))
		draw_rect(Rect2(-6, -12, 12, 22), color)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-31, 27), Vector2(-21, -23), Vector2(0, -57), Vector2(22, -22), Vector2(31, 27)]), Color("#242b45"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -47), Vector2(13, -20), Vector2(0, -3), Vector2(-13, -20)]), color)
		draw_arc(Vector2(0, -20), 34.0 + pulse * 5.0, age, age + 4.8, 20, Color(color, pulse), 4.0)
	if nearby:
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-120, -88), "F — INVOKE %s" % shrine_type.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 240, 18, 5, Color("#090a14"))
		draw_string(font, Vector2(-120, -88), "F — INVOKE %s" % shrine_type.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 240, 18, color)

