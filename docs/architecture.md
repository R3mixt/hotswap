# Hot Swap architecture

Hot Swap prepares a binding layout, then installs it onto Blizzard's original bars outside combat. Planning and editing never mutate live game bindings. There are no custom combat bars or rotation decisions.

## Modules

| Module | Responsibility |
| --- | --- |
| Core | SavedVariables migration, settings, events and public entry points |
| API | Client feature detection, localized spell/item metadata and game API wrappers |
| Profiles / LibraryData | Stable class IDs, recommended keys and display-only specialization/talent metadata |
| Macros | Supported target, form, rank and item macro bodies |
| Items | Inventory capabilities, explicit choices/alternatives and equipment operations |
| Library | Typed entries, filtering, placement and editable target capabilities |
| NativeBars | Map to Blizzard pages/slots; placement, snapshots and visibility |
| Planner | Resolve knowledge, reserve future positions, cover learned actions and validate the plan |
| Engine | Bounded apply, recovery, rollback and maintenance jobs; macro ownership |
| Presets | Complete drafts, activation shortcuts, backups and data-only transfer |
| UI / LibraryUI / ItemsUI | Main configuration, spellbook/target editor and item editor |
| Launcher | Native settings and Escape-menu integration |

Each Lua module receives the shared `K` namespace through addon varargs. The TOC defines load order. Python is for development only.

## Data and flow

1. The selected preset holds editable settings. Stable action IDs connect bindings, overrides and item alternatives; preset IDs survive renames.
2. Planner resolves current-client metadata. Display metadata is separate from learned eligibility. Future actions reserve positions without becoming usable.
3. NativeBars assigns main positions and available extra slots. A main position has one key across form pages. A spell edit changes the selected page; a key edit changes every linked page. Overflow uses ordinary macro bindings after capacity validation.
4. Engine preflight checks combat, cursor state, capacity, shortcut overlap and restorable action types. Snapshot reads finish before the named backup is stored and live writes begin.
5. A frame worker advances small steps with time and operation budgets: macros, native actions, new bindings, obsolete binding removal, settings save and completion verification. Recovery uses the same mechanism.
6. The applied plan is separate from the draft. Inventory and form maintenance use applied settings; an event cannot silently install an edited draft item choice.

`bindingOverrides` maps action IDs to keys. `actionOverrides` holds rank, targeting and replacement edits. `customActions` contains typed spell/item/system/emote/macro-reference descriptors. `itemBindings` holds a selected item ID, ordered alternatives, target mode and explicit empty state. UI calls these domain methods rather than constructing executable text.

## Invariants

- Back up both binding sets, unsaved active bindings, native contents, page/visibility and managed settings before replacement. Never leave the inactive binding set selected across frames.
- Preserve a pre-existing player cursor payload. After failed owned placement, release only the payload acquired by that operation before rollback.
- Preserve user-edited macros. Names and body fingerprints identify ownership; local macro references must still match at apply time.
- Imports are data. Resolve spell names and exact ranks through client metadata; never compile imported display strings as macro syntax. Existing macros remain local references.
- Alt-self wins over friendly mouseover/focus clauses. Arbitrary macro references cannot inherit another native page's self-cast alias where semantics would be unsafe.
- Ground targeting is not unit targeting. Offer item unit modes only from verified capability data; unknown items retain default behavior.
- Missing items/talents retain inert reservations. Losing a form talent must not leave a macro that cancels form before failing.
- Apply, restore and mode switching cannot start in combat. Interrupted jobs report partial progress and resume after lockdown; do not claim completion early.
- Rendering/search use cached metadata and bounded lists. Invalidate relevant caches instead of rebuilding every saved preset on each input event.

## Extension and validation

Keep client API differences in API/NativeBars, not UI handlers. Add catalog entries with stable IDs and sourced spell IDs. Keep display categories separate from capability. Extend target modes through the shared capability/compiler path and test Alt behavior. Add settings through defaults, migration, import validation and export together.

Run `python tests/run_tests.py` after installing requirements-dev.txt. Tests execute actual modules in fresh Lua 5.1 VMs with mocked APIs. Failure injection covers partial apply, rollback, binding-set reads, cursor cleanup, macro edits and combat pauses. UI tests cover input ownership and staging. `ui-qa/capture.py` and `render.ps1` render actual frame geometry with approximate artwork; neither replaces the live-client checks in compatibility.md.
