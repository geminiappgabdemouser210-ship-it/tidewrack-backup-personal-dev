extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and persists them to user://save.json so "Continue" works.

signal state_changed

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.backup.json"
const TEMP_PATH := "user://save.tmp.json"
const SAVE_VERSION := 2
const DEFAULT_SCENE := "res://scenes/game.tscn"

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = DEFAULT_SCENE


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func new_game() -> void:
	flags.clear()
	current_scene = DEFAULT_SCENE
	Journal.reset()
	state_changed.emit()


func has_save() -> bool:
	# A verified previous save is still usable if a write was interrupted.
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal": Journal.save_data(),
	}
	if not _write_payload(TEMP_PATH, payload):
		return false

	# Keep the last complete save until the new file has been fully written. If
	# replacing the primary file fails, restore it so Continue remains usable.
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error := DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
		if backup_error != OK:
			push_error("GameState: could not preserve the previous save.")
			DirAccess.remove_absolute(TEMP_PATH)
			return false
	var replace_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if replace_error != OK:
		push_error("GameState: could not replace save file.")
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(BACKUP_PATH, SAVE_PATH)
		return false
	return true


func _write_payload(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("GameState: could not finish writing save file.")
		DirAccess.remove_absolute(path)
		return false
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var raw_data: Variant = _read_save(SAVE_PATH)
	if typeof(raw_data) != TYPE_DICTIONARY and FileAccess.file_exists(BACKUP_PATH):
		push_warning("GameState: primary save is unreadable; loading previous save.")
		raw_data = _read_save(BACKUP_PATH)
	if typeof(raw_data) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false
	var data: Dictionary = raw_data

	# Saves created before v2 omit journal data. Their scene and story flags use
	# the original field names and are restored unchanged.
	var loaded_scene: Variant = data.get("scene", DEFAULT_SCENE)
	current_scene = loaded_scene if typeof(loaded_scene) == TYPE_STRING and not (loaded_scene as String).is_empty() else DEFAULT_SCENE
	var loaded_flags: Variant = data.get("flags", {})
	flags = (loaded_flags as Dictionary).duplicate(true) if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	Journal.load_data(data.get("journal", data.get("journal_entries", [])))
	state_changed.emit()
	return true


func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
