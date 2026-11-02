# Changelog

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
