extends Node

var arena: RiftArena

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	for slot in Game.SLOTS: Game.equipment[slot] = {}
	Game.start_run(10, "graveyard")
	arena = load("res://scripts/world/arena.gd").new()
	get_tree().root.add_child(arena)
	arena.god_mode = true
	while arena.enemies.size() < 700:
		arena._spawn_enemy(arena.enemies.size() % 55 == 0)
	var started := Time.get_ticks_usec()
	for frame in 180: arena._process(1.0 / 60.0)
	var average_700 := (Time.get_ticks_usec() - started) / 1000.0 / 180.0
	print("[PERF] 700 enemies: %.2f ms/tick (CPU simulation, headless)" % average_700)
	if arena.enemies.size() < 700 or average_700 >= 16.67:
		push_error("[PERF] 700-enemy 60 Hz target failed")
		get_tree().quit(1)
		return
	while arena.enemies.size() < 1000:
		arena._spawn_enemy(arena.enemies.size() % 70 == 0)
	started = Time.get_ticks_usec()
	for frame in 60: arena._process(1.0 / 60.0)
	var average_1000 := (Time.get_ticks_usec() - started) / 1000.0 / 60.0
	print("[PERF] 1000 enemies: %.2f ms/tick (extreme CPU simulation, headless)" % average_1000)
	if arena.enemies.size() < 1000 or average_1000 >= 33.33:
		push_error("[PERF] 1000-enemy extreme-playability target failed")
		get_tree().quit(1)
		return
	print("[PERF] HORDE STRESS PASSED")
	arena.ending = true
	arena.free()
	arena = null
	await get_tree().process_frame
	AudioManager.shutdown()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit(0)
