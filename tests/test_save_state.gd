extends SceneTree
## Headless regression checks for the save schema and journal compatibility.

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, case_name: String) -> void:
	if not condition:
		_failures.append(case_name)


func _finish() -> void:
	if _failures.is_empty():
		print("save-state regression checks passed")
		quit(0)
		return
	printerr("save-state regression checks failed (%d):" % _failures.size())
	for case_name in _failures:
		printerr("  FAIL: %s" % case_name)
	quit(1)


func _run() -> void:
	# Autoload names are available dynamically when this file is launched with
	# `-s`, even though standalone test scripts cannot resolve them statically.
	var game_state: Variant = root.get_node("GameState")
	var journal: Variant = root.get_node("Journal")
	game_state.delete_save()
	game_state.new_game()
	game_state.current_scene = "res://scenes/lamp_room.tscn"
	game_state.set_flag("skeptic", true)
	game_state.set_flag("trusted_edith", false)
	journal.discover("ediths_last_log")
	journal.discover("radio_transcript")
	_check(game_state.save_game(), "round-trip: save succeeds")

	game_state.new_game()
	_check(game_state.load_game(), "round-trip: load succeeds")
	_check(game_state.current_scene == "res://scenes/lamp_room.tscn", "round-trip: restores scene")
	_check(game_state.get_flag("skeptic") == true, "round-trip: restores skeptic flag")
	_check(game_state.get_flag("trusted_edith") == false, "round-trip: restores trusted_edith flag")
	_check(journal.entries() == ["ediths_last_log", "radio_transcript"], "round-trip: restores journal entries")

	# Existing saves did not have a journal key. They must still load their flags and
	# begin with an empty journal instead of inheriting the previous session.
	game_state.delete_save()
	var legacy := FileAccess.open("user://save.json", FileAccess.WRITE)
	legacy.store_string(JSON.stringify({
		"version": 1,
		"scene": "res://scenes/game.tscn",
		"flags": {"believer": true, "radioed_tom": true},
	}))
	legacy.close()
	journal.discover("stale_entry")
	_check(game_state.load_game(), "older save: load succeeds")
	_check(game_state.get_flag("believer") == true, "older save: restores believer flag")
	_check(game_state.get_flag("radioed_tom") == true, "older save: restores radioed_tom flag")
	_check(journal.entries().is_empty(), "older save: starts with an empty journal")

	# An invalid journal field is contained without discarding valid game state.
	var malformed := FileAccess.open("user://save.json", FileAccess.WRITE)
	malformed.store_string(JSON.stringify({
		"version": 1,
		"scene": "res://scenes/lamp_room.tscn",
		"flags": {"skeptic": true},
		"journal": "not-a-list",
	}))
	malformed.close()
	journal.discover("stale_entry")
	_check(game_state.load_game(), "malformed journal: load succeeds")
	_check(game_state.current_scene == "res://scenes/lamp_room.tscn", "malformed journal: restores scene")
	_check(game_state.get_flag("skeptic") == true, "malformed journal: restores flags")
	_check(journal.entries().is_empty(), "malformed journal: clears stale entries")

	# Invalid array values are filtered while valid IDs retain first-seen order.
	var mixed_entries := FileAccess.open("user://save.json", FileAccess.WRITE)
	mixed_entries.store_string(JSON.stringify({
		"version": 1,
		"scene": "res://scenes/game.tscn",
		"flags": {"believer": true},
		"journal": ["", "ediths_last_log", 42, "ediths_last_log", "  radio_transcript  "],
	}))
	mixed_entries.close()
	_check(game_state.load_game(), "invalid entries: load succeeds")
	_check(game_state.get_flag("believer") == true, "invalid entries: restores flags")
	_check(journal.entries() == ["ediths_last_log", "radio_transcript"], "invalid entries: filters and de-duplicates IDs")

	# Discovery is idempotent, and New Game clears only the in-memory state.
	journal.discover("ediths_last_log")
	journal.discover("ediths_last_log")
	_check(journal.entries() == ["ediths_last_log", "radio_transcript"], "duplicate discovery: keeps one copy")
	game_state.new_game()
	_check(journal.entries().is_empty(), "new game: clears journal state")
	_check(game_state.has_save(), "new game: preserves existing save slot")

	game_state.delete_save()
	_finish()
