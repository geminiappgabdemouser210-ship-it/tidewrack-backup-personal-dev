extends SceneTree
## Headless regression checks for the save schema and journal compatibility.


func _init() -> void:
	call_deferred("_run")


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
	assert(game_state.save_game())

	game_state.new_game()
	assert(game_state.load_game())
	assert(game_state.current_scene == "res://scenes/lamp_room.tscn")
	assert(game_state.get_flag("skeptic") == true)
	assert(game_state.get_flag("trusted_edith") == false)
	assert(journal.entries() == ["ediths_last_log", "radio_transcript"])

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
	assert(game_state.load_game())
	assert(game_state.get_flag("believer") == true)
	assert(game_state.get_flag("radioed_tom") == true)
	assert(journal.entries().is_empty())

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
	assert(game_state.load_game())
	assert(game_state.current_scene == "res://scenes/lamp_room.tscn")
	assert(game_state.get_flag("skeptic") == true)
	assert(journal.entries().is_empty())

	# Invalid array values are filtered while valid IDs retain first-seen order.
	var mixed_entries := FileAccess.open("user://save.json", FileAccess.WRITE)
	mixed_entries.store_string(JSON.stringify({
		"version": 1,
		"scene": "res://scenes/game.tscn",
		"flags": {"believer": true},
		"journal": ["", "ediths_last_log", 42, "ediths_last_log", "  radio_transcript  "],
	}))
	mixed_entries.close()
	assert(game_state.load_game())
	assert(game_state.get_flag("believer") == true)
	assert(journal.entries() == ["ediths_last_log", "radio_transcript"])

	# Discovery is idempotent, and New Game clears only the in-memory state.
	journal.discover("ediths_last_log")
	journal.discover("ediths_last_log")
	assert(journal.entries() == ["ediths_last_log", "radio_transcript"])
	game_state.new_game()
	assert(journal.entries().is_empty())
	assert(game_state.has_save())

	game_state.delete_save()
	print("save-state regression checks passed")
	quit()
