# Journal & Save System Regression Test Plan

Structured verification cases for journal entry persistence, save file compatibility, and safety checks.

## Verification Cases

### 1. Main Save / Continue Path
- **Steps:**
  1. Launch game, start new game, discover journal entries.
  2. Save game state (`user://save.json`).
  3. Quit to desktop and relaunch the application.
  4. Click **Continue** on the Main Menu.
- **Expected Result:**
  - `Journal.entries()` correctly contains all discovered entry IDs.
  - `GameState.flags` and `GameState.current_scene` are restored intact.

### 2. v1 & Pre-Versioned Save Compatibility
- **Steps:**
  1. Place an older `v1` or pre-versioned `user://save.json` (lacking `"journal"` key) in the user directory.
  2. Launch game and click **Continue**.
- **Expected Result:**
  - `GameState.flags` and `GameState.current_scene` restore intact.
  - `Journal.entries()` initializes to `[]` without triggering a Godot 4 typed-array (`Array[String]`) runtime error.

### 3. New Game Reset (No In-Memory Leak)
- **Steps:**
  1. Discover journal entries during active session.
  2. Return to Main Menu.
  3. Click **New Game**.
- **Expected Result:**
  - `Journal.entries()` and `GameState.flags` are both completely cleared.
  - No leftover state from previous session persists.

### 4. Notification Suppression on Continue
- **Steps:**
  1. Load a save file containing previously discovered entries via **Continue**.
- **Expected Result:**
  - `journal_loaded` signal fires.
  - `entry_added` signal does NOT fire for already-discovered entries upon restoration.

### 5. Corrupt / Malformed JSON Handling
- **Steps:**
    1. Test loading malformed JSON and non-dictionary JSON.
  2. Observe `load_game()` execution and menu behavior.
- **Expected Result:**
  - `load_game()` returns `false` cleanly without crashing or corrupting current state.
  - `main_menu.gd` handles `load_game() == false` gracefully when Continue is clicked.
### 6. Sanitization, Deduplication & Unknown IDs

- **Steps:**
  1. Pass empty/whitespace strings, duplicate IDs, and non-string items to `Journal.discover()` and `Journal.deserialize()`.
  2. Load a save with unknown or renamed entry IDs.
- **Expected Result:**
  - Empty/whitespace and duplicate IDs are ignored; non-string items are filtered out.
  - Unknown/renamed entry IDs in older saves are skipped gracefully by the reader UI without errors.

### 7. Dialogue-Choice Save Timing
- **Steps:**
  1. Trigger dialogue choices that award journal entries or set flags.
  2. Check timing of `save_game()` calls and quit mid-dialogue.
- **Expected Result:** 
  - `save_game()` runs only after both `GameState.set_flag()` and `Journal.discover()` finish.
  - Quitting mid-dialogue leaves no partial or corrupted save.

### 8. Valid Save with Malformed Journal Field
- **Steps:**
  1. Load a `user://save.json` that parses cleanly with valid `flags` and `scene`, but `journal` is the wrong type (e.g., `"journal": "edith_log_01"` as a string instead of a list, or a dictionary/number).
  2. Observe `load_game()` execution and state restoration.
- **Expected Result:**
  - `load_game()` returns `true`.
  - `flags` and `current_scene` still load intact.
  - `Journal.deserialize()` resets `_entries` to `[]` without throwing a Godot 4 typed-array error.

### 9. Duplicate Entry Discovery
- **Steps:**
  1. Call `Journal.discover("edith_log_01")` more than once (including whitespace variants like `" edith_log_01 "`).
  2. Observe `_entries` array state, signal emissions, and trigger `save_game()`.
- **Expected Result:**
  - `_entries` retains only a single `"edith_log_01"`.
  - `entry_added` emits only on the first discovery.
  - `save_game()` writes a deduplicated `journal` array.
