extends Control

var motes: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 54:
		motes.append({
			"p": Vector2(randf_range(0.0, 1920.0), randf_range(420.0, 1080.0)),
			"v": Vector2(randf_range(-9.0, 12.0), randf_range(-48.0, -16.0)),
			"s": randi_range(2, 5), "a": randf_range(0.2, 0.85), "phase": randf() * TAU
		})

func _process(delta: float) -> void:
	for mote in motes:
		mote.p += mote.v * delta
		mote.phase += delta * 2.0
		if mote.p.y < 280.0:
			mote.p = Vector2(randf_range(0.0, size.x), size.y + randf_range(0.0, 80.0))
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		var alpha: float = mote.a * (0.65 + sin(mote.phase) * 0.35)
		var color := Color(1.0, 0.18 + mote.s * 0.04, 0.35, alpha)
		draw_rect(Rect2(mote.p, Vector2(mote.s, mote.s * 1.7)), color)

