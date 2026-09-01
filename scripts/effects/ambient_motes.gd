class_name AmbientMotes
extends Node2D

var color := Color("#a82955")
var motes: Array[Dictionary] = []

func setup(accent: Color, biome_id: String) -> void:
	color = accent
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome_id)
	for index in 90:
		motes.append({"p": Vector2(rng.randf_range(-1050.0, 1050.0), rng.randf_range(-620.0, 620.0)),
			"v": Vector2(rng.randf_range(-8.0, 12.0), rng.randf_range(-24.0, -7.0)),
			"size": rng.randi_range(2, 5), "alpha": rng.randf_range(0.08, 0.42)})
	queue_redraw()

func _process(delta: float) -> void:
	for mote in motes:
		mote.p += mote.v * delta
		if mote.p.y < -640.0: mote.p.y = 640.0
		if mote.p.x < -1080.0: mote.p.x = 1080.0
		elif mote.p.x > 1080.0: mote.p.x = -1080.0
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		draw_rect(Rect2(mote.p, Vector2(mote.size, mote.size * 1.6)), Color(color, mote.alpha))
