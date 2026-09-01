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

func _ready() -> void:
	randomize()
	_configure_input()
	SaveManager.load_game()
	Game.apply_settings()
	show_title()

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
		"attack": [MOUSE_BUTTON_LEFT], "secondary": [MOUSE_BUTTON_RIGHT],
		"dash": [KEY_SPACE], "skill_q": [KEY_Q], "skill_e": [KEY_E],
		"ultimate": [KEY_R], "character": [KEY_TAB], "pause": [KEY_ESCAPE],
		"interact": [KEY_F]
	}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
		for code in keys[action]:
			var event: InputEvent
			if code is Key:
				event = InputEventKey.new()
				event.physical_keycode = code
			else:
				event = InputEventMouseButton.new()
				event.button_index = code
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	var joypad := {
		"attack": JOY_BUTTON_RIGHT_SHOULDER, "secondary": JOY_BUTTON_LEFT_SHOULDER,
		"dash": JOY_BUTTON_A, "skill_q": JOY_BUTTON_X, "skill_e": JOY_BUTTON_Y,
		"ultimate": JOY_BUTTON_B, "character": JOY_BUTTON_BACK, "pause": JOY_BUTTON_START,
		"interact": JOY_BUTTON_DPAD_UP
	}
	for action in joypad:
		var event := InputEventJoypadButton.new()
		event.button_index = joypad[action]
		InputMap.action_add_event(action, event)

func _new_screen() -> Control:
	_clear_current()
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.theme = UIFactory.game_theme()
	layer.add_child(screen_root)
	return screen_root

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
	menu.add_child(UIFactory.label("Tier %d unlocked  •  %d embers" % [Game.meta.unlocked_tier, Game.meta.currency], 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	menu.add_child(UIFactory.spacer(15))
	var start := UIFactory.button("START NEW RIFT")
	start.pressed.connect(show_run_setup)
	menu.add_child(start)
	var continue_button := UIFactory.button("QUICK RUN — TIER %d" % Game.meta.highest_tier)
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
	quit.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit)
	menu_panel.add_child(UIFactory.margin(menu, 28))
	menu_wrap.add_child(menu_panel)
	content.add_child(menu_wrap)
	screen_root.add_child(UIFactory.margin(content, 55))
	start.grab_focus()

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
	for tier in range(1, mini(10, int(Game.meta.unlocked_tier)) + 1): tier_select.add_item("TIER %02d" % tier, tier)
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
		card.text = "%s\n\n%s\n\nBOSS: %s" % [biome.name.to_upper(), biome.description, _boss_name(biome)]
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
	box.add_child(UIFactory.label("TIER %d  •  %s  •  %s" % [result.tier, DataRegistry.get_biome(result.biome).name, _format_time(result.elapsed)], 22, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
	for index in mini(3, sorted_tags.size()): summary.append(str(sorted_tags[index]).to_upper())
	box.add_child(UIFactory.label("BUILD SIGNATURE  •  " + " / ".join(summary), 20, UIFactory.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	var rarity_text: Array[String] = []
	for rarity in DataRegistry.RARITIES:
		if result.rarities.get(rarity, 0) > 0: rarity_text.append("%s %d" % [rarity, result.rarities[rarity]])
	box.add_child(UIFactory.label("LOOT  •  " + "   ".join(rarity_text), 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
	var currency_label := UIFactory.heading("%d LEGACY EMBERS" % Game.meta.currency, 38, UIFactory.GOLD)
	box.add_child(UIFactory.heading("LEGACY UPGRADES", 54))
	box.add_child(currency_label)
	var offers := [
		["STARTING COIN", "Begin each rift with +25 gold.", "starting_gold", 25, 40],
		["FATE'S MERCY", "Begin each rift with +1 reroll.", "starting_rerolls", 1, 90],
		["RIFT MASTERY", "Permanent +3% starting power.", "passive_power", 3, 120]
	]
	for offer in offers:
		var row := HBoxContainer.new()
		row.add_child(UIFactory.label("%s\n%s\nCURRENT: %s" % [offer[0], offer[1], Game.meta[offer[2]]], 20, UIFactory.TEXT))
		row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := UIFactory.button("BUY — %d" % offer[4], Vector2(210, 66))
		buy.disabled = Game.meta.currency < offer[4]
		buy.pressed.connect(_buy_meta.bind(offer[2], offer[3], offer[4]))
		row.add_child(buy)
		box.add_child(row)
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
	box.custom_minimum_size = Vector2(820, 840)
	box.add_theme_constant_override("separation", 12)
	box.add_child(UIFactory.heading("SETTINGS", 52, UIFactory.GOLD))
	_add_toggle(box, "FULLSCREEN", "fullscreen")
	_add_toggle(box, "V-SYNC", "vsync")
	_add_toggle(box, "AUTO ATTACK", "auto_attack")
	_add_toggle(box, "GAMEPAD VIBRATION", "gamepad_vibration")
	_add_slider(box, "MASTER VOLUME", "master_volume", 0.0, 1.0, 0.05)
	_add_slider(box, "MUSIC VOLUME", "music_volume", 0.0, 1.0, 0.05)
	_add_slider(box, "SFX VOLUME", "sfx_volume", 0.0, 1.0, 0.05)
	_add_slider(box, "SCREEN SHAKE", "screen_shake", 0.0, 1.0, 0.05)
	_add_slider(box, "FLASH INTENSITY", "flash_intensity", 0.0, 1.0, 0.05)
	_add_slider(box, "DAMAGE NUMBERS", "damage_numbers", 0.0, 1.0, 0.05)
	_add_slider(box, "UI SCALE", "ui_scale", 0.8, 1.3, 0.05)
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
