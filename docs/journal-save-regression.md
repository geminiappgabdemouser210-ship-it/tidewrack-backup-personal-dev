# Journal save / Continue regression coverage

This checklist protects the journal save contract without changing the existing
story-flag schema. `GameState` owns the save file; `Journal` owns only its
in-memory entries and passes JSON-safe data to and from `GameState`.

## Save contract

The existing save format remains version 1. A save contains:

- `scene` — the scene Continue loads.
- `flags` — existing narrative flags, unchanged from version 1.
- `journal` — an ordered, de-duplicated list of discovered entry IDs.

Older version-1 saves have no `journal` field. They remain valid: their scene
and story flags load normally, and the journal starts empty.

## How to run the automated checks

Run from the repository root:

```bash
godot --headless --path . -s tests/test_save_state.gd
python3 tests/validate_dialogue.py
```

The dialogue validator remains in the command sequence to confirm that the
unchanged dialogue graphs still parse, resolve targets, and have a reachable
ending.

## Pre-PR regression checklist

Tick each case only after observing the stated expected result. Cases labelled
**Automated** are covered by `tests/test_save_state.gd`; run the command above
and record its passing result. The other cases are deliberate local smoke tests.

- [ ] **JS-01 — Save / Continue round-trip (Automated + smoke).**
  - Setup: Start a new game, add `ediths_last_log` through the journal system,
    set `skeptic` and
    `trusted_edith`, and save from Pause.
  - Action: Return to title, select Continue.
  - Expected: The saved scene loads; both flags have their saved values; the
    journal contains `ediths_last_log` exactly once.

- [ ] **JS-02 — Broken journal field does not discard a valid save (Automated + smoke).**
  - Setup: Create a valid save with a known scene and story flags. Edit only
    its `journal` value in `user://save.json` to a string such as
    `"not-a-list"`.
  - Action: Select Continue.
  - Expected: Continue succeeds and restores the scene and story flags. The
    journal is empty; no stale in-memory entries remain and no crash occurs.

- [ ] **JS-03 — Duplicate discovery is idempotent (Automated + smoke).**
  - Setup: Start a new game with an empty journal.
  - Action: Trigger discovery of the same entry ID twice (for example, call
    `Journal.discover("ediths_last_log")` twice in a debug session), save, and
    Continue.
  - Expected: The entry appears once before and after Continue. The saved
    `journal` array contains one copy of that ID.

- [ ] **JS-04 — New Game clears discovered entries in memory (Automated + smoke).**
  - Setup: Discover at least one journal entry in an active session.
  - Action: Start New Game without saving the new run.
  - Expected: `Journal.entries()` is empty and story flags are reset for the new
    run. The previous on-disk save remains available to Continue until the new
    run is saved; this is intentional single-slot behavior.

- [ ] **JS-05 — Version-1 compatibility (Automated + smoke).**
  - Setup: Use a v1 `user://save.json` with `believer` and `radioed_tom`, no
    `journal` field.
  - Action: Select Continue.
  - Expected: Continue succeeds, both existing flags retain their values, and
    the journal starts empty.

- [ ] **JS-06 — Invalid entries are contained (Automated + smoke).**
  - Setup: Put a valid version-1 save with a `journal` array containing blank strings,
    duplicate strings, and non-string values.
  - Action: Select Continue.
  - Expected: Continue restores valid scene/flags. The journal retains only
    unique, non-empty string IDs, in first-seen order.

## Known boundaries to decide before launch

- **New Game is not a slot reset.** It clears the in-memory flags and journal,
  but the prior on-disk save remains available until the new run is saved.
- **No mid-dialogue or player-position checkpoint exists.** Only the saved
  scene, flags, and journal state resume.
- **Save writes use the original single-file behavior.** A corrupted
  `user://save.json` cannot be recovered by this change.
- **Stored scene paths are not validated on load.** Removing or renaming a
  saved scene can make Continue fail at scene transition.
- **Journal IDs are data, not content snapshots.** A reader should handle an
  unknown or retired ID gracefully when content changes between builds.
- **Cloud-save conflict handling is not implemented.** This change covers only
  the local single-slot save file.
