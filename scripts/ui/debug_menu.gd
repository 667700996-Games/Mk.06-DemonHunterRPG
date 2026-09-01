class_name RiftDebugMenu
extends CanvasLayer

signal command_requested(command: String)

var panel: PanelContainer
var perf: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIFactory.game_theme()
	add_child(root)
	panel = PanelContainer.new()
	panel.position = Vector2(24, 205)
	panel.custom_minimum_size = Vector2(300, 690)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.add_child(UIFactory.heading("DEV HUNT KIT", 25, UIFactory.GOLD))
	var commands := [
		["god", "TOGGLE GOD MODE"], ["enemy", "SPAWN ENEMY"], ["elite", "SPAWN ELITE"],
		["boss", "SPAWN BOSS"], ["item", "SPAWN ITEM"], ["xp", "ADD XP"],
		["gold", "ADD GOLD"], ["tier", "TIER +1"], ["kill_all", "KILL ALL"],
		["stress", "SPAWN 250 STRESS"]
	]
	for entry in commands:
		var button := UIFactory.button(entry[1], Vector2(260, 43))
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(func(): command_requested.emit(entry[0]))
		box.add_child(button)
	perf = UIFactory.label("", 15, UIFactory.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(perf)
	panel.add_child(UIFactory.margin(box, 14))
	root.add_child(panel)
	visible = false

func _process(_delta: float) -> void:
	if not visible: return
	perf.text = "%d FPS\nNODES %d\nOBJECTS %d" % [Engine.get_frames_per_second(), get_tree().get_node_count(), Performance.get_monitor(Performance.OBJECT_COUNT)]

func toggle() -> void:
	visible = not visible

