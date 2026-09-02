class_name RiftHUD
extends CanvasLayer

signal upgrade_selected(upgrade: Dictionary)
signal reroll_requested
signal banish_requested(upgrade: Dictionary)
signal lock_requested(upgrade: Dictionary)
signal favor_requested(tag: String)
signal interface_closed
signal return_to_menu

var hp_bar: ProgressBar
var barrier_bar: ProgressBar
var xp_bar: ProgressBar
var rift_bar: ProgressBar
var hp_text: Label
var level_text: Label
var timer_text: Label
var tier_text: Label
var kill_text: Label
var danger_text: Label
var buff_text: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name: Label
var boss_phase: Label
var skill_fills: Dictionary = {}
var skill_titles: Dictionary = {}
var toast_layer: VBoxContainer
var announcement: Label
var announcement_tween: Tween
var overlay: Control
var latest_item: Dictionary = {}
var fps_label: Label
var inventory_filter := "ALL"
var inventory_sort := "BUILD SCORE"
const MAX_LOOT_TOASTS := 3
const OFFENSE_STATS := ["damage", "all_damage", "attack_speed", "crit_chance", "crit_damage", "projectiles", "penetration", "ricochet", "chain", "area", "lucky_hit", "execute", "explosion_damage", "fire_damage", "ice_damage", "lightning_damage", "poison_damage", "bleed_damage", "elemental_damage", "melee_damage", "projectile_damage", "summon_damage", "boss_damage", "elite_damage"]
const TOUGHNESS_STATS := ["max_health", "barrier", "damage_reduction", "barrier_regen", "life_steal", "potion_power"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_hud()

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIFactory.game_theme()
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_top = 24
	top.offset_right = -28
	top.offset_bottom = 170
	top.add_theme_constant_override("separation", 28)
	root.add_child(top)
	buff_text = UIFactory.label("", 16, UIFactory.GOLD)
	buff_text.position = Vector2(34, 172)
	buff_text.custom_minimum_size = Vector2(430, 28)
	root.add_child(buff_text)

	var vitals := PanelContainer.new()
	vitals.custom_minimum_size = Vector2(430, 130)
	var vital_box := VBoxContainer.new()
	var name_row := HBoxContainer.new()
	var hunter_name := UIFactory.heading("THE LAST HUNTER", 22, UIFactory.TEXT)
	hunter_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hunter_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_row.add_child(hunter_name)
	level_text = UIFactory.label("LV 1", 19, UIFactory.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	level_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(level_text)
	vital_box.add_child(name_row)
	hp_bar = _bar(Color("#e43f5a"), 31)
	hp_text = UIFactory.label("140 / 140", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.add_child(hp_text)
	vital_box.add_child(hp_bar)
	barrier_bar = _bar(Color("#58d7ff"), 12)
	vital_box.add_child(barrier_bar)
	vitals.add_child(UIFactory.margin(vital_box, 10))
	top.add_child(vitals)

	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 130
	var center_box := VBoxContainer.new()
	var rift_row := HBoxContainer.new()
	var rift_label := UIFactory.label("GREATER RIFT", 18, UIFactory.MUTED)
	rift_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rift_row.add_child(rift_label)
	timer_text = UIFactory.heading("00:00", 24, UIFactory.TEXT)
	timer_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rift_row.add_child(timer_text)
	center_box.add_child(rift_row)
	rift_bar = _bar(UIFactory.VIOLET, 31)
	rift_bar.max_value = 1.0
	center_box.add_child(rift_bar)
	xp_bar = _bar(UIFactory.CYAN, 12)
	xp_bar.max_value = 1.0
	center_box.add_child(xp_bar)
	center.add_child(UIFactory.margin(center_box, 10))
	top.add_child(center)

	var status := PanelContainer.new()
	status.custom_minimum_size = Vector2(330, 130)
	var status_box := VBoxContainer.new()
	tier_text = UIFactory.heading("TIER 01", 27, UIFactory.GOLD)
	status_box.add_child(tier_text)
	kill_text = UIFactory.label("0 KILLS  •  0 ELITES", 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	status_box.add_child(kill_text)
	danger_text = UIFactory.label("NO ELITE SIGNAL", 14, Color("#ef7994"), HORIZONTAL_ALIGNMENT_CENTER)
	status_box.add_child(danger_text)
	fps_label = UIFactory.label("", 15, Color("#6f829f"), HORIZONTAL_ALIGNMENT_CENTER)
	status_box.add_child(fps_label)
	status.add_child(UIFactory.margin(status_box, 10))
	top.add_child(status)

	boss_panel = PanelContainer.new()
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.position = Vector2(-400, 178)
	boss_panel.custom_minimum_size = Vector2(800, 92)
	var boss_box := VBoxContainer.new()
	var boss_row := HBoxContainer.new()
	boss_name = UIFactory.heading("RIFT GUARDIAN", 24, UIFactory.CRIMSON)
	boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_phase = UIFactory.label("PHASE I", 17, UIFactory.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	boss_row.add_child(boss_name)
	boss_row.add_child(boss_phase)
	boss_box.add_child(boss_row)
	boss_bar = _bar(Color("#ef315d"), 24)
	boss_bar.max_value = 1.0
	boss_box.add_child(boss_bar)
	boss_panel.add_child(boss_box)
	boss_panel.visible = false
	root.add_child(boss_panel)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-390, -128)
	bottom.custom_minimum_size = Vector2(780, 96)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	var skills := [
		["potion", "1", "POTION", Color("#5ee39a")],
		["secondary", "RMB", "NOVA", Color("#ff4f76")], ["q", "Q", "METEOR", Color("#ff7b35")],
		["e", "E", "AEGIS", Color("#55d9ff")], ["dash", "SPACE", "DASH", Color("#a26cff")],
		["r", "R", "RIFTFALL", Color("#ffd166")]
	]
	for skill in skills:
		var cell := _skill_cell(skill[1], skill[2], skill[3])
		skill_fills[skill[0]] = cell.get_meta("fill")
		skill_titles[skill[0]] = cell.get_meta("title")
		bottom.add_child(cell)
	root.add_child(bottom)

	toast_layer = VBoxContainer.new()
	toast_layer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toast_layer.position = Vector2(-400, -460)
	toast_layer.custom_minimum_size = Vector2(380, 320)
	toast_layer.alignment = BoxContainer.ALIGNMENT_END
	toast_layer.add_theme_constant_override("separation", 6)
	root.add_child(toast_layer)

	announcement = UIFactory.heading("", 54, Color.WHITE)
	announcement.set_anchors_preset(Control.PRESET_CENTER_TOP)
	announcement.position = Vector2(-600, 285)
	announcement.custom_minimum_size = Vector2(1200, 90)
	announcement.modulate.a = 0.0
	root.add_child(announcement)

func _bar(color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UIFactory.panel_style(Color("#080b14"), Color("#29344f"), 1, 3))
	bar.add_theme_stylebox_override("fill", UIFactory.panel_style(color.darkened(0.2), color.lightened(0.15), 1, 3))
	return bar

func _skill_cell(key: String, title: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(142, 88)
	panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color(0.035, 0.045, 0.08, 0.94), color.darkened(0.35), 2, 7))
	var stack := VBoxContainer.new()
	var key_label := UIFactory.label(key, 15, color, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(key_label)
	var title_label := UIFactory.label(title, 17, UIFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(title_label)
	var fill := ProgressBar.new()
	fill.show_percentage = false
	fill.max_value = 1.0
	fill.custom_minimum_size.y = 8
	fill.add_theme_stylebox_override("background", UIFactory.panel_style(Color("#090b13"), Color.TRANSPARENT, 0, 2))
	fill.add_theme_stylebox_override("fill", UIFactory.panel_style(color, color, 0, 2))
	stack.add_child(fill)
	panel.add_child(stack)
	panel.set_meta("fill", fill)
	panel.set_meta("title", title_label)
	return panel

func update_hud(player: RiftPlayer, rift_progress: float, rift_goal: float, boss: RiftEnemy = null, danger_info := "", buffs: Dictionary = {}) -> void:
	hp_bar.max_value = player.max_health
	hp_bar.value = maxf(player.health, 0.0)
	hp_text.text = "%d / %d" % [maxi(0, int(player.health)), int(player.max_health)]
	barrier_bar.max_value = maxf(player.max_barrier, 1.0)
	barrier_bar.value = player.barrier
	barrier_bar.visible = player.max_barrier > 0.0 or player.barrier > 0.0
	level_text.text = UIFactory.format("LV %d", [Game.current_run.level])
	var needed := xp_needed(Game.current_run.level)
	xp_bar.value = Game.current_run.xp / maxf(needed, 1.0)
	rift_bar.value = clampf(rift_progress / maxf(rift_goal, 1.0), 0.0, 1.0)
	timer_text.text = "%02d:%02d" % [int(Game.current_run.elapsed) / 60, int(Game.current_run.elapsed) % 60]
	tier_text.text = UIFactory.format("TIER %02d", [Game.current_run.tier])
	kill_text.text = UIFactory.format("%s KILLS  •  %s ELITES  •  %dG", [_compact(Game.current_run.kills), Game.current_run.elite_kills, Game.current_run.gold])
	danger_text.text = danger_info if not danger_info.is_empty() else UIFactory.localize("NO ELITE SIGNAL")
	var buff_lines: Array[String] = []
	for key in buffs: buff_lines.append(UIFactory.format("%s %ds", [UIFactory.localize(str(key).capitalize()), int(buffs[key])]))
	buff_text.text = "  •  ".join(buff_lines)
	fps_label.text = UIFactory.format("%d FPS  •  %s NODES", [Engine.get_frames_per_second(), _compact(get_tree().get_node_count())])
	var cooldowns := player.cooldown_ratios()
	for key in skill_fills: skill_fills[key].value = cooldowns.get(key, 1.0)
	var potion_title: Label = skill_titles.get("potion") as Label
	if is_instance_valid(potion_title): potion_title.text = UIFactory.format("POTION ×%d", [player.potion_charges])
	if is_instance_valid(boss) and boss.active:
		boss_panel.visible = true
		boss_bar.value = maxf(boss.health / boss.max_health, 0.0)
		boss_name.text = UIFactory.localize(boss.data.get("name", "RIFT GUARDIAN"))
		boss_phase.text = UIFactory.format("PHASE %s  •  %s", [_roman(maxi(1, boss.phase)), UIFactory.localize(boss.boss_modifier)])
	else:
		boss_panel.visible = false

func xp_needed(level: int) -> float:
	return 18.0 + pow(level, 1.34) * 9.0

func announce(text: String, color := Color.WHITE, seconds := 1.5) -> void:
	if is_instance_valid(announcement_tween): announcement_tween.kill()
	announcement.text = UIFactory.localize(text)
	announcement.add_theme_color_override("font_color", color)
	announcement.scale = Vector2(1.18, 1.18)
	announcement.modulate.a = 0.0
	announcement_tween = create_tween()
	announcement_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	announcement_tween.tween_property(announcement, "modulate:a", 1.0, 0.12)
	announcement_tween.parallel().tween_property(announcement, "scale", Vector2.ONE, 0.2)
	announcement_tween.tween_interval(seconds)
	announcement_tween.tween_property(announcement, "modulate:a", 0.0, 0.35)

func show_loot(item: Dictionary, equipped: Dictionary) -> void:
	latest_item = item
	# queue_free() is deferred. Calling it in a child-count while loop leaves the
	# count unchanged until frame end and used to lock the CPU on the fifth pickup.
	while toast_layer.get_child_count() >= MAX_LOOT_TOASTS:
		var oldest := toast_layer.get_child(0)
		toast_layer.remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 96)
	var color: Color = item.get("color", Color.WHITE)
	panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color(0.035, 0.045, 0.08, 0.94), color, 2 if item.get("rarity_index", 0) < 4 else 3, 6))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var name_label := UIFactory.label(Game.localized_item_name(item), 19, UIFactory.TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	var summary := "%s  •  %s %d  •  %s  •  %s" % [
		UIFactory.localize(str(item.get("rarity", "COMMON"))),
		UIFactory.localize("ITEM LEVEL"),
		int(item.get("item_level", 1)),
		Game.localized_item_slot(item),
		Game.localized_item_type(item)
	]
	var summary_label := UIFactory.label(summary, 13, color)
	summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(summary_label)
	var difference := Game.item_score(item, Game.build_tags()) - Game.item_score(equipped, Game.build_tags())
	var direction := "▲" if difference > 0.05 else ("▼" if difference < -0.05 else "—")
	var difference_text := "%+.0f" % difference if absf(difference) > 0.05 else "0"
	var compare_color := Color("#59e391") if difference > 0.05 else (Color("#f16975") if difference < -0.05 else UIFactory.MUTED)
	box.add_child(UIFactory.label("%s %s %s  •  F %s" % [UIFactory.localize("SCORE"), direction, difference_text, UIFactory.localize("EQUIP")], 13, compare_color))
	panel.add_child(box)
	toast_layer.add_child(panel)
	var tween := panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(3.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(panel.queue_free)

func _category_score(item: Dictionary, stats: Array) -> float:
	var score := 0.0
	for affix in item.get("affixes", []):
		if affix.get("stat", "") in stats: score += float(affix.get("value", 0.0))
	return score

func _synergy_score(item: Dictionary, tags: Dictionary) -> float:
	var score := 0.0
	for tag in item.get("tags", []): score += tags.get(tag, 0) * 10.0
	for tag in item.get("legendary", {}).get("tags", []): score += tags.get(tag, 0) * 18.0
	return score

func show_level_up(options: Array[Dictionary], rerolls: int) -> void:
	_close_overlay()
	overlay = _overlay_base()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1180, 700)
	box.add_theme_constant_override("separation", 18)
	box.add_child(UIFactory.heading("POWER SURGE", 58, UIFactory.CYAN))
	box.add_child(UIFactory.label("CHOOSE ONE — THE RIFT WAITS", 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	for index in options.size():
		var upgrade := options[index]
		var card := Button.new()
		card.custom_minimum_size = Vector2(350, 390)
		card.text = "%d\n\n%s\n\n%s\n\n[%s]" % [index + 1, UIFactory.localize(upgrade.name), UIFactory.localize(upgrade.description), UIFactory.localize(upgrade.tag)]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 22)
		card.pressed.connect(func(): upgrade_selected.emit(upgrade); _close_overlay())
		cards.add_child(card)
	box.add_child(cards)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 8)
	var reroll := UIFactory.button(UIFactory.format("REROLL (%d FATE / 100G)", [rerolls]), Vector2(340, 58))
	reroll.disabled = rerolls <= 0 and Game.current_run.gold < 100
	reroll.pressed.connect(func(): reroll_requested.emit())
	footer.add_child(reroll)
	box.add_child(footer)
	var control_row := HBoxContainer.new()
	control_row.alignment = BoxContainer.ALIGNMENT_CENTER
	control_row.add_theme_constant_override("separation", 7)
	for index in options.size():
		var banish := UIFactory.button(UIFactory.format("BANISH %d", [index + 1]), Vector2(125, 42))
		banish.add_theme_font_size_override("font_size", 14)
		banish.pressed.connect(func(): banish_requested.emit(options[index]))
		control_row.add_child(banish)
		var lock := UIFactory.button(UIFactory.format("LOCK %d", [index + 1]), Vector2(105, 42))
		lock.add_theme_font_size_override("font_size", 14)
		lock.pressed.connect(func(): lock_requested.emit(options[index]))
		control_row.add_child(lock)
		var favor := UIFactory.button(UIFactory.format("FAVOR %d", [index + 1]), Vector2(115, 42))
		favor.add_theme_font_size_override("font_size", 14)
		favor.pressed.connect(func(): favor_requested.emit(options[index].tag))
		control_row.add_child(favor)
	box.add_child(control_row)
	_add_overlay_panel(box)
	if cards.get_child_count() > 0: cards.get_child(0).grab_focus()

func show_pause() -> void:
	_close_overlay()
	overlay = _overlay_base()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 560)
	box.add_theme_constant_override("separation", 16)
	box.add_child(UIFactory.heading("RIFT PAUSED", 48, UIFactory.GOLD))
	var resume := UIFactory.button("RESUME")
	resume.pressed.connect(func(): _close_overlay(); interface_closed.emit())
	box.add_child(resume)
	var character := UIFactory.button("CHARACTER & LOOT")
	character.pressed.connect(show_character)
	box.add_child(character)
	var settings_button := UIFactory.button("SETTINGS & ACCESSIBILITY")
	settings_button.pressed.connect(show_ingame_settings)
	box.add_child(settings_button)
	var settings_note := UIFactory.label(UIFactory.format("Accessibility settings are available from the title screen.\nAttack %s  •  Potion %s  •  Barrier %s", [UIFactory.localize("AUTO") if Game.settings.auto_attack else UIFactory.localize("MANUAL"), UIFactory.localize("AUTO") if Game.settings.auto_potion else UIFactory.localize("MANUAL"), UIFactory.localize("AUTO") if Game.settings.auto_barrier else UIFactory.localize("MANUAL")]), 17, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(settings_note)
	var menu := UIFactory.button("ABANDON RIFT")
	menu.pressed.connect(func(): return_to_menu.emit())
	box.add_child(menu)
	_add_overlay_panel(box)
	resume.grab_focus()

func show_ingame_settings() -> void:
	_close_overlay()
	overlay = _overlay_base()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 690)
	box.add_theme_constant_override("separation", 12)
	box.add_child(UIFactory.heading("ACCESSIBILITY", 42, UIFactory.GOLD))
	var language_row := HBoxContainer.new()
	var language_title := UIFactory.label("LANGUAGE", 19, UIFactory.TEXT)
	language_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_row.add_child(language_title)
	var language_select := OptionButton.new()
	var locales := [["한국어", "ko"], ["English", "en"]]
	for index in locales.size():
		language_select.add_item(locales[index][0], index)
		if locales[index][1] == Game.settings.language: language_select.select(index)
	language_select.item_selected.connect(func(index: int):
		Game.settings.language = locales[index][1]
		TranslationServer.set_locale(Game.settings.language)
		call_deferred("show_ingame_settings")
	)
	language_row.add_child(language_select)
	box.add_child(language_row)
	for entry in [["AUTO ATTACK", "auto_attack"], ["AUTO POTION  •  HP ≤ 35%  •  BARRIER INDEPENDENT", "auto_potion"], ["AUTO BARRIER  •  LOW / EMPTY", "auto_barrier"], ["GAMEPAD VIBRATION", "gamepad_vibration"]]:
		var row := HBoxContainer.new()
		var title := UIFactory.label(entry[0], 19, UIFactory.TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var toggle := CheckButton.new()
		toggle.button_pressed = bool(Game.settings[entry[1]])
		toggle.toggled.connect(func(value: bool): Game.settings[entry[1]] = value)
		row.add_child(toggle)
		box.add_child(row)
	for entry in [["MASTER VOLUME", "master_volume"], ["SCREEN SHAKE", "screen_shake"], ["FLASH INTENSITY", "flash_intensity"], ["DAMAGE NUMBERS", "damage_numbers"]]:
		var row := HBoxContainer.new()
		var title := UIFactory.label(entry[0], 19, UIFactory.TEXT)
		title.custom_minimum_size.x = 250
		row.add_child(title)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Game.settings[entry[1]])
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value: float): Game.settings[entry[1]] = value; AudioManager.apply_volumes())
		row.add_child(slider)
		box.add_child(row)
	var back := UIFactory.button("SAVE & BACK")
	back.pressed.connect(func(): Game.apply_settings(); SaveManager.save_game(); show_pause())
	box.add_child(back)
	_add_overlay_panel(box)

