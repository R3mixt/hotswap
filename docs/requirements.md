# Requirement map — 0.4.4 beta

The final release targets WoW Forever. Classic Era / Hardcore is the temporary development target. Retail is not a supported release target. Automated tests use Lua 5.1 with mocked game APIs; a passing suite does not certify protected execution inside either client.

| Requirement | Implemented behavior | Boundary |
| --- | --- | --- |
| Feral leveling, stable keys across specs | One Druid layout, stable support keys and reserved talent positions | Recommendations are editable; no universal optimum is claimed |
| All classes and levels | Nine Era/Forever catalogs, future ability reservations and learned-spell coverage fallback | Current-client data determines names, icons, available ranks and actual knowledge |
| Original WoW action bars | Populates Blizzard main and extra bars; enables the bars it uses | No replacement combat bars; vehicle/override ownership remains Blizzard's |
| Action-bar visibility settings | Setup lists required, optional and unsupported bars; optional choices persist per preset and transfer in exports | Required bars always enable; hidden frames remain available; delayed settings refresh respects combat |
| Correct Druid pages | Base, Cat, Bear and Moonkin native pages | Prowl stays Cat; Travel/Aquatic use Base; changing a position's key updates every linked page |
| Current-game view | Opening Hot Swap shows actual installed commands, native icons and bound pet-slot actions | Read-only; never substitutes recommended or unapplied actions |
| Recommendation preview | Presets → Preview recommendations shows a separate temporary layout | No saved preset, ID counter, macro, backup or live-binding mutation |
| Save recommendations | Save as new preset creates a unique editable copy while preserving existing presets | A separate explicit Apply & save is required to install it |
| Complete preset modes | Create, duplicate, rename, delete, edit and activate complete layouts on Presets tab | No fixed preset count; individual layouts and import payloads have defensive size bounds |
| Preset shortcuts | A global activation key per named preset | Out of combat; all saved modes participate in shortcut conflict checks |
| Preserve unrelated controls | Apply updates only keys explicitly assigned by the selected preset; unrelated bindings and mouse controls remain unchanged | An explicit new assignment takes precedence on that key |
| Fresh-character controls | Login without an enabled applied plan performs no binding writes and creates no editor input capture | Inherited account customizations or missing controls persist; explicit Apply & save saves character bindings without automatic account repair |
| Protect game controls | Preset checkboxes for movement, camera, chat, targeting, interface and casting settings; Spells only enables all | Protects current custom keys; pinned conflicts block Apply rather than overriding the control |
| Macro display | Separate native macro-name and tooltip-code switches | Character-local; cosmetic native fontstrings only, deferred during combat |
| Macro storage | Generated macros use character-specific slots first; per-preset account-wide overflow is opt-in under Settings → Action bars | Existing owned account macros are reused, not migrated; personal macros are never overwritten |
| Macro capacity | Deduplicated budget; low space reserves future keys/editor metadata with empty native positions and fills managed positions outside combat when learned | Visibility preferences stay unchanged; learned layouts may still need freed slots or explicit account overflow |
| Unavailable abilities | L/T badges, native tooltips, editor filter and optional empty native positions | Native empty-grid borders follow Blizzard settings; keys remain reserved |
| Talent key modes | Own key per ability (default), or explicit ordered shared choices; first learned wins | Outside combat; no rotation decisions or guessed dominant specialization; separate existing keys remain |
| Release previous Hot Swap keys | A key no longer used by the addon regains its prior binding only while its current command still matches Hot Swap's last assignment | Later manual changes are preserved |
| Apply and recover safely | Bounded apply/rollback jobs, progress, named backups and original recovery | Combat pauses an active job; recovery errors retain the backup |
| Named backups | Character-class-date-time names; bindings, native bars, visibility, settings and owned macro data | WoW persists SavedVariables on reload/logout |
| Import/export page | Data-only transfer, duplicate-name merging and class validation | Copy/paste to a local file; addons cannot write arbitrary external files |
| Professional native UI | Game fonts, frames, tooltips, tabs and action-slot artwork | Geometry previews approximate artwork; final alignment needs client verification |
| QWERTY viewer and editor | Current bindings are read-only; saved drafts expose spell/item icons, modifier layers, form following, click-to-rebind and searchable list | Unavailable abilities have a distinct state; missing database metadata uses a named fallback |
| Hover bind editor | Saved-draft-only scrollable grouped grid of planned spells, future talents and custom ranks; hover then press a key, Shift/Ctrl combination, side button or wheel | Alt and primary clicks reserved; existing protection, collision and linked-form rules apply; Done keeps the draft and Apply installs with a backup |
| Hover input ownership | Consumes gameplay input without casting while active; Escape exits the current confirmation before the mode | Close, page change, operations and combat release capture; wheel over a spell binds while blank space scrolls |
| Preview-only testing | Highlights the pressed combination and action from the selected current/draft/recommendation view while consuming input | Releases on close/combat; client input routing needs verification |
| Miniature spellbook | Specialization/skill categories, talents, search and Show ranks | Exact ranks come from client metadata; future rank tables are not invented |
| Bind anything supported | Spells, items, game commands, chat, emotes and user/generated macros | Referenced macros must exist locally and match their reviewed body |
| Drag and drop | Entries replace the selected key/page or create a new action | Staged changes; no casting while dragging; occupied replacement requires confirmation |
| Target editing | Applicable target, mouseover, focus, self and ground modes with badges/tooltips | Alt-self takes precedence |
| Mouse configuration | Records observed side-button inputs; separate wheel and middle options | WoW does not expose reliable physical mouse-model/button-count enumeration |
| Shared familiar controls | Shift/Ctrl layers, F/G defensive roles, T/Shift-T trinkets, grave mount | Alt-self except Alt-wheel camera and Alt-grave autorun |
| Pet controls | Live native pet-slot display; hunter/warlock pet spell families and attack/follow/passive bindings | Pet-slot ordering, autocast state and per-pet layouts are not saved or restored by presets |
| Equipment slots | Trinkets use slots 13/14; scans equipment/bags for usable items | Passive equipment does not acquire an on-use effect |
| Clear item bindings | Keys, current selections, availability and saved alternatives | Alternatives are manual; absent selected items become usable when present |
| Item targeting | Verified friendly/hostile unit modes; food self-use and mortar ground use | Unknown items expose default only; no guessed capability |
| Portable item choices | Item IDs, alternatives and target edits carry in presets/imports | No automatic equipment swap when activating a binding preset |
| Food/water | May be selected and bound as inventory items | Automatic best-food/water selection is **not implemented** |
| Diagnostic logging | Opt-in, off by default, bounded saved history with operations, key/command/stage, backups, recovery outcomes and bounded stacks | Hot Swap errors only; copy/clear controls; persisted by WoW on reload/logout |
| Local window preferences | Settings tab with opacity, scale, viewport fitting and Reset appearance | Character-local; independent of shared binding presets |
| Readable failure details | Persistent selectable opaque Details dialog with explicit outcome and backup | Independent of window opacity; current-session last error stays available even if logging is disabled |
| Native command capability | Registry-based preflight before action writes; unavailable defaults omitted | Explicit unsupported focus targets need review rather than silent retargeting |
| Settings/menu entry points | AddOns settings category, Escape menu and `/hotswap` | Separate client menu adapters |
| Escape during recording | Cancels capture before closing the main window | Modal tests pass; client retest required |
| Avoid script timeout | Bounded jobs, cached previews/catalogs and coalesced events | Individual game API calls cannot be interrupted; client retest required |
| Learned-action maintenance | Owned form/item macros, enabled availability/talent choices and capacity-reserved future spells refresh outside combat without key churn | Capacity checks still apply; new uncatalogued families need reviewed Apply; manual slot/key edits are preserved |
| Expert research | Dated primary-source report distinguishes evidence from proposals | Complete 20-player keymap census remains incomplete |
| Maintainability | Separate client API, data, planning, native bars, transactions, presets and UI | Architecture and review records describe invariants and live checks |
| Distribution | Portable build, validation workflow, release notes and CurseForge materials | Public availability requires author sign-in, upload and moderation |

Use the acceptance sequence in [compatibility.md](compatibility.md) before promoting the beta to stable.
