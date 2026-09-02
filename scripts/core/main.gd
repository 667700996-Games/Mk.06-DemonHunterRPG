extends Node

const ArenaScript = preload("res://scripts/world/arena.gd")
const TitleEmbers = preload("res://scripts/effects/title_embers.gd")

var layer: CanvasLayer
var screen_root: Control
var title_art: TextureRect
var title_time := 0.0
var selected_tier := 1
var selected_biome := "graveyard"
var active_arena: Node
var transition_rect: ColorRect

func _ready() -> void:
	randomize()
	_configure_input()
	SaveManager.load_game()
	Game.apply_settings()
	if "--smoke-test" in OS.get_cmdline_user_args():
		var smoke_test: Node = load("res://tests/smoke_test.gd").new()
		add_child(smoke_test)
		return
	if "--stress-test" in OS.get_cmdline_user_args():
		var stress_test: Node = load("res://tests/performance_test.gd").new()
		add_child(stress_test)
		return
	if "--loot-stress-test" in OS.get_cmdline_user_args():
		var loot_stress_test: Node = load("res://tests/loot_performance_test.gd").new()
		add_child(loot_stress_test)
		return
	if "--capture-run" in OS.get_cmdline_user_args():
		_start_run(1, "graveyard")
		call_deferred("_prepare_capture_run")
		return
	if "--capture-settings" in OS.get_cmdline_user_args():
		show_settings()
		return
	show_title()

func _prepare_capture_run() -> void:
	if is_instance_valid(active_arena):
		active_arena._debug_command("stress")
		Game.current_run.elapsed = 105.0
		if "--inventory" in OS.get_cmdline_user_args():
			for index in 16:
				var item := DataRegistry.roll_item(12 + index, 8 + index % 5, ["lightning", "critical", "projectile"])
				Game.inventory.push_front(item)
			get_tree().paused = true
			active_arena.hud.show_character()

func _process(delta: float) -> void:
	if is_instance_valid(title_art):
		title_time += delta
		var drift := sin(title_time * 0.16) * 10.0
		title_art.position = Vector2(-18.0 + drift, -12.0)
		title_art.scale = Vector2.ONE * (1.035 + sin(title_time * 0.11) * 0.004)

func _configure_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SPACE], "skill_q": [KEY_Q], "skill_e": [KEY_E],
		"ultimate": [KEY_R], "character": [KEY_TAB], "pause": [KEY_ESCAPE],
		"interact": [KEY_F], "potion": [KEY_1]
	}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	for action in ["attack", "secondary"]:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, mouse_event)
	var joypad := {
		"attack": JOY_BUTTON_RIGHT_SHOULDER, "secondary": JOY_BUTTON_LEFT_SHOULDER,
		"dash": JOY_BUTTON_A, "skill_q": JOY_BUTTON_X, "skill_e": JOY_BUTTON_Y,
		"ultimate": JOY_BUTTON_B, "character": JOY_BUTTON_BACK, "pause": JOY_BUTTON_START,
		"interact": JOY_BUTTON_DPAD_UP, "potion": JOY_BUTTON_DPAD_DOWN
	}
	for action in joypad:
		var event := InputEventJoypadButton.new()
		event.button_index = joypad[action]
		InputMap.action_add_event(action, event)
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"aim_left": [JOY_AXIS_RIGHT_X, -1.0], "aim_right": [JOY_AXIS_RIGHT_X, 1.0],
		"aim_up": [JOY_AXIS_RIGHT_Y, -1.0], "aim_down": [JOY_AXIS_RIGHT_Y, 1.0]
	}
	for action in axes:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.22)
		var motion := InputEventJoypadMotion.new()
		motion.axis = axes[action][0]
		motion.axis_value = axes[action][1]
		InputMap.action_add_event(action, motion)
	var right_trigger := InputEventJoypadMotion.new()
	right_trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	right_trigger.axis_value = 1.0
	InputMap.action_add_event("attack", right_trigger)
	var left_trigger := InputEventJoypadMotion.new()
	left_trigger.axis = JOY_AXIS_TRIGGER_LEFT
	left_trigger.axis_value = 1.0
	InputMap.action_add_event("secondary", left_trigger)

