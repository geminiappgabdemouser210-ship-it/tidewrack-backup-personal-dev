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

	# A second successful write preserves the prior complete save as recovery
	# data. A damaged primary file should Continue from that recovery copy.
	game_state.set_flag("radioed_tom", true)
	journal.discover("newer_entry")
	assert(game_state.save_game())
	var damaged := FileAccess.open("user://save.json", FileAccess.WRITE)
	damaged.store_string("not json")
	damaged.close()
	game_state.new_game()
	assert(game_state.load_game())
	assert(game_state.get_flag("skeptic") == true)
	assert(game_state.get_flag("radioed_tom", false) == false)
	assert(journal.entries() == ["ediths_last_log", "radio_transcript"])

	# v1 saves did not have a journal key. They must still load their flags and
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

	game_state.delete_save()
	print("save-state regression checks passed")
	quit()
