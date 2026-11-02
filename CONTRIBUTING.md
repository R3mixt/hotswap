# Working on Hot Swap

Hot Swap is available under the [MIT license](LICENSE). Preserve its copyright and license notice when redistributing substantial portions of the code.

## Bug reports

Open a GitHub issue with the addon version, exact client/build, class/level/form, other action-bar addons, the key involved, expected behavior and steps to reproduce. Include whether it happened in Current or a preset draft, during combat, after learning a spell, or following a reload.

For operation failures, copy **Details**. Optional **Settings → Diagnostics** logging can help reproduce a problem. Share the copied diagnostic text, not a complete SavedVariables file containing your presets and backups. Never post tokens or account credentials.

## Local workflow

1. Install Python 3.13 and the pinned `requirements-dev.txt` dependency.
2. Make a focused change on a branch. Keep actual bindings, staged edits and preset recommendations distinct.
3. Add a regression for behavior changes, especially rollback, ownership, combat deferral or malformed imports.
4. Run `python tests/run_tests.py` and `python -m unittest discover -s tests -p "test_*.py"`.
5. Run `python package.py` before preparing a release. Update Core/TOC versions and release notes together.
6. Describe what changed, why, automated validation and any client checks still needed.

## Module map

| Area | Modules |
| --- | --- |
| State and lifecycle | Core, Profiles, Presets |
| Live view and editing | CurrentBindings, UI, LibraryUI, HoverBindingsUI |
| Planning and game writes | Planner, Engine, NativeBars, API, Protection |
| Learning, talents and macros | Availability, AvailabilityEngine, TalentBindings, Macros |
| Items and diagnostics | Items, ItemsUI, Diagnostics, SettingsUI, Launcher |

The TOC controls module order; the packager checks an explicit allowlist. Do not add runtime dependencies accidentally through build tooling.

## Invariants worth preserving

- Reading, opening and importing never apply game bindings.
- Protected writes stay out of combat and use the backed-up transaction path.
- Maintenance updates owned installed state, not an unapplied draft or a user's later manual replacement.
- New generated macros are character-specific; personal macros are not overwritten.
- Import is bounded data parsing, never Lua evaluation.
- Actual game API behavior takes precedence over mock convenience. Synthetic macro capacity is only for transaction fixtures; dedicated real-limit tests remain mandatory.

The UI geometry harness is `ui-qa/capture.py` plus `ui-qa/render.ps1` on Windows. Label its outputs as mock previews. Never claim a live-client pass from those images or the Lua API mocks.

Backups, SavedVariables, local dependencies, credentials and generated install receipts are excluded from version control. Preserve those exclusions when adding build or publishing scripts.
