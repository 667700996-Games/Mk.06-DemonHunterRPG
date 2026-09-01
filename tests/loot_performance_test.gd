extends Node

const DROP_COUNT := 1000

func _ready() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("[LOOT PERF] " + message)
	get_tree().quit(1)

func _run() -> void:
	await get_tree().process_frame
	var original_state := Game.serialize().duplicate(true)
	Game.inventory.clear()
	for slot in Game.SLOTS: Game.equipment[slot] = {}
	Game.settings.auto_salvage_common = false
	Game.settings.auto_salvage_magic = false
	Game.settings.auto_salvage_rare = false
	Game.start_run(10, "graveyard")
	var arena: RiftArena = load("res://scripts/world/arena.gd").new()
	get_tree().root.add_child(arena)
	arena.god_mode = true

	var started := Time.get_ticks_usec()
	for index in DROP_COUNT:
		arena._drop_item(arena.player.global_position, index % 7 == 0)
	var drop_msec := (Time.get_ticks_usec() - started) / 1000.0
	if arena.ground_item_count > arena.MAX_GROUND_ITEMS:
		_fail("ground item safety cap failed")
		return

	started = Time.get_ticks_usec()
	arena._simulate_pickups(1.0 / 60.0)
	var collect_msec := (Time.get_ticks_usec() - started) / 1000.0
	if Game.inventory.size() > Game.INVENTORY_CAP:
		_fail("inventory safety cap failed")
		return
	if arena.hud.toast_layer.get_child_count() > arena.hud.MAX_LOOT_TOASTS:
		_fail("loot toast safety cap failed")
		return
	var pool_after_first_wave := arena.pickup_pool.size()
	for index in DROP_COUNT:
		arena._drop_item(arena.player.global_position, index % 9 == 0)
	arena._simulate_pickups(1.0 / 60.0)
	if arena.pickup_pool.size() > pool_after_first_wave:
		_fail("pickup pool grew during a reusable second wave")
		return
	if collect_msec >= 100.0:
		_fail("1000-drop collection exceeded 100 ms: %.2f ms" % collect_msec)
		return
	print("[LOOT PERF] %d drops generated in %.2f ms; collection %.2f ms" % [DROP_COUNT, drop_msec, collect_msec])
	print("[LOOT PERF] inventory=%d ground=%d pool=%d toasts=%d" % [Game.inventory.size(), arena.ground_item_count, arena.pickup_pool.size(), arena.hud.toast_layer.get_child_count()])
	print("[LOOT PERF] MASS LOOT STRESS PASSED")
	arena.ending = true
	arena.free()
	Game.hydrate(original_state)
	AudioManager.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
