class_name RiftPickup
extends Node2D

signal collected(pickup: RiftPickup)

var active := false
var kind := "xp"
var value := 1.0
var item: Dictionary = {}
var age := 0.0
var velocity := Vector2.ZERO
var magnetized := false

func activate_xp(origin: Vector2, amount: float) -> void:
	global_position = origin
	kind = "xp"
	value = amount
	item.clear()
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(35.0, 100.0)
	_start()

func activate_gold(origin: Vector2, amount: float) -> void:
	global_position = origin
	kind = "gold"
	value = amount
	item.clear()
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(35.0, 90.0)
	_start()

func activate_item(origin: Vector2, rolled_item: Dictionary) -> void:
	global_position = origin
	kind = "item"
	value = 1.0
	item = rolled_item
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(80.0, 170.0)
	_start()

func _start() -> void:
	age = 0.0
	magnetized = false
	active = true
	visible = true
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false
	item.clear()

func simulate(delta: float, player_position: Vector2, pickup_radius: float) -> void:
	if not active: return
	age += delta
	velocity = velocity.lerp(Vector2.ZERO, minf(1.0, delta * 5.0))
	global_position += velocity * delta
	var distance := global_position.distance_to(player_position)
	if distance < pickup_radius or magnetized:
		magnetized = true
		var speed := 480.0 + maxf(0.0, pickup_radius - distance) * 3.0
		global_position = global_position.move_toward(player_position, speed * delta)
	if distance < 28.0:
		collected.emit(self)
	queue_redraw()

func _draw() -> void:
	if not active: return
	var bob := sin(age * 5.0) * 4.0
	match kind:
		"xp":
			var color := Color("#55e7ff")
			draw_colored_polygon(PackedVector2Array([Vector2(0, -9 + bob), Vector2(7, bob), Vector2(0, 9 + bob), Vector2(-7, bob)]), color)
			draw_circle(Vector2(0, bob), 13.0, Color(color, 0.12))
		"gold":
			draw_colored_polygon(PackedVector2Array([Vector2(-8, -7 + bob), Vector2(7, -9 + bob), Vector2(10, 5 + bob), Vector2(-4, 10 + bob), Vector2(-10, 2 + bob)]), Color("#ffc857"))
		"item":
			var color: Color = item.get("color", Color.WHITE)
			var rarity_index: int = item.get("rarity_index", 0)
			draw_circle(Vector2(0, bob + 2), 24.0, Color(color, 0.13))
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -14 + bob), Vector2(10, -14 + bob), Vector2(15, 7 + bob), Vector2(0, 17 + bob), Vector2(-15, 7 + bob)]), color.darkened(0.12))
			draw_rect(Rect2(-4, -8 + bob, 8, 17), color.lightened(0.35))
			if rarity_index >= 4:
				var height := 150.0 if rarity_index == 4 else 220.0
				draw_rect(Rect2(-3, -height + bob, 6, height), Color(color, 0.5))
				draw_rect(Rect2(-14, -height + bob, 28, height), Color(color, 0.07))
			var font := ThemeDB.fallback_font
			draw_string_outline(font, Vector2(-90, 40 + bob), item.get("rarity", "ITEM").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 13, 4, Color("#080a12"))
			draw_string(font, Vector2(-90, 40 + bob), item.get("rarity", "ITEM").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 13, color)
			draw_string_outline(font, Vector2(-120, 58 + bob), item.get("name", "Unknown"), HORIZONTAL_ALIGNMENT_CENTER, 240, 14, 4, Color("#080a12"))
			draw_string(font, Vector2(-120, 58 + bob), item.get("name", "Unknown"), HORIZONTAL_ALIGNMENT_CENTER, 240, 14, Color.WHITE)
