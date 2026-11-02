# Changelog

## 0.4.1 beta — 2026-11-01

- Add explicit Own key / Shared key selection in the talent-key editor, with a direct Change key action.
- Preserve individual custom bindings when changing between independent and shared talent choices.
- Keep unlearned talent buttons inert, including form cancellation, and refresh independent talent macros when learned or removed.

## 0.4.0 beta — 2026-11-01

- Add preset protections for movement, camera/selection, chat, targeting, other game controls and casting settings; Spells only enables all six.
- Add separate local switches for native macro labels, tooltip macro code and unavailable entries in the editor.
- Distinguish ordinary unlearned spells from talent abilities with L/T badges and readable tooltips.
- Optionally leave unavailable native slots empty and fill them as spells are learned, preserving keys and personal bar edits.
- Add ordered talent alternatives on shared utility keys, with first-learned selection, out-of-combat updates and preset transfer.
- Organize Settings into Controls, Action bars, Window and Diagnostics.

## 0.3.3 beta — 2026-11-01

- Preserve bindings outside the keys assigned by the preset. When a key leaves Hot Swap control, restore its displaced binding only if the player has not changed it.
- Recognize Blizzard's hidden left/right mouse commands without weakening unsupported-command checks. Capture and verify hidden aliases and custom mouse assignments in both binding sets.
- Repair missing left/right controls once on reload for older active layouts, outside combat, with a named backup. Existing custom mouse assignments are preserved.
- Restore old backups without interpreting uncaptured mouse state as an instruction to erase it; preserve each binding set's own mouse controls. New snapshots still restore intentionally unbound buttons exactly.
- Add hidden-command, selective-update, dual-set recovery, legacy migration and rollback regressions.

## 0.3.2 beta — 2026-11-01

- Fix fresh-character Optimize on Classic Era: omit unavailable default focus controls and validate actual registered commands before action-bar or macro writes. Explicit saved focus intent stays an actionable error.
- Add Settings with character-local opacity, preferred scale, automatic screen fitting and Reset appearance. Preset imports and switches preserve these preferences.
- Add opt-in diagnostics, off by default, with a bounded 200-entry history, setup phases, key/command/stage, backup and rollback result, bounded error stacks, copy and clear controls. Preserve the existing game error handler.
- Add persistent, selectable failure details; distinguish preflight rejection, completed rollback and incomplete recovery instead of clipping the error into the footer.
- Strengthen the binding mock to enumerate supported commands, reject unavailable commands and reproduce the Era F6 failure; test logging, recovery, saved-mode restoration and UI controls.

## 0.3.1 beta — 2026-11-01

- Fix Optimize failing with "A generated action macro changed before placement." Macro creation can reorder indices; placement and maintenance now resolve and verify stable names and exact contents.
- Add Setup's Action bars dialog: required bars enable automatically, optional visibility is saved per preset and shared through imports/exports, and unsupported bars are distinguished from hidden bars.
- Rename the final installation action to **Apply & save**, with clear draft/active wording and backup-first explanation.
- Synchronize Blizzard's native bar-setting cache, preserve nil/legacy toggle positions, and refresh after delayed server updates without touching protected frames in combat.
- Upgrade regression mocks to reproduce macro sorting and index changes, preserving native action references. Add failure, rollback, bar-setting and delayed-visibility coverage.

## 0.3.0 beta — 2026-11-01

- Uses Blizzard's original bars and correct native Druid pages.
- Bounded apply, restore and rollback with visible progress.
- Optimize, complete presets, activation shortcuts and named backups.
- Miniature spellbook with categories, talents, ranks, items, game/chat/emote commands and macro references.
- Drag/click placement and applicable target-mode edits with keyboard badges.
- Items organized by binding, selected item, availability and saved alternatives.
- Preview-only keyboard testing and click-to-rebind.
- Hardened import validation, macro ownership, missing-item updates and recovery.

Automated regression coverage passes; in-game acceptance remains. Automatic best-food/water selection is not included. Era mock tests do not certify Forever-specific behavior.
