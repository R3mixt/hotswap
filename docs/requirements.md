# Requirement map — 0.3.2 beta

The final release targets WoW Forever. Classic Era / Hardcore is the temporary development target. Retail is not a supported release target. Automated tests use Lua 5.1 with mocked game APIs; a passing suite does not certify protected execution inside either client.

| Requirement | Implemented behavior | Boundary |
| --- | --- | --- |
| Feral leveling, stable keys across specs | One Druid layout, stable support keys and reserved talent positions | Recommendations are editable; no universal optimum is claimed |
| All classes and levels | Nine Era/Forever catalogs, future ability reservations and learned-spell coverage fallback | Current-client data determines names, icons, available ranks and actual knowledge |
| Original WoW action bars | Populates Blizzard main and extra bars; enables the bars it uses | No replacement combat bars; vehicle/override ownership remains Blizzard's |
| Action-bar visibility settings | Setup lists required, optional and unsupported bars; optional choices persist per preset and transfer in exports | Required bars always enable; hidden frames remain available; delayed settings refresh respects combat |
| Correct Druid pages | Base, Cat, Bear and Moonkin native pages | Prowl stays Cat; Travel/Aquatic use Base; changing a position's key updates every linked page |
| Optimize button | Creates and activates a new optimized preset while retaining the previous preset | Validation and named backup precede live mutation |
| Complete preset modes | Create, duplicate, rename, delete, edit and activate complete layouts on Presets tab | No fixed preset count; individual layouts and import payloads have defensive size bounds |
| Preset shortcuts | A global activation key per named preset | Out of combat; all saved modes participate in shortcut conflict checks |
| Replace existing bindings safely | Bounded apply/rollback jobs, progress, named backups and original recovery | Combat pauses an active job; recovery errors retain the backup |
| Named backups | Character-class-date-time names; bindings, native bars, visibility, settings and owned macro data | WoW persists SavedVariables on reload/logout |
| Import/export page | Data-only transfer, duplicate-name merging and class validation | Copy/paste to a local file; addons cannot write arbitrary external files |
| Professional native UI | Game fonts, frames, tooltips, tabs and action-slot artwork | Geometry previews approximate artwork; final alignment needs client verification |
| QWERTY editor | Spell/item icons, modifier layers, form following, click-to-rebind and searchable list | Unavailable abilities have a distinct state; missing database metadata uses a named fallback |
| Preview-only testing | Highlights the pressed combination and planned action while consuming input | Releases on close/combat; client input routing needs verification |
| Miniature spellbook | Specialization/skill categories, talents, search and Show ranks | Exact ranks come from client metadata; future rank tables are not invented |
| Bind anything supported | Spells, items, game commands, chat, emotes and user/generated macros | Referenced macros must exist locally and match their reviewed body |
| Drag and drop | Entries replace the selected key/page or create a new action | Staged changes; no casting while dragging; occupied replacement requires confirmation |
| Target editing | Applicable target, mouseover, focus, self and ground modes with badges/tooltips | Alt-self takes precedence |
| Mouse configuration | Records observed side-button inputs; separate wheel and middle options | WoW does not expose reliable physical mouse-model/button-count enumeration |
| Shared familiar controls | Shift/Ctrl layers, F/G defensive roles, T/Shift-T trinkets, grave mount | Alt-self except Alt-wheel camera and Alt-grave autorun |
| Equipment slots | Trinkets use slots 13/14; scans equipment/bags for usable items | Passive equipment does not acquire an on-use effect |
| Clear item bindings | Keys, current selections, availability and saved alternatives | Alternatives are manual; absent selected items become usable when present |
| Item targeting | Verified friendly/hostile unit modes; food self-use and mortar ground use | Unknown items expose default only; no guessed capability |
| Portable item choices | Item IDs, alternatives and target edits carry in presets/imports | No automatic equipment swap when activating a binding preset |
| Food/water | May be selected and bound as inventory items | Automatic best-food/water selection is **not implemented** |
| Diagnostic logging | Opt-in, off by default, bounded saved history with operations, key/command/stage, backups, recovery outcomes and bounded stacks | Hot Swap errors only; copy/clear controls; persisted by WoW on reload/logout |
| Local window preferences | Settings tab with opacity, scale, viewport fitting and Reset appearance | Character-local; independent of shared binding presets |
| Readable failure details | Persistent selectable Details dialog with explicit outcome and backup | Current-session last error stays available even if logging is disabled |
| Native command capability | Registry-based preflight before action writes; unavailable defaults omitted | Explicit unsupported focus targets need review rather than silent retargeting |
| Settings/menu entry points | AddOns settings category, Escape menu and `/hotswap` | Separate client menu adapters |
| Escape during recording | Cancels capture before closing the main window | Modal tests pass; client retest required |
| Avoid script timeout | Bounded jobs, cached previews/catalogs and coalesced events | Individual game API calls cannot be interrupted; client retest required |
| Learned-action maintenance | Owned form/item macros refresh outside combat without key churn | New learned-family coverage can require reviewed Apply |
| Expert research | Dated primary-source report distinguishes evidence from proposals | Complete 20-player keymap census remains incomplete |
| Maintainability | Separate client API, data, planning, native bars, transactions, presets and UI | Architecture and review records describe invariants and live checks |
| Distribution | Portable build, validation workflow, release notes and CurseForge materials | Public availability requires author sign-in, upload and moderation |

Use the acceptance sequence in [compatibility.md](compatibility.md) before promoting the beta to stable.
