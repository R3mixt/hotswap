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

## 0.3.3 follow-up — 1 November 2026

The prior registry guard incorrectly treated Blizzard's active hidden mouse commands as unavailable. The mock had exposed them in visible enumeration and concealed this distinction. Source-backed handling is limited to CAMERAORSELECTORMOVE and TURNORACTION; unsupported focus commands still fail safely. Snapshot reads supplement enumeration with hidden command aliases and direct reads of affected keys, including custom mouse assignments.

The user's revised requirement changes Apply from whole-map replacement to planned-key updates. A committed plan tracks each managed key's installed command and displaced binding. Releasing a key restores its displaced binding only while Hot Swap's command is still installed; personal changes remain untouched. Exact rollback and explicit backup restoration keep snapshot semantics.

Independent review found that old backups lack hidden mouse state and cannot represent deliberate unbinding there. Their migration preserves each binding set's own current mouse controls, not whichever set was processed most recently. New versioned snapshots restore custom and intentionally empty mouse bindings exactly. A bounded, backup-first reload migration repairs only missing primary buttons in older active layouts and defers in combat; current layouts do not automatically undo intentional later unbinding.

Regression coverage exercises default and custom mouse controls, additional hidden aliases, failed reads, closed-window Apply, selective updates, displaced/manual keys, dual-set recovery and rollback. Live-client retesting is still required for real camera/target/interact input delivery.

Final 0.3.3 review also injected a personal mouse edit after recovery backup. Both successful repair and later-failure rollback preserve that edit without rewriting the original backup. The final integrated validation result is recorded in the generated release validation report.

## 0.4.0 follow-up — 1 November 2026

Control protections now classify actual current commands and reserve their keys before spell allocation, including hidden mouse aliases and Alt-self collisions. Independent review found and fixed a linked-page allocation defect: a protected Alt alias on a healing page must rehome the entire native position across Cat/Bear/Base/Moonkin. Protected explicit spell pins and global preset shortcuts stop in preview. Dynamic macro/frame names containing CAMERA or CHAT are not classified as native controls. Unreadable registry state fails closed.

Availability and ordered talent choices are separate from UI rendering and protected mutations. Shared choices resolve only from learned spells, retain a stable destination, preserve other keys, and reserve Alt consistently across helpful/non-helpful alternatives. Explicit reset, rank/replacement edits and copying the displayed alternate were reviewed together to prevent stale target/rank metadata. Typed exports validate order, class identity, limits and target capability.

The new availability worker uses the installed plan, verifies owned slot/key content before each write, retains manual-edit detachment across events and rollback, and guards binding-set changes. Failure injection covers slot placement/cursor cleanup, overflow saves, manual edits during jobs and rollback. Obsolete generated macros are removed by a separate one-per-frame idle worker only after successful commit and only when no native slot or binding references them. Named backups recreate missing owned macros by exact body when needed.

Settings has four native subsections. Geometry previews for Controls, Action bars, Window, Diagnostics and Talent choices were inspected; a clipped multiline window note was fixed. Cosmetic macro visibility changes only original fontstrings and defers in combat. Local display preferences do not travel in presets. Availability badges and hidden editor entries retain physical key positions.

The release packaging step reruns the integrated Lua 5.1 suite and records its exact result. Source review, failure injection and geometry previews are complete; real-client protected execution, font rendering, event timing, camera input and talent-respec behavior still require the acceptance checks in compatibility.md.

Final integrated validation: **331/331 scenarios passed** using the actual Lua 5.1 modules and mocked WoW APIs. The package contains 21 runtime modules; ZIP integrity and explicit manifest checks passed.

## 0.4.1 follow-up — 1 November 2026

The talent editor now explicitly distinguishes Own key (default independent binding) from Shared key (ordered learned alternatives). Mode changes retain independent key overrides and use the existing validated preset format. Own key has a direct Change key action. Both native UI layouts were rendered and inspected.

Unknown catalog talents are strictly inert tooltip macros. Known talents also keep managed macro identities so ordinary learn/respec transitions can edit owned bodies without moving keys or slots. Earlier raw-spell talent placements upgrade through the ownership-checked slot worker. When shared placeholders need different target/rank bodies, or an unchanged alias must remain inactive, maintenance delegates before any writes to the existing transaction worker. Tests cover normal/focus variants and an unavailable fixed rank that must not activate with its spell family.


## 0.4.2 follow-up — 2 November 2026

Reproduced the reported starting Warrior failure with 120 personal account macros and 30 empty character slots: the original layout requested 40 generated macros, mostly future placeholders. Capacity fitting now defers unlearned ordinary spell macros while retaining their keys, native positions and editor metadata. The installed plan records this execution policy separately from visibility settings and uses the existing owned-slot worker when spell knowledge changes. Learned actions are never silently discarded to fit.

