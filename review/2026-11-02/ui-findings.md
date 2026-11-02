# UI and interaction review — 0.4.4 baseline

Reviewed `7d5d5f28a527bfa298ddc33f7a4670b0d24da5bf`. These are review findings, not runtime changes. `python review/2026-11-02/ui_probe.py --deps PATH_TO_DEPENDENCIES` runs the real modules through the existing Lua 5.1 harness and asserts/prints the three baseline defect observations below. The dependency argument is optional when `lupa` is installed in `python-deps` or the Python environment. These probes document existing defects; their assertions should change when regression tests for fixes are added. Visual inspection used generated geometry images, not a running WoW client.

## Confirmed bugs

### UI-01 — Draft item editing fails to enter the draft context (P2, high confidence)

- **Code:** `KeybindOptimizer/ItemsUI.lua:24`, `:40`, `:46`, `:60`, `:68`, `:81`; `KeybindOptimizer/SettingsUI.lua:105`; `KeybindOptimizer/UI.lua:303`, `:406`, `:716`, `:2182`.
- **Reproduce:** Open Hot Swap (Current), visit Items, add item 1710 to the utility choices, then Use this item. The choice is saved in the selected preset, but `bindingSource` remains `current` and Apply is disabled. The enabled Edit key button refuses with “Choose an editable preset draft before rebinding.” Open spellbook takes the user to Current with no spellbook. Settings → Spells only similarly saves protection flags without selecting the draft context.
- **Expected:** A user who explicitly opens a draft editor should see its preset name, be able to edit its key, and be able to apply the resulting draft outside combat after validation. Read-only Current and Recommendation contexts should never ambiguously describe a draft editor.
- **Cause:** Most setting controls call `UI:Stage`, which enters draft mode, and preset actions receive special handling in `UI:Call`. Items mutations and Spells only bypass both transitions. `ItemsUI` enables Edit key without checking source while `BeginCapture` correctly rejects that source.
- **Fix:** Introduce one explicit “edit this preset” transition for all draft-editing entry points; invoke it on Items/Controls draft entry or successful mutations. Keep character-local appearance/diagnostics independent. Use one shared editability predicate for button state and handler behavior.
- **Acceptance:** From Current and Recommendations, repeat every Items mutation, Edit key, Open spellbook, and Spells only. Assert the correct preset identity, draft source, UI enabled state, and zero gameplay writes until explicit Apply.

### UI-02 — Recommendation preview inherits an unrelated live-binding search (P2, high confidence)

- **Code:** `KeybindOptimizer/UI.lua:1408` (`PreviewRecommendations`), compared with the filter reset in `SetBindingSource` at `:1402` and `Open` at `:2216`.
- **Reproduce:** Search Current for `ZZZZunlikely`, open Presets, and click Preview recommendations. The source changes to recommendation, but `bindingView` stays `list` and `search` stays `zzzzunlikely`. The result is “No matching bindings” instead of the recommended keyboard.
- **Expected:** This primary preview action should present an immediately reviewable recommendation. It should reset to Keyboard with no search (and a clearly identified form/modifier layer), or visibly offer “clear previous filter” rather than silently showing an empty plan.
- **Fix:** Route preview through the same source-transition reset routine, explicitly choosing the initial keyboard state. Preserve filters only for ordinary navigation within the same context.
- **Acceptance:** Start from an empty search result, Shift/Ctrl layer, list view, and a different pinned form. Preview from Presets must show the intended recommended keyboard and still create no preset or gameplay writes.

## Smaller correctness/usability issue

The empty-list message at `UI.lua:1631` says “select All”, but the Action page menu at `:1457` only offers Base/Cat/Bear/Moonkin. `SetActionPage` supports `all`; users have no corresponding menu item. Offer All pages for List (while retaining one page for the physical keyboard), or correct the recovery instruction. Searching in a draft currently remains restricted to its form filter, so a valid spell on another page can appear missing.

## Recommended state contract

- **Current:** live reader only; no draft or gameplay mutation from inspection. Action: inspect, or explicitly choose/capture a draft.
- **Recommendation:** immutable temporary plan and settings snapshot. Action: save a separate named draft; no direct Apply.
- **Draft:** explicit stable preset ID plus its editable settings; edits autosave only that draft. Action: undo, review differences, or Apply after fresh preflight.
- **Installed:** separate snapshot/identity from the selected draft; maintenance reads only this plan. Apply success updates Installed, failure reports verified rollback or recovery needed.
- **Local preferences:** appearance and diagnostics remain independent of these layout modes.

A single transition method should reset mode-specific selection, search, layer and modal state, and the same capability predicate should determine both enabled buttons and permitted actions.

## Professional UX improvements

1. **Make state and scope unmistakable.** A persistent mode control should identify Current (read-only), Recommendation (unsaved), or Draft + preset name. Show “Installed preset” separately. Read-only modes should expose inspection and their next useful action rather than an entire bank of disabled editing buttons.
2. **Add explicit current-to-draft capture as a separate feature.** It needs its own representation for native slots, bindings, macro references and unsupported contents, plus a preview of capture completeness. Do not convert current layout to recommendations. Until implemented, explain the limitation beside the edit affordance.
3. **Offer a useful change review.** Summarize keys changed/released, native slots replaced, macros created/reused and remaining capacity, protected controls, bar visibility and casting setting changes. Link affected rows to their editor and preserve a readily identifiable backup.
4. **Provide draft undo/redo and reset scope.** Autosaved draft edits currently have no general undo. Distinguish Reset key, Reset action, Revert draft to installed, and Delete preset; display whether edits are saved to the draft versus installed in WoW.
5. **Improve finding actions.** Make search scope visible (all pages/current form); add an explicit All pages list view and a clear-search control. Hover bind needs search and form/category filters for large catalogs while retaining access to future spells/ranks. Preserve one-click return to the full list.
6. **Improve legibility without abandoning Blizzard styling.** The geometry previews have a consistent native visual language, but many key tags are 7–9 px and important helper text 10–11 px. Add a readable text-density setting and validate actual client fonts at small viewport/UI-scale combinations. Avoid communicating state solely with gold/gray text or one-letter badges.
7. **Clarify input capture.** Keep an obvious “Keys are being intercepted; no casting” state and Escape instruction visible during keyboard and hover testing. Combat entry must visibly announce that normal game input is active. Test close, modal, search focus, spellbook drag, collision confirmation, combat and resumed operation paths in the real client.
8. **Simplify the action hierarchy.** Presets has both a panel Apply button and a footer Apply; one primary install action is enough. Preserve explicit backup-first installation and make recommendation saving a distinct step. Prefer “Apply preset” with a clear “Draft saved automatically” status if renaming does not disrupt established terminology.
9. **Make Items understandable without technical knowledge.** Label the bare item-ID field, offer pasteable item links where supported, show the chosen item's actual key and availability, and state that alternatives do not switch automatically. Keep equipment changes visibly separate because Equip saved acts immediately.
10. **Persist window placement and use stable geometry.** `LibraryUI.lua:198-202` re-centers the window during fitting; opening/closing spellbook should preserve the user's chosen position where possible. Dropdowns should be clamped and scrollable and should respect effective scale. Validate long spell/preset names, localization and low resolutions.

## What should be retained

Current data has its own read-only reader; recommendations can be inspected without creating drafts; Apply is explicit and backed up; edits reuse conflict and linked-form checks; unavailable actions have distinct indicators; the spellbook virtualizes visible rows; busy/combat/modal transitions deliberately release capture. These are the right foundations. The greatest UI weakness is inconsistent transition logic between them, not the native artwork.
