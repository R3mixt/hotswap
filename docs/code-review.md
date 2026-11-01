# 0.3.0 review record

Reviewed 1 November 2026 across runtime, UI, import/export, native actions and recovery, including independent cross-checks between module owners. The release remains beta until client acceptance is complete.

## Findings fixed

- Replaced synchronous setup/recovery with bounded frame jobs, addressing the reported Engine timeout. Named backups precede writes; rollback has its own worker and error reporting.
- Recovered the original active binding set when reading/restoring the other set fails, including unsaved active edits. Retained complete snapshots for subsequent recovery.
- Removed custom combat-bar code/settings with explicit legacy import migration. Removed obsolete item UI/form-driver helpers; extracted spellbook/target and item editors.
- Corrected native Druid pages and linked-position edits. Missing/removed form talents and powershift actions use inert placeholders instead of cancelling form before failure.
- Prevented imported names/ranks from becoming executable macro fallback. Typed descriptors resolve client metadata; payload and per-preset record limits bound work.
- Preserved user macro bodies and revalidated references during apply. Blocked unsafe arbitrary-macro Alt aliases on shared positions.
- Distinguished ground, self-use and verified unit-target items. Kept draft choices separate from installed maintenance; deduplicated shared-macro edits. Pending target modes cannot accidentally share future behavior.
- Released owned cursor payloads after failed placement while preserving the player's existing cursor. Validated snapshot restore types and flyout pickup.
- Cached library search data and checked global shortcuts without rebuilding every full preset. Retired stale prototype implementation copies from maintained source.

## Evidence and limits

The integration run passed **191/191** actual-Lua-5.1 regression scenarios. Packaging reruns the suite and generates a fresh report. Checks cover all class/flavor catalogs, older extra-bar capacity, native snapshots, failure rollback, reload persistence, UI capture, spell/rank/target editing, item alternatives and safe transfer.

No unresolved blocking defect was identified in this review. Protected execution, taint, real input consumption, target/ground casting and textures still require in-game acceptance. Automatic best-food/water selection and a complete top-20 professional-keymap census remain unfinished requirements, not release claims.
