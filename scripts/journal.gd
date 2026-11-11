extends Node
## Journal — discovered-log state.
##
## Autoloaded as `Journal`. GameState owns the on-disk save; this node keeps
## the journal's in-memory state and exposes a deliberately small persistence
## boundary for it. Reader UI can consume entries() without owning save logic.

signal entry_added(id: String)

var _entries: Array[String] = []


func discover(id: String) -> void:
	if id.is_empty():
		push_warning("Journal: ignoring an empty entry id.")
		return
	if id in _entries:
		return
	_entries.append(id)
	entry_added.emit(id)


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


func reset() -> void:
	_entries.clear()


## Returns only JSON-safe data for GameState's save payload.
func save_data() -> Array[String]:
	return entries()


## Restores a save payload defensively. Invalid values are ignored rather than
## poisoning the journal or preventing the rest of a valid save from loading.
func load_data(value: Variant) -> void:
	_entries.clear()
	if typeof(value) != TYPE_ARRAY:
		return
	for raw_id in value:
		if typeof(raw_id) != TYPE_STRING:
			continue
		var id := (raw_id as String).strip_edges()
		if not id.is_empty() and not id in _entries:
			_entries.append(id)
