# Implementation status

## Completed

Previous commit 0d125de addressed F1, F2, F4, F5, F6 and F7 from REPORT.md.
This follow-up addresses:

- F8: selecting an unchanged installed preset no longer marks it dirty or creates a needless backup/reapply.
- F9: failed native action reads show unavailable details with an explicit read error, rather than claiming the slot is empty.
- F10 / part of U4: Draft List has an All pages option; returning to Keyboard selects a single page.
- Part of U7: named full restoration shows the selected backup name and replacement scope, requires confirmation, and captures the selected ID so confirmation cannot restore a different selection.

## Hover bind verification

Already implemented in HoverBindingsUI.lua and accessible from Bindings while explicitly editing a saved preset draft. It shows all planned spell actions in a scrollable grid, including future/unlearned class abilities, talent actions, form pages, spellbook coverage additions and configured fixed ranks. The normal unavailable-spell visibility preference does not remove them.

Added coverage checks for all nine original classes with unavailable entries hidden in the ordinary editor, plus an exact fixed-rank check. Existing tests cover learned/unlearned talents, repeated assignments, modifiers, side buttons/wheel, linked forms, collision confirmations, Done, explicit Apply, Escape, close and combat teardown.

“All spells” means all planned spells for that character/preset, not every spell across every class or every possible rank simultaneously. Additional exact ranks must be configured as bindings first; unavailable ranks are limited by client metadata. Items, generic macros and system commands remain in their respective editors. Native pet-slot ordering/autocast persistence is not implemented.

Mock verification establishes grid contents and staged input behavior. Real-client rendering, taint and no-casting input routing still require in-game acceptance.

## Remaining backlog

F3 (interleaved binding writers and rollback reconciliation) is still open and needs a transaction journal/fresh-observation design, not removal of verification. Larger UX features remain open: draft undo/redo, full before/after review, current-native-layout capture, hover search/filter controls, typography/window improvements, backup retention, import inspection/size limits, explicit planning context, consumable selection and pet-layout persistence. U4 and U7 are partial, not complete.

No release installation, publishing or version promotion was performed.
