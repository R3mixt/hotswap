# Changelog

## Unreleased

- Add a Modern theme with flat slate panels, cool accents and sans-serif typography alongside the default Classic theme.
- Switch themes immediately in Settings → Window without changing binding drafts or shared presets. Reset appearance restores Classic.
- Generate reproducible Classic and Modern preview images from the real addon UI without launching WoW, with explicit offline-preview labels.

## 1.0.0 - 2026-11-02

- Always opens the Current layout with the miniature spellbook and preserves staged edits.
- Adds Blizzard spellbook drag/drop and a Game spellbook opener.
- Adds independent character-local replacement and swap confirmation settings.
- Imports add presets without switching the selected draft or changing current settings.
- Handles downloaded UTF-8 profile text, validates imports atomically and bounds exports.
- Uses native actions for simple spells and ranks; reserves future spells without placeholder macros.
- Creates new macros only in character slots. Legacy account-overflow options cannot create shared macros.
- Adds a backed-up, confirmed reset to Blizzard's default character keybindings.
- Improves Current display of supported third-party action-bar button bindings.
- Adds behavior documentation, review evidence and regression scenarios.

- New presets leave optional utility form cancellation off to keep the full Era class catalogs within character macro capacity; existing preferences remain unchanged.

Prepared for Classic Era user testing. Automated Lua/API-mock tests and rendered UI geometry do not certify in-game protected execution, taint, casting or Bartender/Dominos compatibility. Conditional layouts can still exceed the character macro limit and will fail with a capacity explanation. Downloaded .hotswap files are imported by opening the text externally and pasting the code. No public upload is performed.

## 0.4.9 beta - 2026-11-02

- Fixed Current layouts failing to apply because future abilities exhausted character macro slots.
- Unlearned spells and missing items now reserve their chosen positions without creating macros.
- Learned spells and available items use native actions and bindings wherever possible.
- Reserved actions activate automatically when learned or acquired, outside combat, while respecting manual binding and action-bar changes.
- Existing Current layouts and pending drafts are upgraded automatically. Unused, unchanged addon-owned macros are cleaned up safely.
- Actions that require macros use character-specific slots. If space is unavailable, those actions remain reserved without blocking the rest of Apply.
- Personal macros and unrelated controls are preserved.


## 0.4.8 beta — 2026-11-02

- Stage hover-bind replacements and supported preset swaps immediately without confirmation dialogs. Keep hover input active for successive edits. Ordinary click/drag editing retains its confirmation flow; Apply still installs the staged layout.


## 0.4.7 beta — 2026-11-02

- Make Current a full editable layout seeded only from live controls, with an independent spell catalog instead of the selected preset's replacements.
- Allow unlearned spells, specific future ranks, missing items and emotes; reserve future actions with verified character macros. Preserve existing unrelated keys and native slots.
- Enable all-spells Hover bind, Change action, Clear key, and adding items by ID in Current. Future abilities remain visible in the Current spellbook.
- Keep pending Current edits across reloads until applied or discarded; retain readable future-action labels after Apply and learning. Named backups recreate owned Current macros safely, including name collisions.


## 0.4.6 beta — 2026-11-02

- Open Current bindings in edit mode with the spellbook visible. Stage key changes and learned-spell/item/macro replacements, then apply only those edits with a named backup. Discard pending edits without game writes.
- Detect stale keys/slots before applying Current edits; retain pending edits after a failed installation and use the existing recovery worker.
- Select a class-compatible draft on login; retain foreign presets but exclude them from selection. Disable foreign installed layouts without changing game controls.
- Prompt to overwrite the selected preset or save under a new name when saving recommendations or applying changed drafts. Preserve preset IDs/shortcuts on overwrite and the original saved version on save-as-new.


## 0.4.5 beta — 2026-11-02

- Fix restored direct macro identities and preserve personal changes after failed form maintenance.
- Correct draft editor state, imported shortcut validation, copied fixed ranks and recommendation preview filters.
- Avoid reapplying unchanged presets; distinguish unreadable live slots; add All pages in List and named-restore confirmation.
- Verify Hover bind includes every planned spell across all nine classes, unavailable talents and configured ranks.
- Validated with mocked Lua APIs; live-client acceptance remains pending.

## 0.4.4 beta — 2026-11-02

- Open on the current character's actual bindings and native bar contents, including movement, mouse controls and current pet slots. Do not substitute class recommendations or reserve future spells in this view.
- Replace the prominent Optimize action with Presets > Preview recommendations. Preview without creating macros, presets or game bindings; save a separate recommended draft only when requested, then explicitly Apply & save.
- Add Hover bind: a native scrollable spell grid that includes future abilities, talents and configured ranks. Hover an ability and press its new key; the keyboard and preset draft update together.
- Keep linked action-bar positions and existing swap/protection rules. Support Shift/Ctrl, side buttons and wheel bindings; reserve Alt, movement and primary clicks.
- Add Done - keep draft and Apply & save. Hover mode consumes input without casting, ends on Escape, closing or combat, and releases capture before applying.
- Add fresh-character regressions confirming login does not alter inherited account bindings or create input capture; explicit Apply only saves the character binding set.

## 0.4.3 beta — 2026-11-02

- Display readable action labels on verified generated native macro buttons while preserving their internal names, bodies and bindings. T and Shift-T show Trinket 1 and Trinket 2.
- Explain empty trinket slots in tooltips while preserving equipped-item details and distinguishing uncached item data.
- Name the addon upload `HotSwap-0.4.3-CurseForge.zip` and clearly mark the separate developer source archive as not for upload. Add an explicit root-folder/TOC/load-file check before publishing a package. The previous runtime ZIP already contained its TOC; the reported rejection could not be reproduced locally.

## 0.4.2 beta — 2026-11-02

- Use character-specific slots for new generated macros by default. Account-wide overflow is an explicit preset option under Settings > Action bars.
- Fix the low-level Warrior setup failure when only 30 macro slots are available. If future placeholders exceed capacity, keep their keys and native positions reserved without allocating individual macros. Learned abilities populate owned positions outside combat.
- Preserve personal macros and reuse existing unchanged owned macros. Existing account macros are not migrated or automatically reclaimed.
- Keep real future spell metadata in the editor and explain capacity reservations in Review. Report which macro bank needs space when learned abilities or backup restoration cannot fit.
- Make failure Details opaque so the page behind it cannot obscure error text.

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