func _new_screen() -> Control:
	_clear_current()
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.theme = UIFactory.game_theme()
	layer.add_child(screen_root)
	transition_rect = ColorRect.new()
	transition_rect.color = Color("#050711")
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(transition_rect)
	call_deferred("_play_screen_transition")
	return screen_root

func _play_screen_transition() -> void:
	if not is_instance_valid(transition_rect) or not is_instance_valid(screen_root): return
	screen_root.move_child(transition_rect, screen_root.get_child_count() - 1)
	var tween := transition_rect.create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, 0.28)
	tween.tween_callback(transition_rect.queue_free)

func _clear_current() -> void:
	if is_instance_valid(active_arena):
		active_arena.queue_free()
		active_arena = null
	if is_instance_valid(layer): layer.queue_free()
	layer = null
	screen_root = null
	title_art = null

func show_title() -> void:
	_new_screen()
	AudioManager.play_music("menu")
	title_art = TextureRect.new()
	title_art.texture = load("res://assets/art/title_graveyard.png")
	title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(title_art)
	screen_root.move_child(title_art, 0)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(shade)
	var embers := TitleEmbers.new()
	embers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(embers)

	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 120)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 830
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(UIFactory.spacer(105))
	var title := UIFactory.heading("R I F T F A L L", 104, Color("#f5efff"))
	title.add_theme_color_override("font_shadow_color", Color("#eb3f67"))
	title.add_theme_constant_override("shadow_offset_x", 7)
	title.add_theme_constant_override("shadow_offset_y", 6)
	left.add_child(title)
	left.add_child(UIFactory.heading("NIGHT OF A THOUSAND BLADES", 27, Color("#bca8e8")))
	left.add_child(UIFactory.spacer(430))
	left.add_child(UIFactory.label("ONE HUNTER  •  ENDLESS BUILDS  •  NO MERCY", 18, Color("#a9b6d2"), HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(left)

	var menu_wrap := CenterContainer.new()
	menu_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var menu_panel := PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(410, 650)
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 14)
	menu.add_child(UIFactory.heading("ENTER THE RIFT", 34, UIFactory.GOLD))
	menu.add_child(UIFactory.label(UIFactory.format("Tier %d unlocked  •  %d embers", [Game.meta.unlocked_tier, Game.meta.currency]), 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	menu.add_child(UIFactory.spacer(15))
	var start := UIFactory.button("START NEW RIFT")
	start.pressed.connect(show_run_setup)
	menu.add_child(start)
	var continue_button := UIFactory.button(UIFactory.format("QUICK RUN — TIER %d", [Game.meta.highest_tier]))
	continue_button.pressed.connect(func(): _start_run(Game.meta.highest_tier, _biome_for_tier(Game.meta.highest_tier)))
	menu.add_child(continue_button)
	var upgrades := UIFactory.button("LEGACY UPGRADES")
	upgrades.pressed.connect(show_meta)
	menu.add_child(upgrades)
	var stats := UIFactory.button("HUNTER RECORDS")
	stats.pressed.connect(show_statistics)
	menu.add_child(stats)
	var settings_button := UIFactory.button("SETTINGS")
	settings_button.pressed.connect(show_settings)
	menu.add_child(settings_button)
	var quit := UIFactory.button("QUIT TO DESKTOP")
	quit.pressed.connect(_quit_game)
	menu.add_child(quit)
	menu_panel.add_child(UIFactory.margin(menu, 28))
	menu_wrap.add_child(menu_panel)
	content.add_child(menu_wrap)
	screen_root.add_child(UIFactory.margin(content, 55))
	start.grab_focus()

func _quit_game() -> void:
	AudioManager.shutdown()
	await get_tree().create_timer(0.08, true, false, true).timeout
	get_tree().quit()

func show_run_setup() -> void:
	_new_screen()
	_add_menu_background()
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(920, 780)
	outer.add_theme_constant_override("separation", 22)
	outer.add_child(UIFactory.heading("CHOOSE YOUR RIFT", 54, UIFactory.GOLD))
	outer.add_child(UIFactory.label("Higher tiers increase density, elite affixes, danger, and loot quality.", 20, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var tier_row := HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 16)
	tier_row.add_child(UIFactory.label("DIFFICULTY TIER", 22, UIFactory.TEXT))
	var tier_select := OptionButton.new()
	tier_select.custom_minimum_size = Vector2(310, 58)
	for tier in range(1, mini(10, int(Game.meta.unlocked_tier)) + 1): tier_select.add_item(UIFactory.format("TIER %02d", [tier]), tier)
	tier_select.select(maxi(0, tier_select.item_count - 1))
	selected_tier = tier_select.get_selected_id()
	tier_select.item_selected.connect(func(index: int): selected_tier = tier_select.get_item_id(index))
	tier_row.add_child(tier_select)
	outer.add_child(tier_row)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	var biome_buttons: Array[Button] = []
	for biome in DataRegistry.biomes:
		var card := Button.new()
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(270, 310)
		card.text = UIFactory.format("%s\n\n%s\n\nBOSS: %s", [UIFactory.localize(biome.name), UIFactory.localize(biome.description), UIFactory.localize(_boss_name(biome))])
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 18)
		card.pressed.connect(_choose_biome.bind(biome.id, card, biome_buttons))
		biome_buttons.append(card)
		cards.add_child(card)
	outer.add_child(cards)
	selected_biome = DataRegistry.biomes[0].id
	biome_buttons[0].button_pressed = true
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	var back := UIFactory.button("BACK", Vector2(250, 60))
	back.pressed.connect(show_title)
	actions.add_child(back)
	var begin := UIFactory.button("OPEN RIFT", Vector2(360, 68))
	begin.add_theme_stylebox_override("normal", UIFactory.panel_style(Color("#541f43"), UIFactory.CRIMSON, 3, 8))
	begin.pressed.connect(func(): _start_run(selected_tier, selected_biome))
	actions.add_child(begin)
	outer.add_child(actions)
	_add_center_panel(outer)
	begin.grab_focus()

func _choose_biome(id: String, selected: Button, group: Array[Button]) -> void:
	selected_biome = id
	for button in group: button.button_pressed = button == selected

func _boss_name(biome: Dictionary) -> String:
	var ids: PackedStringArray = biome.bosses
	return DataRegistry.by_boss.get(ids[0], {}).get("name", "Unknown")

func _biome_for_tier(tier: int) -> String:
	return DataRegistry.biomes[(tier - 1) % DataRegistry.biomes.size()].id

func _start_run(tier: int, biome: String) -> void:
	_clear_current()
	Game.start_run(tier, biome)
	active_arena = ArenaScript.new()
	active_arena.run_finished.connect(_on_run_finished)
	add_child(active_arena)

func _on_run_finished(result: Dictionary) -> void:
	if is_instance_valid(active_arena): active_arena.queue_free()
	active_arena = null
	show_results(result)

func show_results(result: Dictionary) -> void:
	_new_screen()
	_add_menu_background()
	AudioManager.play_music("victory" if result.get("cleared", false) else "menu")
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(980, 840)
	box.add_theme_constant_override("separation", 13)
	box.add_child(UIFactory.heading("RIFT CONQUERED" if result.cleared else "THE HUNTER FELL", 58, UIFactory.GOLD if result.cleared else UIFactory.CRIMSON))
	box.add_child(UIFactory.label(UIFactory.format("TIER %d  •  %s  •  %s", [result.tier, UIFactory.localize(DataRegistry.get_biome(result.biome).name), _format_time(result.elapsed)]), 22, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var values := [
		["KILLS", result.kills], ["ELITES", result.elite_kills], ["DAMAGE", _compact(result.damage)], ["DPS", _compact(result.dps)],
		["HIGHEST CRIT", _compact(result.highest_crit)], ["DAMAGE TAKEN", _compact(result.damage_taken)], ["ITEMS", result.items], ["EMBERS", "+%d" % result.currency_earned]
	]
	for value in values:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(220, 105)
		var lines := VBoxContainer.new()
		lines.add_child(UIFactory.label(str(value[0]), 15, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		lines.add_child(UIFactory.heading(str(value[1]), 30, UIFactory.TEXT))
		cell.add_child(lines)
		grid.add_child(cell)
	box.add_child(grid)
	var tags := Game.build_tags()
	var sorted_tags := tags.keys()
	sorted_tags.sort_custom(func(a, b): return tags[a] > tags[b])
	var summary: Array[String] = []
	for index in mini(3, sorted_tags.size()): summary.append(UIFactory.localize(str(sorted_tags[index])))
	box.add_child(UIFactory.label(UIFactory.format("BUILD SIGNATURE  •  %s", [" / ".join(summary)]), 20, UIFactory.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	var rarity_text: Array[String] = []
	for rarity in DataRegistry.RARITIES:
		if result.rarities.get(rarity, 0) > 0: rarity_text.append("%s %d" % [UIFactory.localize(rarity), result.rarities[rarity]])
	box.add_child(UIFactory.label(UIFactory.format("LOOT  •  %s", ["   ".join(rarity_text)]), 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	var menu := UIFactory.button("MAIN MENU", Vector2(250, 60))
	menu.pressed.connect(show_title)
	actions.add_child(menu)
	var retry := UIFactory.button("RETRY TIER", Vector2(250, 60))
	retry.pressed.connect(func(): _start_run(result.tier, result.biome))
	actions.add_child(retry)
	if result.cleared:
		var next := UIFactory.button("NEXT TIER", Vector2(280, 66))
		next.pressed.connect(func(): _start_run(result.tier + 1, _biome_for_tier(result.tier + 1)))
		actions.add_child(next)
	box.add_child(actions)
	_add_center_panel(box)

func show_meta() -> void:
	_new_screen()
	_add_menu_background()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(850, 760)
	box.add_theme_constant_override("separation", 18)
	var currency_label := UIFactory.heading(UIFactory.format("%d LEGACY EMBERS", [Game.meta.currency]), 38, UIFactory.GOLD)
	box.add_child(UIFactory.heading("LEGACY UPGRADES", 54))
	box.add_child(currency_label)
	var offers := [
		["STARTING COIN", "Begin each rift with +25 gold.", "starting_gold", 25, 40],
		["FATE'S MERCY", "Begin each rift with +1 reroll.", "starting_rerolls", 1, 90],
		["RIFT MASTERY", "Permanent +3% starting power.", "passive_power", 3, 120]
	]
	for offer in offers:
		var row := HBoxContainer.new()
		row.add_child(UIFactory.label(UIFactory.format("%s\n%s\nCURRENT: %s", [UIFactory.localize(offer[0]), UIFactory.localize(offer[1]), Game.meta[offer[2]]]), 20, UIFactory.TEXT))
		row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := UIFactory.button(UIFactory.format("BUY — %d", [offer[4]]), Vector2(210, 66))
		buy.disabled = Game.meta.currency < offer[4]
		buy.pressed.connect(_buy_meta.bind(offer[2], offer[3], offer[4]))
		row.add_child(buy)
		box.add_child(row)
	var unlock_item := UIFactory.button("UNSEAL 3 ITEM BASES — 80")
	unlock_item.disabled = Game.meta.currency < 80 or Game.meta.unlocked_items.size() >= DataRegistry.base_items.size() - 16
	unlock_item.pressed.connect(_buy_unlock.bind("item", 80))
	box.add_child(unlock_item)
	var unlock_power := UIFactory.button("UNBIND A LEGENDARY POWER — 150")
	unlock_power.disabled = Game.meta.currency < 150 or Game.meta.unlocked_powers.size() >= DataRegistry.legendary_powers.size() - 10
	unlock_power.pressed.connect(_buy_unlock.bind("power", 150))
	box.add_child(unlock_power)
	var back := UIFactory.button("BACK TO TITLE", Vector2(300, 62))
	back.pressed.connect(show_title)
	box.add_child(back)
	_add_center_panel(box)

func _buy_meta(key: String, amount: int, cost: int) -> void:
	if Game.meta.currency < cost: return
	Game.meta.currency -= cost
	Game.meta[key] += amount
	SaveManager.save_game()
	show_meta()

func _buy_unlock(kind: String, cost: int) -> void:
	if Game.meta.currency < cost: return
	var starter_items := ["rift_repeater", "grave_razor", "stormneedle", "cinder_staff", "iron_cowl", "seer_hood", "ossuary_plate", "blood_coat", "razor_grips", "spark_gauntlets", "ashwalkers", "gale_treads", "storm_eye", "funeral_charm", "coil_ring", "red_oath"]
	var starter_powers := ["storm_web", "red_bloom", "hoarfrost_step", "execution_oath", "trident_law", "funeral_pyres", "slow_constellation", "thunderheart", "winterglass", "plague_tide"]
	var candidates: Array[String] = []
	if kind == "item":
		for item in DataRegistry.base_items:
			if item.id not in starter_items and item.id not in Game.meta.unlocked_items: candidates.append(item.id)
	else:
		for power in DataRegistry.legendary_powers:
			if power.id not in starter_powers and power.id not in Game.meta.unlocked_powers: candidates.append(power.id)
	if candidates.is_empty(): return
	candidates.shuffle()
	Game.meta.currency -= cost
	var count := mini(3, candidates.size()) if kind == "item" else 1
	for index in count:
		if kind == "item": Game.meta.unlocked_items.append(candidates[index])
		else: Game.meta.unlocked_powers.append(candidates[index])
	SaveManager.save_game()
	show_meta()

func show_statistics() -> void:
	_new_screen()
	_add_menu_background()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 760)
	box.add_theme_constant_override("separation", 14)
	box.add_child(UIFactory.heading("HUNTER RECORDS", 52, UIFactory.GOLD))
	var rows := [
		["TOTAL RUNS", Game.statistics.total_runs], ["TOTAL KILLS", Game.statistics.total_kills],
		["ELITE KILLS", Game.statistics.elite_kills], ["BOSS KILLS", Game.statistics.boss_kills],
		["HIGHEST TIER", Game.statistics.highest_tier], ["FASTEST CLEAR", _format_time(Game.statistics.fastest_clear)],
		["HIGHEST HIT", _compact(Game.statistics.highest_damage)], ["HIGHEST DPS", _compact(Game.statistics.highest_dps)],
		["LEGENDARY DROPS", Game.statistics.legendary_drops]
	]
	for row_data in rows:
		var row := HBoxContainer.new()
		var name_label := UIFactory.label(row_data[0], 21, UIFactory.MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UIFactory.label(str(row_data[1]), 25, UIFactory.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		box.add_child(row)
	var back := UIFactory.button("BACK TO TITLE")
	back.pressed.connect(show_title)
	box.add_child(back)
	_add_center_panel(box)

func show_settings() -> void:
	_new_screen()
	_add_menu_background()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1280, 820)
	box.add_theme_constant_override("separation", 14)
	box.add_child(UIFactory.heading("SETTINGS", 52, UIFactory.GOLD))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 34)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 610
	left.add_theme_constant_override("separation", 10)
	left.add_child(UIFactory.heading("DISPLAY & CONTROL", 24, UIFactory.CYAN))
	_add_language_option(left)
	_add_option(left, "RESOLUTION", "resolution", ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"])
	_add_option(left, "FPS LIMIT", "fps_limit", [60, 90, 120, 144, 240])
	_add_toggle(left, "FULLSCREEN", "fullscreen")
	_add_toggle(left, "V-SYNC", "vsync")
	_add_toggle(left, "AUTO ATTACK", "auto_attack")
	_add_toggle(left, "HOLD TO ATTACK", "hold_to_attack")
	_add_toggle(left, "GAMEPAD VIBRATION", "gamepad_vibration")
	_add_toggle(left, "AUTO SALVAGE COMMON", "auto_salvage_common")
	_add_toggle(left, "AUTO SALVAGE MAGIC", "auto_salvage_magic")
	_add_toggle(left, "AUTO SALVAGE RARE", "auto_salvage_rare")
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 610
	right.add_theme_constant_override("separation", 10)
	right.add_child(UIFactory.heading("AUDIO & ACCESSIBILITY", 24, UIFactory.CYAN))
	_add_toggle(right, "AUTO POTION  •  HP ≤ 35%", "auto_potion")
	_add_toggle(right, "AUTO BARRIER  •  LOW / EMPTY", "auto_barrier")
	_add_slider(right, "MASTER VOLUME", "master_volume", 0.0, 1.0, 0.05)
	_add_slider(right, "MUSIC VOLUME", "music_volume", 0.0, 1.0, 0.05)
	_add_slider(right, "SFX VOLUME", "sfx_volume", 0.0, 1.0, 0.05)
	_add_slider(right, "UI VOLUME", "ui_volume", 0.0, 1.0, 0.05)
	_add_slider(right, "SCREEN SHAKE", "screen_shake", 0.0, 1.0, 0.05)
	_add_slider(right, "FLASH INTENSITY", "flash_intensity", 0.0, 1.0, 0.05)
	_add_slider(right, "DAMAGE NUMBERS", "damage_numbers", 0.0, 1.0, 0.05)
	_add_slider(right, "UI SCALE", "ui_scale", 0.8, 1.3, 0.05)
	columns.add_child(right)
	box.add_child(columns)
	var back := UIFactory.button("SAVE & RETURN")
	back.pressed.connect(func(): Game.apply_settings(); SaveManager.save_game(); show_title())
	box.add_child(back)
	_add_center_panel(box)

func _add_toggle(parent: VBoxContainer, title: String, key: String) -> void:
	var row := HBoxContainer.new()
	var text_label := UIFactory.label(title, 20, UIFactory.TEXT)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_label)
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(Game.settings[key])
	toggle.toggled.connect(func(value: bool): Game.settings[key] = value)
	row.add_child(toggle)
	parent.add_child(row)

func _add_language_option(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var text_label := UIFactory.label("LANGUAGE", 20, UIFactory.TEXT)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_label)
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(280, 48)
	var locales := [["한국어", "ko"], ["English", "en"]]
	for index in locales.size():
		select.add_item(locales[index][0], index)
		if locales[index][1] == Game.settings.language: select.select(index)
	select.item_selected.connect(func(index: int):
		Game.settings.language = locales[index][1]
		TranslationServer.set_locale(Game.settings.language)
		call_deferred("show_settings")
	)
	row.add_child(select)
	parent.add_child(row)

func _add_slider(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	var text_label := UIFactory.label(title, 20, UIFactory.TEXT)
	text_label.custom_minimum_size.x = 280
	row.add_child(text_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(Game.settings[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float): Game.settings[key] = value)
	row.add_child(slider)
	var value_label := UIFactory.label("%d%%" % int(slider.value * 100.0), 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size.x = 70
	slider.value_changed.connect(func(value: float): value_label.text = "%d%%" % int(value * 100.0))
	row.add_child(value_label)
	parent.add_child(row)

func _add_option(parent: VBoxContainer, title: String, key: String, values: Array) -> void:
	var row := HBoxContainer.new()
	var text_label := UIFactory.label(title, 20, UIFactory.TEXT)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_label)
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(280, 48)
	for index in values.size():
		select.add_item(str(values[index]), index)
		if str(values[index]) == str(Game.settings[key]): select.select(index)
	select.item_selected.connect(func(index: int): Game.settings[key] = values[index])
	row.add_child(select)
	parent.add_child(row)

func _add_menu_background() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/art/title_graveyard.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.34, 0.38, 0.55, 1.0)
	screen_root.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.04, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(shade)
	screen_root.move_child(background, 0)
	screen_root.move_child(shade, 1)

func _add_center_panel(content: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_child(UIFactory.margin(content, 32))
	center.add_child(panel)
	screen_root.add_child(center)

func _format_time(seconds: float) -> String:
	if seconds <= 0.0: return "—"
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _compact(value: float) -> String:
	if value >= 1000000.0: return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0: return "%.1fK" % (value / 1000.0)
	return str(int(value))
