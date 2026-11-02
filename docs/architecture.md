# Hot Swap architecture — 0.4.2

Hot Swap prepares a binding layout, then installs it onto Blizzard's original bars outside combat. Planning and editing never mutate live game bindings. There are no custom combat bars or rotation decisions.

## Modules

| Module | Responsibility |
| --- | --- |
| Core | SavedVariables migration, settings, events and public entry points |
| Diagnostics | Opt-in bounded per-character error/operation records and copyable export; preserves prior error handler |
| Protection | Classify game controls and reserve existing keys for checked categories |
| Availability / TalentBindings | Learned/talent presentation and validated ordered shared-key choices |
| AvailabilityEngine | Bounded owned-slot refresh using the installed layout, separate from draft edits |
| API | Client feature detection, localized spell/item metadata and game API wrappers |
| Profiles / LibraryData | Stable class IDs, recommended keys and display-only specialization/talent metadata |
| Macros | Supported target, form, rank and item macro bodies |
| Items | Inventory capabilities, explicit choices/alternatives and equipment operations |
| Library | Typed entries, filtering, placement and editable target capabilities |
| NativeBars | Map to Blizzard pages/slots; placement, snapshots and visibility |
| Planner | Resolve knowledge, reserve future positions, cover learned actions and validate the plan |
| Engine | Bounded apply, recovery, rollback and maintenance jobs; macro ownership |
| Presets | Complete drafts, activation shortcuts, backups and data-only transfer |
| UI / LibraryUI / ItemsUI / SettingsUI | Main configuration, spellbook/target and item editors, local appearance/log controls |
| Launcher | Native settings and Escape-menu integration |

Each Lua module receives the shared `K` namespace through addon varargs. The TOC defines load order. Python is for development only.

## Data and flow

1. The selected preset holds editable settings. Stable action IDs connect bindings, overrides and item alternatives; preset IDs survive renames.
2. Planner resolves current-client metadata. Display metadata is separate from learned eligibility. Future actions reserve positions without becoming usable.
3. NativeBars assigns main positions and available extra slots. A main position has one key across form pages. A spell edit changes the selected page; a key edit changes every linked page. Overflow uses ordinary macro bindings after capacity validation.
4. Engine preflight checks combat, supported native commands/focus capability, capacity and shortcut overlap; snapshot preparation validates cursor state and restorable action types. Snapshot reads finish before the named backup is stored and live writes begin.
5. A frame worker advances small steps with time and operation budgets: macros, native actions, planned bindings, release of previously owned keys, settings save and completion verification. Recovery uses the same mechanism.
6. The applied plan is separate from the draft. Inventory and form maintenance use applied settings; an event cannot silently install an edited draft item choice.

`bindingOverrides` maps action IDs to keys. `actionOverrides` holds rank, targeting and replacement edits. `customActions` contains typed spell/item/system/emote/macro-reference descriptors. `itemBindings` holds a selected item ID, ordered alternatives, target mode and explicit empty state. UI calls these domain methods rather than constructing executable text.

Apply merges planned keys into the captured live binding map. `appliedPlan.bindingOwnership[key]` records the installed command and the command it displaced, with false representing an unbound key. If a later preset releases that key, the displaced command is restored only while the live command still matches Hot Swap's owned command. Personal edits and unrelated shortcuts remain. Explicit Restore and rollback continue to recover full saved binding maps; they are not scoped Apply operations.

The visible binding registry omits some valid hidden commands. `API.HiddenMouseCommands` contains only the two source-verified native camera/turn commands. Captures supplement enumeration with all aliases from `GetBindingKey` and direct BUTTON1/BUTTON2 reads, preserving custom and unbound states. Expected/owned key probes also cover commands absent from enumeration. A read failure stops snapshot preparation rather than inventing bindings.

Snapshots and applied plans use `mouseBindingsVersion=1` after hidden mouse state is handled. Older snapshots cannot distinguish uncaptured mouse defaults from intentional unbinding: restore retains the current mouse controls and hidden aliases separately for each account/character binding set, supplying native defaults only when needed. Legacy installed layouts can receive a bounded, backed-up recovery of missing BUTTON1/BUTTON2 controls after combat; existing custom mouse actions remain untouched. New snapshots preserve intentional unbinding exactly.

`nativeBars` contains optional boolean visibility choices keyed by native toggle index 1–7 (displayed bars 2–8). Missing entries preserve unused bar visibility; planned occupancy always forces a required bar on. Visibility snapshots preserve every tuple position, including nil/legacy flags. Current Era/Forever proxy setters maintain a short-lived full-mask cache: capability-checked derived setters synchronize all bits before the final full-mask write. A bounded observer refreshes Blizzard frames from current mirrored values after server updates, pauses in combat, and never replays stale visibility writes.

## Macro capacity

`allowAccountMacros` is a per-preset boolean, default false, transferred through the validated settings format. Engine creates new generated macros in character-specific slots first. Account-wide slots are available only when this option is enabled; existing fingerprint-verified owned account macros remain reusable without migration. Personal macros and edited generated macros are never overwritten to free space.

`Macros:FitBudget` counts deduplicated new bodies against available slots. If the full plan exceeds that budget, `plan.deferFutureMacros` rebuilds native placements with unavailable spell slots empty and overflow reservations inert. Stable action IDs, keys and editor metadata remain intact; `capacityDeferredCount` supplies the informational Review/footer message. This does not mutate `hideUnavailableSpells`, `adaptTalents` or the local editor filter. AvailabilityEngine tracks this applied policy and populates owned positions outside combat when spells are learned, subject to capacity checks. A fully learned layout may still exceed the character bank; preflight rejects it before mutation rather than assuming every class fits 30 macros.

