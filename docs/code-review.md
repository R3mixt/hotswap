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

## 0.3.1 follow-up — 1 November 2026

The live-client Optimize error exposed a gap in the original test double: it appended new macros without sorting/reindexing the bank. Modeling those moves reproduced the exact NativeBars.lua placement error. The fix uses current name/content/ownership checks at placement, overflow binding, maintenance and recovery. Numeric IDs remain diagnostic results, never stable identities. New regressions cover repeated Optimize, reordering, deletion, personal edits and rollback with action references preserved by the game model.

Bar visibility now has a staged native UI, strict per-preset import/export flags and required-bar enforcement. Tests verify actual mocked frames become visible, nil/legacy flags preserve positions, unused bars retain explicit choices, delayed mirror values refresh correctly, stale proxy cache bits are cleared, Restore supersedes prior requests, and combat stops frame updates. The derived-setting adapter and deferred refresh were independently reviewed against Blizzard's current Era/Forever implementation. The final button is Apply & save; selection only opens a saved draft.

See the generated validation report for the current full-suite count. These reproductions strengthen coverage but do not replace the requested in-game retest.

## 0.3.2 follow-up — 1 November 2026

Reproduced the reported new-Druid Optimize failure by making the mock enumerate real supported commands and reject TARGETFOCUS on Era. The former assigned-key-only mock accepted any command and concealed the defect. Planning now omits unsupported defaults; explicit saved focus intent and every planned native command are checked against the actual registry before mutation.

Independent review also found and fixed two edge cases: a registered arbitrary CLICK/MACRO command must not bypass the typed action path, and a named backup must authenticate preset shortcuts using the saved modes it will restore, including deleted modes. Baseline recovery still preserves arbitrary original personal bindings.

Diagnostics are modular, opt-in and bounded. Disabled operation records nothing; enabled transactions record phases and outcomes with exact failing command/context and bounded stacks. Logger failures cannot break setup. The global handler forwards original arguments/results and does not replace another addon's newer wrapper when disabled. Settings and logs stay outside import/export and recovery state.

UI review checked persistent error details, explicit recovery outcomes, Escape handling, native slider support on Era/Forever, copy/clear controls and preferred-versus-fitted scale. Geometry previews were inspected for Settings, diagnostic log and failure details. Regression coverage includes fresh Era Optimize, no-write preflight, native recovery, disabled/enabled diagnostics, failure injection, handler chaining, capped storage, reload and appearance isolation.

The final integrated suite passed **253/253** scenarios using actual Lua 5.1 modules and mocked WoW APIs. No unresolved blocking source issue was identified. Real-client protected execution, slider dragging, rendered textures and long-log scrolling/copy remain acceptance checks; mock and geometry results are not a live-client certification. Public CurseForge creation/upload is still unfinished after the dashboard returned a client error.
