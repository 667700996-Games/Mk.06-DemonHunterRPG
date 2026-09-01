extends Node2D

var biome: Dictionary = {}
var seed_value := 1
var props: Array[Dictionary] = []
var arena_radius := 3200.0

func setup(data: Dictionary, tier: int) -> void:
	biome = data
	seed_value = hash(data.get("id", "graveyard")) + tier * 719
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	props.clear()
	for i in 210:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(320.0, arena_radius - 100.0)
		props.append({
			"p": Vector2.from_angle(angle) * radius,
			"kind": rng.randi_range(0, 5), "scale": rng.randf_range(0.7, 1.45),
			"flip": -1.0 if rng.randf() < 0.5 else 1.0
		})
	queue_redraw()

func _draw() -> void:
	var floor_color: Color = biome.get("floor", Color("#0b1025"))
	var dark: Color = biome.get("accent_dark", Color("#1b3155"))
	var accent: Color = biome.get("accent", Color("#a82955"))
	draw_circle(Vector2.ZERO, arena_radius + 180.0, floor_color)
	# Chunky tile variation: each tile is decorative and never a collision burden.
	for x in range(-16, 17):
		for y in range(-16, 17):
			var pos := Vector2(x, y) * 192.0
			if pos.length() > arena_radius: continue
			var noise := absf(sin(float(x * 73 + y * 151 + seed_value) * 0.013))
			var tile_color := floor_color.lerp(dark, noise * 0.22)
			draw_rect(Rect2(pos - Vector2(94, 94), Vector2(188, 188)), tile_color)
			if (x + y + seed_value) % 4 == 0:
				draw_line(pos + Vector2(-82, 68), pos + Vector2(75, 68), Color(accent, 0.09), 4.0)
	# Rift veins make the otherwise practical arena feel authored.
	for spoke in 18:
		var angle := TAU * spoke / 18.0 + sin(spoke * 7.0) * 0.12
		var start := Vector2.from_angle(angle) * 520.0
		var finish := Vector2.from_angle(angle + sin(spoke) * 0.08) * randf_range(1050.0, 2400.0)
		draw_polyline(PackedVector2Array([start, start.lerp(finish, 0.48) + Vector2.from_angle(angle + PI * 0.5) * 45.0, finish]), Color(accent, 0.17), 7.0)
	for prop in props:
		_draw_prop(prop.p, prop.kind, prop.scale, prop.flip, dark, accent)
	# Boundary monoliths communicate the arena edge without invisible walls.
	for index in 48:
		var angle := TAU * index / 48.0
		var p := Vector2.from_angle(angle) * arena_radius
		var tangent := Vector2.from_angle(angle + PI * 0.5)
		draw_colored_polygon(PackedVector2Array([p - tangent * 24, p + tangent * 24, p + tangent * 17 - Vector2(0, 82), p - tangent * 15 - Vector2(0, 96)]), dark.lightened(0.12))
		draw_line(p - Vector2(0, 82), p - Vector2(0, 14), Color(accent, 0.35), 5.0)

func _draw_prop(p: Vector2, kind: int, prop_scale: float, flip: float, dark: Color, accent: Color) -> void:
	var shadow := Color(0.0, 0.0, 0.0, 0.22)
	draw_ellipse(p + Vector2(8, 10), 30.0 * prop_scale, 11.0 * prop_scale, shadow)
	match kind:
		0: # crooked headstone
			draw_rect(Rect2(p + Vector2(-17, -44) * prop_scale, Vector2(34, 48) * prop_scale), dark.lightened(0.18))
			draw_rect(Rect2(p + Vector2(-22, 2) * prop_scale, Vector2(44, 9) * prop_scale), dark.lightened(0.08))
			draw_line(p + Vector2(0, -33) * prop_scale, p + Vector2(0, -10) * prop_scale, Color(accent, 0.3), 3.0)
		1: # grave cross
			draw_rect(Rect2(p + Vector2(-5, -56) * prop_scale, Vector2(10, 62) * prop_scale), dark.lightened(0.25))
			draw_rect(Rect2(p + Vector2(-24, -40) * prop_scale, Vector2(48, 9) * prop_scale), dark.lightened(0.25))
		2: # dead branch
			draw_line(p + Vector2(0, 8), p + Vector2(7 * flip, -56) * prop_scale, dark.lightened(0.14), 9.0)
			draw_line(p + Vector2(4 * flip, -34) * prop_scale, p + Vector2(29 * flip, -51) * prop_scale, dark.lightened(0.14), 6.0)
		3: # shattered pillar
			draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 7), p + Vector2(17, 7), p + Vector2(13, -54) * prop_scale, p + Vector2(-11, -45) * prop_scale]), dark.lightened(0.2))
			draw_rect(Rect2(p + Vector2(-23, -3), Vector2(46, 10)), dark.lightened(0.1))
		4: # rune shard
			draw_colored_polygon(PackedVector2Array([p + Vector2(-11, 6), p + Vector2(12, 2), p + Vector2(8, -42) * prop_scale, p + Vector2(-4, -59) * prop_scale]), dark.lightened(0.22))
			draw_line(p + Vector2(1, -36) * prop_scale, p + Vector2(3, -13) * prop_scale, Color(accent, 0.65), 4.0)
		_: # bone pile
			draw_line(p + Vector2(-22, 3), p + Vector2(19, -9), dark.lightened(0.35), 7.0)
			draw_line(p + Vector2(-18, -11), p + Vector2(23, 4), dark.lightened(0.35), 7.0)
