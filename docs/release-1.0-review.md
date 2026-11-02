# Hot Swap 1.0 release review

Reviewed 2026-11-02 against the requested opening, editing, macro, transfer, recovery and compatibility behavior. Three parallel reviewers owned UI/design, preset transfer, and the binding engine; the integrating reviewer checked cross-feature behavior, release artifacts and documentation. Follow-up review examined changes across ownership boundaries rather than accepting each implementation in isolation.

## Findings resolved

| Priority | Finding | Resolution and evidence |
| --- | --- | --- |
| High | Import replaced the selected working settings | Add imported drafts without switching selection; round trips explicitly select the result, preservation tests assert table identity |
| High | Import could partially publish after a validation exception | Stage the collection and IDs, validate, then publish; injected failures leave originals intact |
| High | Ordinary future preset spells used placeholder macros | Empty owned reservations and learned-action maintenance; rank/talent/slot ownership tests |
| High | Old overflow preference allowed new account macros | Character-only creation and budget enforcement even for legacy imports; personal macro preservation and capacity failure tests |
| High | Full learned Era Druid could exceed the character cap with automatic utility form cancellation | New default leaves optional utility cancellation off; existing preferences remain; explicit opt-in still checks capacity |
| High | Replacement confirmation could overwrite a destination changed after review | Revalidate key command, action slot/content, source and combat state on acceptance; three stale-review regressions |
| Medium | No actual Blizzard-default binding reset | Confirmed, backup-first character reset; undo, account preservation, combat rejection and save-failure rollback tests |
| Medium | Successful default reset retained stale recovery flags | Clear recovery state after successful reset; regression covers quarantined state |
| Medium | Native spellbook drag/drop was absent and mouse shield blocked the book | Resolve native cursor payloads through the staged edit path; suspend outside mouse shielding while the native book is visible |
| Medium | Replacement and swap prompts were not independently configurable | Two local switches, enabled initially; restore/reset confirmations remain mandatory |
| Medium | Imported shortcut could leave the cached preview stale | Invalidate planning when a retained imported shortcut changes reserved keys; preserve current settings |
| Medium | External text formatting caused avoidable import failures | UTF-8 BOM, CRLF and surrounding whitespace normalization, bounded input and finite numeric validation |
| Medium | Export could exceed its own import limits | Reject oversized collections with selected-preset export guidance |
| Medium | Supported addon button bindings lacked native slot display | Read allowlisted live action-button attributes; preserve the original command and reject non-action buttons |

## Review coverage

The engine review covers preflight, asynchronous writes, rollback, account versus character binding persistence, macro identity/capacity, rank and talent transitions, empty reservations and manual-edit preservation. UI review covers opening Current, draft separation, spellbook drop/cancel paths, input capture, hover binding, confirmations, recovery actions, settings and geometry. Transfer review covers format bounds, non-executable parsing, class checks, duplicate names/IDs/shortcuts, export symmetry, local settings and atomic failure behavior.

Existing regressions also exercise item availability and targeting, form/page transitions, pet actions, fresh-character no-write behavior, unsupported focus controls, protected movement/chat/mouse commands, error logging, backup restoration, account bindings, macro index reordering and reload in a fresh Lua VM. The integration additions exercise twelve edit/apply/import/reopen cycles followed by restoring the oldest backup, combat rejection without later installing a draft, and a deterministic corpus of 263 malformed payloads with no state changes or execution.

The untouched starting commit passed **458/458** tests. Final build counts and full output are recorded in the generated `docs/validation.md` and developer archive `test-results.txt`. Seven packaging regressions cover TOC placement, missing files, extra addon roots, traversal, and source-archive rejection. Packaging checks ZIP CRCs, exact manifests and SHA-256 hashes.

With all catalog families learned simultaneously and the new defaults, Era macro demand was Druid 29, Mage 9, Warrior 3, Rogue 4, Hunter 21, Priest 24, Paladin 26, Shaman 12 and Warlock 26 out of 30 empty character slots. This deliberately includes talents that cannot normally coexist; personal character macros reduce the available capacity.

Test capacity is explicit: oversized full-catalog transaction fixtures use a named synthetic character-bank capacity to isolate rollback/identity behavior. Real 30-slot tests remain separate and cover starting classes, full learned Era catalogs, exhausted banks, and character-only creation. Passing a synthetic-capacity scenario is not evidence that the same layout fits a real client.

The UI geometry harness emits 29 states using actual Lua frame construction with substitute artwork/fonts. Reviewed screenshots and detailed reviewer records are in the repository's `review/1.0-*` files. The harness client version is set consistently to Era rather than selecting an Era catalog on a Forever-capability mock.

## Compatibility evidence and limits

Bartender maps native commands to action buttons and uses override bindings, including its `Keybind` click token. This supports using native slots where possible and preserving addon-owned overrides rather than rewriting its configuration. [Bartender primary source](https://raw.githubusercontent.com/Nevcairiel/Bartender4/master/ActionBars.lua).

The adapter reads recognized Bartender/Dominos-style button frames only when they expose an action slot; unknown/custom macro frames remain ordinary commands. This is a bounded compatibility improvement, not certification of either addon. Their custom paging and override state can supersede the saved binding map. Neither addon is installed in the inspected Classic Era AddOns folder, so real integration remains a user-test item.

The release does not claim live taint-free execution, correct physical key routing on every client, exact Blizzard font/texture rendering, actual casting, or server-specific behavior based on mocks. The full Forever conditional Druid fixture can exceed the character macro cap; the addon reports this safely and the user must reduce conditional actions or free slots. Existing presets retain their form-cancellation preference and can likewise require adjustment. The immediate installed test target is Classic Era.

## Release decision

Version 1.0.0 is prepared for the requested local Classic Era user testing, with the current behavior contract in [behavior.md](behavior.md). Public publishing and live-client certification are not part of this release action. Use the acceptance sequence to record actual in-game results before treating compatibility as verified.
