extends Node
## Journal – discovered-logs system.
##
## Autoloaded as `Journal`. As the player examines objects, the dialogue
## "set_flag" hooks record discovered entries here; GameState persists them
## in user://save.json and the journal screen renders them.

signal entry_added(id: String)
signal journal_loaded

var _entries: Array[String] = []


func discover(id: String) -> void:
	var clean_id := id.strip_edges()
	if clean_id.is_empty() or clean_id in _entries:
		return
	_entries.append(clean_id)
	entry_added.emit(clean_id)


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


func clear() -> void:
	_entries.clear()
	journal_loaded.emit()


func serialize() -> Array[String]:
	return _entries.duplicate()


func deserialize(raw: Variant) -> void:
	_entries.clear()
	if typeof(raw) == TYPE_ARRAY:
		for item: Variant in raw:
			if typeof(item) == TYPE_STRING:
				var clean_id := (item as String).strip_edges()
				if not clean_id.is_empty() and clean_id not in _entries:
					_entries.append(clean_id)
	journal_loaded.emit()