## Invariants

- Back up both binding sets, unsaved active bindings, native contents, page/visibility and managed settings before mutation. Never leave the inactive binding set selected across frames.
- Applying changes planned keys and releases only unchanged owned keys. Unrelated bindings survive; explicit full restore still recovers the saved maps.
- Preserve a pre-existing player cursor payload. After failed owned placement, release only the payload acquired by that operation before rollback.
- Preserve user-edited macros. Names and body fingerprints identify ownership; local macro references must still match at apply time.
- Macro indices are transient lookup results. Creation, deletion and renaming can reorder a bank; resolve the stable name and verify exact contents again at placement, direct binding, maintenance and rollback.
- Imports are data. Resolve spell names and exact ranks through client metadata; never compile imported display strings as macro syntax. Existing macros remain local references.
- Alt-self wins over friendly mouseover/focus clauses. Arbitrary macro references cannot inherit another native page's self-cast alias where semantics would be unsafe.
- Ground targeting is not unit targeting. Offer item unit modes only from verified capability data; unknown items retain default behavior.
- Missing items/talents retain inert reservations. Losing a form talent must not leave a macro that cancels form before failing.
- Apply, restore and mode switching cannot start in combat. Interrupted jobs report partial progress and resume after lockdown; do not claim completion early.
- Rendering/search use cached metadata and bounded lists. Invalidate relevant caches instead of rebuilding every saved preset on each input event.

## Extension and validation

Keep client API differences in API/NativeBars, not UI handlers. Add catalog entries with stable IDs and sourced spell IDs. Keep display categories separate from capability. Extend target modes through the shared capability/compiler path and test Alt behavior. Add settings through defaults, migration, import validation and export together.

Run `python tests/run_tests.py` after installing requirements-dev.txt. Tests execute actual modules in fresh Lua 5.1 VMs with mocked APIs. Failure injection covers partial apply, rollback, binding-set reads, cursor cleanup, macro edits and combat pauses. UI tests cover input ownership and staging. `ui-qa/capture.py` and `render.ps1` render actual frame geometry with approximate artwork; neither replaces the live-client checks in compatibility.md.

## Local diagnostics and preferences

`db.preferences` holds diagnostics (default false), windowOpacity and windowScale independently of preset data. Import/export, switching and recovery do not overwrite it. Effective scale fits the viewport without changing the stored preference. `db.diagnostics` holds at most 200 records, each with a 3000-character message, timestamp, severity/event and a whitelist of short primitive context fields. There are no raw macro/preset dumps or network operations.

Engine logs transitions rather than every mutation. Scoped protected calls capture a bounded stack only while diagnostics are enabled. Logger failures cannot interrupt a transaction. The opt-in global wrapper only records errors identifying Hot Swap and always forwards to the previous handler. Disabling restores that handler only while Hot Swap is still the outermost wrapper; an intervening addon's chain keeps an inactive pass-through wrapper. SavedVariables persist on normal reload/logout.

Client command capabilities are cached separately from assigned keys and invalidated by UPDATE_BINDINGS. Apply forces a fresh registry read before mutation. The Engine only permits generated preset CLICK commands after validating their stable identity; imported macro references follow the fingerprint-verified macro path. Restoring a baseline preserves arbitrary original commands. Restoring an enabled named backup checks saved preset identities, including modes that recovery will resurrect, without changing current state before backup.

## Control and spell-availability options

Protection classifies the currently bound command, not a hard-coded default key. It reads the visible registry and hidden mouse aliases, reserves selected categories before allocation, and is checked again before installation. Previously managed keys that become protected are retained and released from addon ownership. Casting protection suppresses only casting modifier/CVar changes; explicit action-bar visibility remains part of the spell layout.

`talentAlternatives[actionID]` is an ordered list of at most eight catalog IDs. Validation rejects foreign classes, duplicate/invalid entries, fixed-rank/replacement conflicts and target modes unsupported by any alternative. The primary may be reordered or removed. The first learned source supplies the ability while the destination ID/key/page stays stable. Any helpful choice reserves its Alt-self alias for the entire list; non-helpful selections block that alias. Other bindings remain independent. Transfer uses typed `t` records and never imports macro code.

`hideUnavailableSpells` leaves unknown native placements empty; `adaptTalents` limits that behavior to catalog talent abilities. Hidden overflow reserves its key with an inert shared macro, since there is no native empty slot to bind. The game still owns frame/grid visibility. Availability maintenance uses applied settings, verifies ownership before touching slots/keys, and preserves personal changes. It runs through the existing bounded worker and waits out combat. No selection or protected configuration happens during combat.

Local `showMacroNames`, `showMacroCode` and `showUnavailableBindings` preferences default true and stay outside presets. Native macro labels use only original button fontstring alpha with post-update hooks; disabling labels never hides a secure action button. Settings is split into four native subsections while the main tab count stays unchanged.

Talent-key mode uses the existing data model: no `talentAlternatives` entry means Own key; an entry means Shared key. Switching to Own key removes only that choice policy, retaining independent `bindingOverrides`. Unknown catalog talents use inert tooltip-only managed macros or empty native reservations under visibility/capacity policy. Separate learned talent transitions use bounded owned updates.
