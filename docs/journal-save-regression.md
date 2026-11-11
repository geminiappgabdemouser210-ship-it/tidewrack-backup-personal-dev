# Journal save / Continue regression coverage

This checklist protects the journal save contract without changing the existing
story-flag schema. `GameState` owns the save file; `Journal` owns only its
in-memory entries and passes JSON-safe data to and from `GameState`.

## Save contract

The current schema is version 2. A save contains:

- `scene` — the scene Continue loads.
- `flags` — existing narrative flags, unchanged from version 1.
- `journal` — an ordered, de-duplicated list of discovered entry IDs.

Version-1 saves have no `journal` field. They remain valid: their scene and
story flags load normally, and the journal starts empty. The loader also accepts
the earlier provisional `journal_entries` key if one is encountered.

Saving first writes a temporary file, then keeps the prior complete save as a
recovery copy while replacing the primary file. If the primary file is
unreadable, Continue loads that recovery copy.

## Automated regression cases

Run from the repository root:

```bash
godot --headless --path . -s tests/test_save_state.gd
python3 tests/validate_dialogue.py
```

`tests/test_save_state.gd` covers:

1. **Current save / Continue round-trip** — saves a scene, `skeptic`,
   `trusted_edith`, and two journal IDs; resets the runtime; then confirms that
   Continue restores all of them exactly.
2. **Recovery after primary corruption** — makes a second save, corrupts its
   primary file, then verifies that Continue restores the previous complete save
   rather than losing flags or journal entries.
3. **Version-1 compatibility** — loads a v1 payload with `believer` and
   `radioed_tom`; confirms both flags remain intact and that no stale journal
   entry leaks in from the current session.

The dialogue validator remains in the command sequence because journal discovery
is declared in the dialogue graph. It verifies that the modified graph still
parses, resolves targets, and has a reachable ending.

## Pre-PR smoke checks

Run these manually in a local build:

1. Start a new game, read the logbook, Pause → Save, return to the title, then
   Continue. Confirm the logbook entry is still present once the reader UI
   consumes `Journal.entries()`.
2. Make both a narrative choice and a journal discovery before saving. Continue
   must restore the chosen story flag and the discovered entry together.
3. Save twice with different journal state. Damage or remove the primary
   `user://save.json`; Continue should resume from the first save via
   `user://save.backup.json`.
4. Try malformed journal payloads (missing field, non-array, blank IDs,
   duplicates, and non-string values). A valid scene and flag payload must still
   load; invalid journal values are ignored.
5. Confirm a v1 `user://save.json` still enables Continue and preserves its
   story flags. Its journal should be empty.

## Known boundaries to decide before launch

- **New Game is not a slot reset.** It clears the in-memory flags and journal,
  but the prior on-disk save remains available until the new run is saved.
- **No mid-dialogue or player-position checkpoint exists.** Only the saved
  scene, flags, and journal state resume.
- **No recovery copy exists after the first-ever save.** If that only file is
  corrupted, Continue cannot recover a prior state.
- **Stored scene paths are not validated on load.** Removing or renaming a
  saved scene can make Continue fail at scene transition.
- **Journal IDs are data, not content snapshots.** A reader should handle an
  unknown or retired ID gracefully when content changes between builds.
- **Cloud-save conflict handling is not implemented.** The backup protects one
  local write sequence only.
