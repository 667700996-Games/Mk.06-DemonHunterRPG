class_name RiftHUD
extends CanvasLayer

signal upgrade_selected(upgrade: Dictionary)
signal reroll_requested
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
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name: Label
var boss_phase: Label
var skill_fills: Dictionary = {}
var toast_layer: VBoxContainer
var announcement: Label
var announcement_tween: Tween
var overlay: Control
var latest_item: Dictionary = {}
var fps_label: Label

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

	var vitals := PanelContainer.new()
	vitals.custom_minimum_size = Vector2(430, 130)
	var vital_box := VBoxContainer.new()
	var name_row := HBoxContainer.new()
	name_row.add_child(UIFactory.heading("THE LAST HUNTER", 22, UIFactory.TEXT))
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
	vitals.add_child(vital_box)
	top.add_child(vitals)

	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 130
	var center_box := VBoxContainer.new()
	var rift_row := HBoxContainer.new()
	rift_row.add_child(UIFactory.label("GREATER RIFT", 18, UIFactory.MUTED))
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
	center.add_child(center_box)
	top.add_child(center)

	var status := PanelContainer.new()
	status.custom_minimum_size = Vector2(330, 130)
	var status_box := VBoxContainer.new()
	tier_text = UIFactory.heading("TIER 01", 27, UIFactory.GOLD)
	status_box.add_child(tier_text)
	kill_text = UIFactory.label("0 KILLS  •  0 ELITES", 18, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	status_box.add_child(kill_text)
	fps_label = UIFactory.label("", 15, Color("#6f829f"), HORIZONTAL_ALIGNMENT_CENTER)
	status_box.add_child(fps_label)
	status.add_child(status_box)
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
		["secondary", "RMB", "NOVA", Color("#ff4f76")], ["q", "Q", "METEOR", Color("#ff7b35")],
		["e", "E", "AEGIS", Color("#55d9ff")], ["dash", "SPACE", "DASH", Color("#a26cff")],
		["r", "R", "RIFTFALL", Color("#ffd166")]
	]
	for skill in skills:
		var cell := _skill_cell(skill[1], skill[2], skill[3])
		skill_fills[skill[0]] = cell.get_meta("fill")
		bottom.add_child(cell)
	root.add_child(bottom)

	toast_layer = VBoxContainer.new()
	toast_layer.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	toast_layer.position = Vector2(-430, -120)
	toast_layer.custom_minimum_size = Vector2(395, 480)
	toast_layer.alignment = BoxContainer.ALIGNMENT_END
	toast_layer.add_theme_constant_override("separation", 8)
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
	stack.add_child(UIFactory.label(title, 17, UIFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var fill := ProgressBar.new()
	fill.show_percentage = false
	fill.max_value = 1.0
	fill.custom_minimum_size.y = 8
	fill.add_theme_stylebox_override("background", UIFactory.panel_style(Color("#090b13"), Color.TRANSPARENT, 0, 2))
	fill.add_theme_stylebox_override("fill", UIFactory.panel_style(color, color, 0, 2))
	stack.add_child(fill)
	panel.add_child(stack)
	panel.set_meta("fill", fill)
	return panel

func update_hud(player: RiftPlayer, rift_progress: float, rift_goal: float, boss: RiftEnemy = null) -> void:
	hp_bar.max_value = player.max_health
	hp_bar.value = maxf(player.health, 0.0)
	hp_text.text = "%d / %d" % [maxi(0, int(player.health)), int(player.max_health)]
	barrier_bar.max_value = maxf(player.max_barrier, 1.0)
	barrier_bar.value = player.barrier
	barrier_bar.visible = player.max_barrier > 0.0 or player.barrier > 0.0
	level_text.text = "LV %d" % Game.current_run.level
	var needed := xp_needed(Game.current_run.level)
	xp_bar.value = Game.current_run.xp / maxf(needed, 1.0)
	rift_bar.value = clampf(rift_progress / maxf(rift_goal, 1.0), 0.0, 1.0)
	timer_text.text = "%02d:%02d" % [int(Game.current_run.elapsed) / 60, int(Game.current_run.elapsed) % 60]
	tier_text.text = "TIER %02d" % Game.current_run.tier
	kill_text.text = "%s KILLS  •  %s ELITES" % [_compact(Game.current_run.kills), Game.current_run.elite_kills]
	fps_label.text = "%d FPS  •  %s ACTIVE" % [Engine.get_frames_per_second(), _compact(get_tree().get_node_count())]
	var cooldowns := player.cooldown_ratios()
	for key in skill_fills: skill_fills[key].value = cooldowns.get(key, 1.0)
	if is_instance_valid(boss) and boss.active:
		boss_panel.visible = true
		boss_bar.value = maxf(boss.health / boss.max_health, 0.0)
		boss_name.text = boss.data.get("name", "RIFT GUARDIAN").to_upper()
		boss_phase.text = "PHASE %s" % _roman(maxi(1, boss.phase))
	else:
		boss_panel.visible = false

func xp_needed(level: int) -> float:
	return 18.0 + pow(level, 1.34) * 9.0

func announce(text: String, color := Color.WHITE, seconds := 1.5) -> void:
	if is_instance_valid(announcement_tween): announcement_tween.kill()
	announcement.text = text
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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 116)
	var color: Color = item.get("color", Color.WHITE)
	panel.add_theme_stylebox_override("panel", UIFactory.panel_style(Color(0.035, 0.045, 0.08, 0.96), color, 2 if item.rarity_index < 4 else 4, 7))
	var box := VBoxContainer.new()
	box.add_child(UIFactory.label("%s  •  ITEM LEVEL %d" % [item.rarity.to_upper(), item.item_level], 15, color))
	box.add_child(UIFactory.label(item.name, 22, UIFactory.TEXT))
	var difference := Game.item_score(item, Game.build_tags()) - Game.item_score(equipped, Game.build_tags())
	var compare_color := Color("#59e391") if difference >= 0.0 else Color("#f16975")
	box.add_child(UIFactory.label("%+.0f BUILD POWER   •   F QUICK EQUIP" % difference, 16, compare_color))
	panel.add_child(box)
	toast_layer.add_child(panel)
	while toast_layer.get_child_count() > 4: toast_layer.get_child(0).queue_free()
	var tween := panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(4.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)

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
		card.text = "%d\n\n%s\n\n%s\n\n[%s]" % [index + 1, upgrade.name.to_upper(), upgrade.description, upgrade.tag.to_upper()]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 22)
		card.pressed.connect(func(): upgrade_selected.emit(upgrade); _close_overlay())
		cards.add_child(card)
	box.add_child(cards)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	var reroll := UIFactory.button("REROLL (%d)" % rerolls, Vector2(300, 58))
	reroll.disabled = rerolls <= 0
	reroll.pressed.connect(func(): reroll_requested.emit())
	footer.add_child(reroll)
	box.add_child(footer)
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
	var settings_note := UIFactory.label("Accessibility settings are available from the title screen.\nAuto-attack: %s  •  Screen shake: %d%%" % ["ON" if Game.settings.auto_attack else "OFF", int(Game.settings.screen_shake * 100)], 17, UIFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(settings_note)
	var menu := UIFactory.button("ABANDON RIFT")
	menu.pressed.connect(func(): return_to_menu.emit())
	box.add_child(menu)
	_add_overlay_panel(box)
	resume.grab_focus()

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
	for i in mini(4, tag_keys.size()): signature.append("%s %d" % [str(tag_keys[i]).to_upper(), tags[tag_keys[i]]])
	equipment_box.add_child(UIFactory.label("BUILD: " + "  /  ".join(signature), 18, UIFactory.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	for slot in Game.SLOTS:
		var item: Dictionary = Game.equipment.get(slot, {})
		var row := PanelContainer.new()
		var row_box := HBoxContainer.new()
		var slot_label := UIFactory.label(slot.replace("_", " ").to_upper(), 16, UIFactory.MUTED)
		slot_label.custom_minimum_size.x = 110
		row_box.add_child(slot_label)
		var item_label := UIFactory.label(item.get("name", "— EMPTY —"), 18, item.get("color", Color("#65728a")))
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
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in Game.inventory.slice(0, 24):
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
	var row := HBoxContainer.new()
	var text := UIFactory.label("%s\n%s  •  ILVL %d  •  SCORE %.0f" % [item.name, item.rarity, item.item_level, Game.item_score(item, tags)], 17, color)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var equip := UIFactory.button("EQUIP", Vector2(120, 52))
	equip.pressed.connect(func(): Game.equip_item(item); show_character())
	row.add_child(equip)
	var salvage := UIFactory.button("SALVAGE", Vector2(140, 52))
	salvage.disabled = item.get("favorite", false)
	salvage.pressed.connect(func(): Game.salvage_item(item); show_character())
	row.add_child(salvage)
	panel.add_child(row)
	return panel

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