New macro creation is character-only unless the preset explicitly enables account overflow. Budget checks, asynchronous creation, maintenance and named restoration use the applicable saved plan's policy. Reusable owned account macros remain valid for upgrades; no migration or cross-character ownership claim is attempted. Full learned/custom layouts can still exceed the client's character capacity, and stop safely with a bank-specific message.

Independent runtime review checked storage policy propagation, restoration, macro ownership and manual-edit preservation. Existing full-catalog test fixtures now explicitly enable overflow where capacity is unrelated to their assertions; fresh-character/default-policy tests retain the real character-only default. New regressions exercise all nine starting classes at 30 free slots, distinct character databases sharing one account bank, explicit character-first overflow, future spell activation across Warrior stance pages, exhausted-bank no-write failures and recovery.

The error Details panel now has an opaque native backing independent of main-window opacity. Focused UI tests and geometry checks cover the new staged checkbox, readable failure details and reservation notice. The final suite count and ZIP integrity result are recorded by release packaging. Actual client security, input routing and rendering remain subject to compatibility.md.


## 0.4.3 follow-up — 2 November 2026

The reported T-button text `KBO_5e1cc3d3` is the content-derived name for `#showtooltip 13` followed by `/use 13`. Native Blizzard buttons display macro names independently from the item icon/tooltip. Cosmetic labels now use the installed action's readable name (Trinket 1/2 for slots 13/14), leaving stored macro identities and secure bindings intact. A bounded presentation index avoids running the planner or spellbook scan on button updates. Every lookup checks the current effective native action and exact owned macro contents, preserving personal or changed macros and following native page switches. Visibility preferences and combat deferral remain unchanged.

Empty trinket tooltips are derived from the live inventory slot. Equipped-item details remain native; optional item-spell data is described as reported availability, not proof of a passive effect. Tests cover modern and legacy hooks, optional arguments/returns, personal edits, page changes, visibility, combat deferral, tooltip ownership and current item metadata.

The 0.4.2 runtime ZIP has the expected immediate `KeybindOptimizer/KeybindOptimizer.toc`; local integrity/manifest checks did not reproduce a missing TOC. The reported upload was identified only by version. New artifacts explicitly distinguish the CurseForge upload from developer source and validate the upload's root/TOC/load-file shape before publication. External CurseForge acceptance is not claimed.


## 0.4.4 follow-up — 2 November 2026

HoverBindingsUI is a separate UI extension loaded after the spellbook editor. It consumes the existing complete plan and stages edits through UI:AssignBinding, preserving reserved controls, Alt self-cast, linked form positions and collision confirmation. The scrollable grid retains all planned spell actions including future talents and configured ranks, independently of the keyboard's unavailable-spell filter. Hovering uses cached data; input does not rescan the spellbook. Done keeps the current draft; Apply & save uses the existing backed-up installation worker.

Input ownership was reviewed alongside the existing keyboard tester. Hover mode has its own keyboard sink and mouse-only world shield; neither exists on fresh login. Closing, page changes, combat and operation start release hover capture. Swap confirmation temporarily suspends the grid while retaining input interception and returns to the editor afterward. Geometry checks resolve viewport width before first layout and use responsive columns; rendering remains an approximation of the real game.

The reported fresh-character mouse failure was reproduced from saved account overrides that explicitly disabled BUTTON1 and BUTTON2. Current fresh initialization and binding-change events perform no binding writes; explicit Apply & save installs controls in the character set while preserving the account set. The local account file was backed up and only those two entries repaired while WoW was closed. This is an individual data repair, not an automatic account-reset feature in the distributed addon. The historical writer of the disabled entries was not proven.


### 0.4.4 current/recommendation separation

Opening Hot Swap now selects a read-only view of the actual game layout; tab navigation retains an explicitly selected view. Recommendation preview is a distinct temporary plan; saving it creates a uniquely named preset without installing it. Only an explicit Apply & save or configured preset activation performs the backed-up transaction. Saved-draft editing, spellbook changes and Hover bind are unavailable for current-game and unsaved recommendation views. Preview construction must restore temporary planning context even on failure and must not advance the saved preset counter.

The current reader includes native pet slots, commands, icons and reported autocast state. Existing hunter/warlock spell and command bindings remain part of presets; pet-bar slot ordering, autocast persistence and per-pet layout storage are not implemented. The private account-file repair described above is excluded from runtime and release artifacts. Final review and regression results for this flow are recorded by the release validation step; live-client acceptance remains required.
