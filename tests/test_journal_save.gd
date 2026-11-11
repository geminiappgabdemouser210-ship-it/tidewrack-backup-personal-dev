extends SceneTree
## Headless regression test for Journal + GameState save/Continue persistence.
## Run: godot --headless -s res://tests/test_journal_save.gd

var _failures: int = 0
var _entry_added_count: int = 0
var _journal_loaded_count: int = 0


func _initialize() -> void:
	var backup_exists := FileAccess.file_exists(GameState.SAVE_PATH)
	var backup_text := ""
	if backup_exists:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
		if f != null:
			backup_text = f.get_as_text()
			f.close()

	Journal.entry_added.connect(_on_entry_added)
	Journal.journal_loaded.connect(_on_journal_loaded)

	_test_save_and_continue()
	_test_v1_save_without_journal()
	_test_new_game_resets_journal()
	_test_toast_suppression_on_load()
	_test_corrupt_and_non_dict_saves()
	_test_sanitization_and_deserialization()
	_test_malformed_journal_field_in_valid_save()
	_test_duplicate_entry_discovery()

	# Restore any pre-existing save.json and reset in-memory state.
	GameState.new_game()
	if backup_exists:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(backup_text)
			f.close()
	else:
		GameState.delete_save()

	if _failures == 0:
		print("ALL JOURNAL/SAVE TESTS PASSED")
		quit(0)
	else:
		push_error("%d journal/save test assertion(s) failed." % _failures)
		quit(1)


func _on_entry_added(_id: String) -> void:
	_entry_added_count += 1


func _on_journal_loaded() -> void:
	_journal_loaded_count += 1


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + msg)


func _write_raw_save(text: String) -> void:
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	_assert(f != null, "Could not open save path for test fixture.")
	if f != null:
		f.store_string(text)
		f.close()


func _test_save_and_continue() -> void:
	GameState.new_game()
	GameState.current_scene = "res://scenes/lamp_room.tscn"
	GameState.set_flag("trusted_edith", true)
	Journal.discover("edith_log_01")
	Journal.discover("tide_chart")
	_assert(GameState.save_game(), "save_game() should succeed")

	# Simulate cold relaunch by wiping in-memory state before load_game().
	GameState.flags.clear()
	GameState.current_scene = "res://scenes/game.tscn"
	Journal.clear()

	_assert(GameState.load_game(), "load_game() should succeed")
	_assert(GameState.current_scene == "res://scenes/lamp_room.tscn", "current_scene should persist")
	_assert(GameState.get_flag("trusted_edith") == true, "story flag should persist")
	_assert(Journal.entries() == ["edith_log_01", "tide_chart"], "journal entries should persist in order")


func _test_v1_save_without_journal() -> void:
	GameState.new_game()
	_write_raw_save('{"version": 1, "scene": "res://scenes/game.tscn", "flags": {"skeptic": true}}')
	_assert(GameState.load_game(), "v1 save without journal key should load")
	_assert(GameState.get_flag("skeptic") == true, "v1 flag should load intact")
	_assert(Journal.entries().is_empty(), "v1 save should initialize journal to []")


func _test_new_game_resets_journal() -> void:
	GameState.new_game()
	GameState.set_flag("believer", true)
	Journal.discover("edith_log_01")
	GameState.new_game()
	_assert(GameState.flags.is_empty(), "new_game() should clear flags")
	_assert(Journal.entries().is_empty(), "new_game() should clear journal entries")


func _test_toast_suppression_on_load() -> void:
	GameState.new_game()
	Journal.discover("edith_log_01")
	_assert(GameState.save_game(), "save_game() for toast test should succeed")
	Journal.clear()

	_entry_added_count = 0
	_journal_loaded_count = 0
	_assert(GameState.load_game(), "load_game() for toast test should succeed")
	_assert(_entry_added_count == 0, "entry_added must not fire on load_game()")
	_assert(_journal_loaded_count == 1, "journal_loaded should fire once on load_game()")


func _test_corrupt_and_non_dict_saves() -> void:
	GameState.new_game()
	GameState.set_flag("radioed_tom", true)
	Journal.discover("edith_log_01")

	_write_raw_save("{corrupt json")
	_assert(not GameState.load_game(), "corrupt JSON should return false")
	_assert(GameState.get_flag("radioed_tom") == true, "corrupt load must not clobber flags")
	_assert(Journal.entries() == ["edith_log_01"], "corrupt load must not clobber journal")

	_write_raw_save("[1, 2, 3]")
	_assert(not GameState.load_game(), "non-dictionary JSON should return false")


func _test_sanitization_and_deserialization() -> void:
	GameState.new_game()
	Journal.discover("")
	Journal.discover("   ")
	_assert(Journal.entries().is_empty(), "empty/whitespace discover() calls should be ignored")

	Journal.deserialize([" a ", "", 42, null, "a", "b"])
	_assert(Journal.entries() == ["a", "b"], "deserialize() should trim, filter, and deduplicate")


func _test_malformed_journal_field_in_valid_save() -> void:
	GameState.new_game()
	_write_raw_save('{"version": 1, "scene": "res://scenes/game.tscn", "flags": {"radioed_tom": true}, "journal": "edith_log_01"}')
	_assert(GameState.load_game(), "valid save with string journal field should still load")
	_assert(GameState.get_flag("radioed_tom") == true, "flags should still load when journal field is malformed")
	_assert(Journal.entries().is_empty(), "malformed journal field should reset journal to []")


func _test_duplicate_entry_discovery() -> void:
	GameState.new_game()
	_entry_added_count = 0
	Journal.discover("edith_log_01")
	Journal.discover("edith_log_01")
	Journal.discover(" edith_log_01 ")
	_assert(Journal.entries() == ["edith_log_01"], "duplicate discover() calls should store entry once")
	_assert(_entry_added_count == 1, "entry_added should emit only on first discovery")

	_assert(GameState.save_game(), "save_game() after duplicate discovery should succeed")
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	_assert(typeof(parsed) == TYPE_DICTIONARY and parsed.get("journal", []) == ["edith_log_01"], "saved JSON journal should be deduplicated")
