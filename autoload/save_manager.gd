extends Node

const SAVE_PATH := "user://riftfall_save.json"
const TEMP_PATH := "user://riftfall_save.tmp"
const BACKUP_PATH := "user://riftfall_save.backup.json"

var last_error := ""

func load_game() -> bool:
	var data := _read_json(SAVE_PATH)
	if data.is_empty(): data = _read_json(BACKUP_PATH)
	if data.is_empty(): return false
	Game.hydrate(data)
	return true

func save_game() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		last_error = "Unable to open temporary save file: %s" % FileAccess.get_open_error()
		push_error(last_error)
		return false
	file.store_string(JSON.stringify(Game.serialize(), "  "))
	file.flush()
	file.close()
	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
	var absolute_backup := ProjectSettings.globalize_path(BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(absolute_save, absolute_backup)
		DirAccess.remove_absolute(absolute_save)
	var result := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if result != OK:
		last_error = "Atomic save rename failed: %s" % error_string(result)
		push_error(last_error)
		return false
	last_error = ""
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Ignoring corrupt RIFTFALL save at %s" % path)
		return {}
	return parsed