func show_character() -> void:
	_close_overlay()
	overlay = _overlay_base()
	var content := HBoxContainer.new()
	content.custom_minimum_size = Vector2(1500, 860)
	content.add_theme_constant_override("separation", 20)
	var equipment_box := VBoxContainer.new()
	equipment_box.custom_minimum_size.x = 610
	equipment_box.add_child(UIFactory.heading("THE HUNTER", 42, UIFactory.GOLD))
	var tags := Game.build_tags()
	var tag_keys := tags.keys()
	tag_keys.sort_custom(func(a, b): return tags[a] > tags[b])
	var signature: Array[String] = []
	for i in mini(4, tag_keys.size()): signature.append("%s %d" % [UIFactory.localize(str(tag_keys[i])), tags[tag_keys[i]]])
	equipment_box.add_child(UIFactory.label(UIFactory.format("BUILD: %s", ["  /  ".join(signature)]), 18, UIFactory.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	for slot in Game.SLOTS:
		var item: Dictionary = Game.equipment.get(slot, {})
		var row := PanelContainer.new()
		var row_box := HBoxContainer.new()
		var slot_label := UIFactory.label(UIFactory.localize(slot.replace("_", " ").to_upper()), 16, UIFactory.MUTED)
		slot_label.custom_minimum_size.x = 110
		row_box.add_child(slot_label)
		var item_color := DataRegistry.rarity_color(item.get("rarity", "Common")) if not item.is_empty() else Color("#65728a")
		var equipped_text := "%s\n%s" % [Game.localized_item_name(item), Game.localized_item_type(item)] if not item.is_empty() else "— EMPTY —"
		var item_label := UIFactory.label(equipped_text, 18, item_color)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(item_label)
		row_box.add_child(UIFactory.label("%.0f" % Game.item_score(item, tags), 18, UIFactory.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		row.add_child(row_box)
		equipment_box.add_child(row)
	content.add_child(equipment_box)
	var inventory_box := VBoxContainer.new()
	inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_box.add_child(UIFactory.heading("RECENT LOOT", 42, UIFactory.TEXT))
	inventory_box.add_child(UIFactory.label("Build-aware score compares tags, affixes, and legendary synergy.", 17, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var tools := HBoxContainer.new()
	tools.add_child(UIFactory.label("FILTER", 15, UIFactory.MUTED))
	var filter_select := OptionButton.new()
	var filter_values := ["ALL", "RARE+", "LEGENDARY+", "BUILD TAGS"]
	for value in filter_values: filter_select.add_item(UIFactory.localize(value))
	filter_select.select(maxi(0, filter_values.find(inventory_filter)))
	filter_select.item_selected.connect(func(index: int): inventory_filter = filter_values[index]; show_character())
	tools.add_child(filter_select)
	tools.add_child(UIFactory.label("SORT", 15, UIFactory.MUTED))
	var sort_select := OptionButton.new()
	var sort_values := ["BUILD SCORE", "RARITY", "ITEM LEVEL"]
	for value in sort_values: sort_select.add_item(UIFactory.localize(value))
	sort_select.select(maxi(0, sort_values.find(inventory_sort)))
	sort_select.item_selected.connect(func(index: int): inventory_sort = sort_values[index]; show_character())
	tools.add_child(sort_select)
	var salvage_low := UIFactory.button("SALVAGE LOW", Vector2(155, 44))
	salvage_low.add_theme_font_size_override("font_size", 15)
	salvage_low.pressed.connect(func(): Game.auto_salvage(); show_character())
	tools.add_child(salvage_low)
	inventory_box.add_child(tools)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in _filtered_inventory(tags).slice(0, 30):
		list.add_child(_inventory_row(item, tags))
	if Game.inventory.is_empty(): list.add_child(UIFactory.label("No loot carried. The rift is hungry.", 21, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	scroll.add_child(list)
	inventory_box.add_child(scroll)
	var close := UIFactory.button("CLOSE [TAB]", Vector2(280, 58))
	close.pressed.connect(func(): _close_overlay(); interface_closed.emit())
	inventory_box.add_child(close)
	content.add_child(inventory_box)
	_add_overlay_panel(content)

func _inventory_row(item: Dictionary, tags: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var color: Color = item.get("color", Color.WHITE)
	panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("#0d1424"), color.darkened(0.3), 2, 6))
	var item_box := VBoxContainer.new()
	item_box.add_theme_constant_override("separation", 8)
	item_box.add_child(UIFactory.label(Game.localized_item_name(item), 20, color))
	var details: Array[String] = [UIFactory.format("%s  •  ILVL %d  •  SCORE %.0f", [UIFactory.localize(item.rarity), item.item_level, Game.item_score(item, tags)])]
	details.append_array(_item_detail_lines(item))
	var text := UIFactory.label("\n".join(details), 15, UIFactory.MUTED)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 480
	text.custom_minimum_size.y = details.size() * 20
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	item_box.add_child(text)
	item_box.add_child(_item_comparison_panel(item, tags))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 6)
	var equip := UIFactory.button("EQUIP", Vector2(120, 52))
	equip.pressed.connect(func(): Game.equip_item(item); show_character())
	actions.add_child(equip)
	var favorite := UIFactory.button("★" if item.get("favorite", false) else "☆", Vector2(58, 52))
	favorite.pressed.connect(func(): item.favorite = not item.get("favorite", false); Game.inventory_changed.emit(); show_character())
	actions.add_child(favorite)
	var salvage := UIFactory.button("SALVAGE", Vector2(140, 52))
	salvage.disabled = item.get("favorite", false)
	salvage.pressed.connect(func(): Game.salvage_item(item); show_character())
	actions.add_child(salvage)
	item_box.add_child(actions)
	panel.add_child(item_box)
	return panel

func _item_comparison_panel(item: Dictionary, current_tags: Dictionary) -> PanelContainer:
	var target_slot := Game.equipment_slot_for_item(item)
	var equipped: Dictionary = Game.equipment.get(target_slot, {})
	var comparison_tags := _tags_without_item(current_tags, equipped)
	var candidate_score := Game.item_score(item, comparison_tags)
	var equipped_score := Game.item_score(equipped, comparison_tags)
	var metrics := [
		["SCORE", candidate_score - equipped_score],
		["OFFENSE", _offense_score(item) - _offense_score(equipped)],
		["TOUGHNESS", _category_score(item, TOUGHNESS_STATS) - _category_score(equipped, TOUGHNESS_STATS)],
		["SYNERGY", _synergy_score(item, comparison_tags) - _synergy_score(equipped, comparison_tags)]
	]
	var comparison_panel := PanelContainer.new()
	comparison_panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color("#0a1120"), Color("#2d4468"), 1, 5))
	var comparison_box := VBoxContainer.new()
	comparison_box.add_theme_constant_override("separation", 5)
	var slot_name := UIFactory.localize(target_slot.replace("_", " ").to_upper())
	var equipped_name := UIFactory.localize("EMPTY SLOT") if equipped.is_empty() else Game.localized_item_name(equipped)
	comparison_box.add_child(UIFactory.label(UIFactory.format("COMPARED TO: %s  •  %s", [slot_name, equipped_name]), 14, UIFactory.TEXT))
	var metric_row := HFlowContainer.new()
	metric_row.add_theme_constant_override("h_separation", 12)
	metric_row.add_theme_constant_override("v_separation", 4)
	for metric in metrics:
		var value: float = metric[1]
		var direction := "▲" if value > 0.05 else ("▼" if value < -0.05 else "—")
		var metric_color := Color("#59e391") if value > 0.05 else (Color("#f16975") if value < -0.05 else UIFactory.MUTED)
		var metric_label := UIFactory.label("%s %s %+.0f" % [UIFactory.localize(str(metric[0])), direction, value], 14, metric_color)
		metric_label.custom_minimum_size.x = 108
		metric_row.add_child(metric_label)
	comparison_box.add_child(metric_row)
	comparison_panel.add_child(comparison_box)
	return comparison_panel

func _tags_without_item(current_tags: Dictionary, item: Dictionary) -> Dictionary:
	var remaining: Dictionary = current_tags.duplicate()
	for tag in item.get("tags", []):
		remaining[tag] = maxi(0, int(remaining.get(tag, 0)) - 1)
	var legendary: Dictionary = item.get("legendary", {})
	for tag in legendary.get("tags", []):
		remaining[tag] = maxi(0, int(remaining.get(tag, 0)) - 2)
	return remaining

func _offense_score(item: Dictionary) -> float:
	var score := float(item.get("base_power", 0.0)) if item.get("slot", "") == "weapon" else 0.0
	return score + _category_score(item, OFFENSE_STATS)

func _item_detail_lines(item: Dictionary, affix_limit := -1, include_usage := true) -> Array[String]:
	var lines: Array[String] = []
	lines.append(UIFactory.format("EQUIP SLOT: %s  •  ITEM TYPE: %s", [Game.localized_item_slot(item), Game.localized_item_type(item)]))
	if include_usage: lines.append(Game.localized_item_usage(item))
	var tags := Game.localized_item_tags(item)
	var rating_source := "WEAPON POWER %.1f  •  BUILD TAGS: %s" if item.get("slot", "") == "weapon" else "BASE RATING %.1f  •  BUILD TAGS: %s"
	lines.append(UIFactory.format(rating_source, [float(item.get("base_power", 0.0)), tags if not tags.is_empty() else UIFactory.localize("NONE")]))
	var affixes: Array = item.get("affixes", [])
	var visible_count := affixes.size() if affix_limit < 0 else mini(affix_limit, affixes.size())
	for index in visible_count: lines.append("• " + Game.localized_affix_description(affixes[index]))
	if visible_count < affixes.size():
		lines.append(UIFactory.format("+%d MORE AFFIXES", [affixes.size() - visible_count]))
	var legendary: Dictionary = item.get("legendary", {})
	if not legendary.is_empty():
		lines.append(UIFactory.format("◆ LEGENDARY POWER: %s", [UIFactory.localize(str(legendary.get("description", "")))]))
	return lines

func _filtered_inventory(tags: Dictionary) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for item in Game.inventory:
		var include := inventory_filter == "ALL"
		if inventory_filter == "RARE+": include = item.get("rarity_index", 0) >= 2
		elif inventory_filter == "LEGENDARY+": include = item.get("rarity_index", 0) >= 4
		elif inventory_filter == "BUILD TAGS":
			include = false
			for tag in item.get("tags", []):
				if tags.get(tag, 0) > 0: include = true
		if include: output.append(item)
	match inventory_sort:
		"RARITY": output.sort_custom(func(a, b): return a.get("rarity_index", 0) > b.get("rarity_index", 0))
		"ITEM LEVEL": output.sort_custom(func(a, b): return a.get("item_level", 0) > b.get("item_level", 0))
		_: output.sort_custom(func(a, b): return Game.item_score(a, tags) > Game.item_score(b, tags))
	return output

func has_overlay() -> bool:
	return is_instance_valid(overlay)

func close_interface() -> void:
	_close_overlay()
	interface_closed.emit()

func _overlay_base() -> Control:
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UIFactory.game_theme()
	var shade := ColorRect.new()
	shade.color = Color(0.006, 0.008, 0.02, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	add_child(root)
	return root

func _add_overlay_panel(content: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color(0.035, 0.05, 0.095, 0.98), Color("#53658e"), 2, 10))
	panel.add_child(UIFactory.margin(content, 28))
	center.add_child(panel)
	overlay.add_child(center)

func _close_overlay() -> void:
	if is_instance_valid(overlay): overlay.queue_free()
	overlay = null

func _compact(value: float) -> String:
	if value >= 1000000.0: return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0: return "%.1fK" % (value / 1000.0)
	return str(int(value))

func _roman(value: int) -> String:
	return ["I", "II", "III", "IV"][clampi(value - 1, 0, 3)]
