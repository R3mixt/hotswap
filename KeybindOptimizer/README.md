# Hot Swap 0.4.8

A configurable World of Warcraft addon for stable class bindings, druid form pages, mouseover/focus macros, Alt self-cast, and selectable on-use items.

**Status: installable beta.** Version 0.4.8 opens Current bindings in edit mode with the spellbook open. Click to rebind, or drag any spell or item onto a key, including unlearned abilities or missing items. Apply changes backs up and installs only your edits; Discard edits removes pending changes. Prefilled drafts remain separate. Saving a recommendation or applying an edited draft prompts you to overwrite the selected preset or save as new. The scrollable Hover bind editor edits Current or preset drafts without casting. Generated native buttons retain readable action labels and explanatory trinket tooltips. Generated macros remain character-specific by default, with future spell positions reserved when space is limited. Account-wide overflow is an explicit preset option. Bindings and mouse controls outside the selected preset remain unchanged. The actual Lua modules are checked using Lua 5.1 and mocked WoW APIs; real-client behavior still needs a retest. Geometry previews approximate artwork and fonts and are not game screenshots.

## Install and open

1. Extract the `KeybindOptimizer` folder into the game's `Interface/AddOns` folder. The `.toc` file must be directly inside `Interface/AddOns/KeybindOptimizer/`.
2. Use the client folder you intend to test: `_classic_era_` for Era / Hardcore or the Forever client folder when available. Do not install into a different client's AddOns folder.
3. Restart WoW if it was running while a new addon folder was installed. Enable Hot Swap at character selection.
4. Open **Hot Swap** from the Escape menu or **Options → AddOns → Hot Swap → Open Hot Swap**. `/hotswap` also works. Select the client automatically or explicitly, record your side buttons, and choose whether to use the wheel and middle click.
5. Open **Bindings** to inspect your actual controls. On **Presets**, choose **Preview recommendations** to inspect a proposed layout without saving or applying it. Choose **Save preset...**, then **Overwrite selected** or **Save as new**. Edit that saved draft in **Bindings**, **Setup**, and **Items**, then choose **Apply & save** outside combat.

Opening the window or selecting a preset does not change live bindings. **Apply & save** records a named backup first, creates the needed macros, populates the original action bars, enables required extra bars, updates the keys explicitly assigned by the preset, sets self-cast options unless protected, and saves character bindings. Unrelated bindings and mouse controls remain unchanged. No outside application, subscription, or library is required to run the addon.

When a new layout stops using a key previously assigned by Hot Swap, the addon restores that key's earlier binding only if its current binding still matches Hot Swap's last assignment. If you changed the key yourself afterward, that change is preserved. An explicitly assigned key in the new preset still takes precedence; Review lists those expected replacements.

In **Setup → Action bars**, see which original bars the preset requires and choose whether to show other available bars. Required bars always turn on; an unchecked unused bar can be hidden. **Use defaults** clears optional choices so unused bars retain their current visibility. Changes are saved in the preset and take effect with **Apply & save**. Hidden bars remain selectable; bars absent from the client are marked unavailable. Visibility may take a moment to update while WoW receives its settings from the server.

Wait for the progress indicator to finish. You may close the window while the operation continues. An operation cannot start in combat; if combat begins during setup, the partly completed operation pauses and resumes afterward. Automatic rollback and named recovery use the same bounded worker. The original backup is retained if recovery cannot finish.

The addon is displayed as **Hot Swap**. Its existing `KeybindOptimizer` install folder and saved-data identifiers are retained for compatibility. `/hotswap` opens the interface; `/kbo` remains an alias. Existing settings and item presets migrate to complete presets automatically.

## Presets and mode shortcuts

The **Presets** tab manages complete setups: spell and system bindings, mouse options, self-cast settings, selected items and saved equipment. Create, duplicate, rename and delete custom modes without a fixed number of slots. Each saved preset retains edits as you make them. **Editing** identifies the selected draft; **Active** identifies the layout currently installed in the game. Recommendation previews are temporary: merely opening one creates no preset, consumes no preset ID and changes no game controls. **Save preset...** offers **Overwrite selected** (keeps its identity and shortcut) or **Save as new** (asks for a unique name and keeps the original saved version). Cancel changes neither saved version nor game controls. Draft edits are retained across reloads until you make this save choice.

Set a **Hot Swap key** for each preset, then use a preset to install updated shortcuts. Shortcuts stay available across modes and follow renames. A shortcut cannot overlap another preset shortcut or a planned action in any saved mode. Switching uses the same fresh validation, named backup and rollback process as the button. Switching is unavailable in combat and is not queued to fire later. Repeating an unchanged active mode does not create another backup.

Existing game bindings on keys assigned by the selected preset are **expected replacements**, not errors. Other keys remain unchanged. The optional **Review** window starts with replacement details collapsed and uses readable action names. Actual duplicate assignments or unavailable macro capacity still block installation.

## Import, export and external files

Use the separate **Import / export** tab to export the selected preset or all presets. Choose **Select to copy**, press Ctrl+C, and share the text. To save an external file, paste it into a text editor and save it with a `.hotswap` extension. WoW addons cannot write arbitrary external files directly.

To import someone else's settings, open their file, copy its text, paste it into the tab and choose **Import presets**. Imports add saved presets for review; they do not activate bindings. Existing names are preserved, with imported duplicates named `Name (2)`, `Name (3)`, and so on. Current exports include a class check; conflicting imported mode shortcuts are left unassigned. Exported data contains settings, not executable Lua, macros, backups or account credentials. The earlier KBO1 format remains importable.

## In-game interface

The seven tabs are **Setup**, **Presets**, **Bindings**, **Items**, **Backups**, **Import / export**, and **Settings**. The interface uses the game's own frame, button, checkbox, scrollbar and action-slot artwork, game fonts, gold headings and native tooltips. Advanced options stay collapsed until needed. Combat actions use Blizzard's original bars and their own cooldowns, tooltips and hotkey labels.

All artwork is referenced from the installed game; there is no browser, web UI, bundled replacement font, or external skin dependency. Geometry previews use approximate artwork and fonts, so the exact client rendering still needs an in-game check.

The Bindings page opens on **Current**, an editable QWERTY view of your actual game bindings, native action icons and pet controls. It returns to Current each time you open Hot Swap; navigating between tabs keeps an explicitly selected editing view. Select a saved preset draft explicitly to edit it. Recommendation previews are read-only until saved. Current edits stay saved across reloads until Apply changes or Discard edits. Current starts from your actual controls and never imports recommended keys. Use Hover bind for the full class spell catalog, including unlearned spells. Future spell and missing-item reservations use character macros when needed and become usable when you learn or acquire the ability or item. Normal macro-space limits apply; insufficient space leaves your edits saved without changing your controls. The spellbook Items tab also accepts an item ID. Current follows the active native action page. In a draft or recommendation, **Follow form** follows your form; choosing an Action page pins the preview without shifting your character. Hold Shift, Ctrl, Alt, or a combination to inspect that modifier layer. Current shows the actual bindings on that layer; recommended layouts reserve Alt for self-cast and the camera/auto-run controls. Layer buttons also let you inspect a layer without holding a key. Press a combination to highlight its keys and display the action from the selected view. Current displays what is installed; a draft or recommendation displays only its proposed actions. Testing does not cast or apply anything and ends when combat starts.

While editing a saved preset draft, click an occupied key or icon to begin rebinding immediately. Current-game and recommendation views do not open rebinding controls. Each main-bar position uses one key across every native form page, so rebinding updates the linked position on all pages. Empty keys open a searchable action picker. The detail panel retains **Change action** and **Reset key**. Compatible swaps require confirmation; incompatible collisions are blocked. All changes stay staged until **Apply & save**. The **List** view and search retain access to every action, including bindings outside the displayed keyboard/mouse controls.

For faster editing of a saved preset draft, choose **Bindings → Hover bind**. It is unavailable in Current and unsaved recommendation views. Its scrollable grid shows all planned spell bindings, grouped by form and specialization / skill line, including future talents, form-specific abilities and custom ranks. Entries remain available here even when the normal editor hides unavailable spells. Hover an ability and press a key, a Shift/Ctrl combination, a side mouse button or the wheel to stage its binding. Alt and the primary left/right mouse clicks remain reserved; movement and protected-control restrictions still apply. The wheel binds when over a spell and scrolls when over blank grid space.

Hover bind uses the same linked form positions and collision checks as the keyboard editor. **Done - keep draft** exits without installing changes; **Apply & save** installs the edited preset with a named backup. No spells cast while the mode is active. Escape dismisses a confirmation first, then leaves Hover bind. Closing the window, changing pages, starting an operation or entering combat releases its input capture.

While editing a saved preset draft, open **Spellbook** beside the keyboard to browse spells by specialization / skill line, including reserved talent abilities. Separate sections list game commands, chat controls, emotes, and existing user or generated macros. Drag an entry onto a key, or select it and click the destination. Dragging only edits the preset and never casts the action. **Show ranks** exposes ranks identified in the current client; choosing one permits a separate downrank binding alongside the highest-rank family entry. Rankless spells do not acquire invented ranks, and future ranks absent from current-client data cannot be safely enumerated.

The binding editor offers supported targeting modes, such as target, mouseover, focus and self, with a small badge and tooltip. Helpful spells preserve Alt-self precedence where allowed. Existing macro references preserve their text; missing or changed macros are reported for review instead of silently recreated. Targeting controls do not rewrite arbitrary user macro text.

Unlearned spells use the current client's spell database for their real icon and native tooltip. Amber **L** marks ordinary unlearned spells; blue **T** marks a talent ability that is not learned. You can rebind them before learning them; display metadata never makes an unlearned action castable. A spell absent from this client's database retains a named placeholder rather than borrowing a different expansion's spell. Empty item slots identify the missing selection separately from unlearned spells.

Escape ends mouse recording or closes an action picker first, keeping the main window open. A subsequent Escape closes the main window. Opening the settings category or game-menu shortcut never applies a layout automatically.

The interface reuses its preview between relevant changes, updates only the visible page, filters item-data events, and redraws after Apply on a later frame. Apply still runs fresh validation before modifying bindings.

## Settings and troubleshooting

If automatic form maintenance fails, Hot Swap retains your personal bindings and bar edits, saves a recovery backup, and disables only unchanged owned form-dependent macros. A persistent recovery notice asks you to review and explicitly Apply a preset or restore a backup. Personally edited macros remain yours. Recovery work waits out combat; it never silently restores the entire original setup.


**Settings → Controls** lets each preset preserve movement, camera/selection, chat, targeting, other interface controls, and casting settings. **Spells only** checks all six. Checked categories keep their existing keys, including custom remaps; automatic spell assignments choose another free key. A manually pinned spell on a protected key must be changed before Apply. Unrelated keys are preserved regardless of these checkboxes. Protection takes effect with **Apply & save** and travels with preset exports.

**Settings → Action bars** includes **Hide unavailable spells on action bars**, which leaves unknown spell slots empty, and **Adapt to learned talents**, which does this for talent abilities only. Slots and keys stay reserved. Learning or resetting talents refreshes the applied layout outside combat, without applying draft edits or overwriting personal bar changes. Blizzard's **Always Show Action Bars** setting may still show empty button borders; Hot Swap does not hide protected native button frames.

Native buttons show readable action labels instead of internal macro IDs. T shows **Trinket 1** (upper slot 13), and Shift-T shows **Trinket 2** (lower slot 14). Empty-slot tooltips explain what belongs there; equipped-item tooltips retain Blizzard's item details. Macro names and bodies remain unchanged internally so existing bindings and backups stay valid.

Generated macros use character-specific slots by default. **Allow account-wide macro overflow** permits additional macros in the shared account bank when character slots are full. This is a per-preset option, saved in exports and installed with **Apply & save**. Existing owned account macros can still be reused; they are not automatically moved into character slots. Personal macros are never overwritten to make room.

When macro space is limited, Hot Swap first reserves future spell keys without creating a separate macro for every unlearned ability. Their icons and tooltips remain available in the editor unless you hide unavailable entries, while their native bar positions stay empty. Managed positions fill outside combat as spells are learned, subject to available macro space. Review explains the reservation count. This does not change your visibility preferences. A fully learned layout may still need more than 30 macros: free character slots or explicitly enable account-wide overflow if preflight reports insufficient capacity.

The same section has character-local display controls: **Show macro names on action buttons**, **Show macro code in Hot Swap tooltips**, and **Show unavailable spells in the editor**. They apply immediately and do not travel in shared presets. Macro-name changes defer while in combat. Hiding editor entries does not delete their bindings. All options retain prior behavior until changed.

**Bindings → Talent keys** offers **Own key** and **Shared key** for each eligible utility position. **Own key** is the default: every ability keeps its separate custom key, and a talent button stays inactive until the ability is learned. Choose **Change key** to set that ability's binding. **Shared key** uses an ordered list of up to eight abilities; the first learned choice wins. For example, a key can offer Moonkin Form, then Nature's Swiftness. If neither is learned, it stays inactive. Choices use actual learned abilities, not a guessed specialization. Switching back to Own key restores the original ability and retains every custom key override. Other independent bindings remain unchanged.

The choice is per binding and saved with each preset, so independent and shared keys can coexist. Import/export preserves both. Fixed-rank or replacement edits are separate choices; Default targeting supports alternatives with different target capabilities. **Apply & save** installs your choices. Learning or removing a talent updates its managed action outside combat without changing keys. Unlearned talent buttons contain no cast or form-cancellation command.

**Settings → Window** controls this character's window opacity (40–100%) and preferred scale (70–130%). Changes take effect immediately. The window reduces its effective scale when necessary to fit the screen and spellbook. **Reset appearance** restores the defaults. These preferences stay local when importing or switching binding presets.

**Settings → Diagnostics → Enable diagnostic logging** is off by default. Turn it on before reproducing a problem. It keeps the latest 200 Hot Swap entries, including setup phases, failures, key/command, backup identifier, rollback outcome and bounded stack traces when available. It captures uncaught errors that identify Hot Swap; it is not a general other-addon error collector and never replaces the game's existing error presentation. Logs do not contain raw preset exports or macro bodies from context fields and are never uploaded automatically.

Use **View / copy log → Select text → Ctrl+C** to share the output or paste it into an external text file. After reproducing, `/reload` or log out so WoW writes the log into this character's `SavedVariables/KeybindOptimizer.lua` file. The file also contains personal presets and backups; share the copied diagnostic text when you only want to share diagnostics. Disabling logging preserves existing entries; **Clear log** removes them.

Apply failures also have a full selectable **Details** view even when logging is off. Closing it keeps the last failure accessible; **Dismiss error** or a successful retry clears it. The message distinguishes a preflight rejection (nothing changed), a verified rollback, and recovery that still needs attention.

Classic Era omits unavailable default focus controls. Command support comes from the running client's binding registry, not the selected profile label. Explicit saved focus targeting is rejected for review instead of silently changing its target. Unsupported commands fail before backup or action-bar writes.

New characters can inherit custom or unbound controls from WoW's saved account bindings. Hot Swap does not write bindings or open an input-capture overlay on a fresh character's login; an inherited missing control can therefore remain missing until you explicitly change the bindings or apply a saved preset. Apply & save saves the chosen layout for that character and leaves the account binding map unchanged. Hot Swap does not automatically repair account binding files.

## Core behavior

- All nine Forever/Classic classes have curated profiles. The Druid layout is identical across specs; talent positions remain reserved when not learned.
- Druid uses the original Base, Moonkin, Cat and Bear pages. Prowl stays on Cat; Travel and Aquatic use Base. The combat bank uses `1–5`, `Shift-1–5`, `R`, and `Shift-R`. Support and emergency controls remain accessible from every form.
- Every distinct active spell found in the player's and current pet's spellbooks receives a binding. Passives are excluded. Uncatalogued spells receive stable fallback keys, clearly labeled **Additional spells**. These fallback placements are complete coverage, not a claim of expert optimization.
- Recommendations reserve future catalog families at every level, including talented abilities. Normal families use the highest learned rank; explicit downranks can be added from the spellbook. Existing keys stay stable when learning spells.
- Runtime form indices are discovered. Form and combination macros receive bounded maintenance outside combat when learned abilities change. If stale form guards cannot be repaired, original recovery is attempted. Native bar paging remains owned by Blizzard.
- Form selection uses a `noform` guard. Intentional Classic Era powershifting has a separate control; it is never triggered by repeatedly scrolling into the same form.
- Helpful spells use Alt-self, friendly mouseover, then friendly target. The optional final self fallback is off by default. Spells that cannot target self are excluded. Focus and resurrection macros have explicit target conditions.
- Simple learned spells use native spell actions. Targeting, exact ranks, forms and shared actions use stored macros when needed; future reservations can retain empty native slots to save macro space. Macros are deduplicated and checked against capacity and body-length limits. Personal macros are never overwritten to make room.
- Macro contents and the resulting bindings are verified. Applying a changed layout keeps the original rollback baseline.

## Pets

Current resolves bound native pet-slot commands to the pet bar's actual actions and icons when a pet is available. Hunter and warlock recommendations include pet abilities and attack, follow and passive commands; their spell and key edits belong to the preset. You can also bind supported native pet-slot commands through the spellbook's game-controls section.

Blizzard continues to control the pet bar. Hot Swap does **not** save or restore its slot order, autocast choices, pet identity or separate layouts for different pets. Switching a preset changes the saved keybindings and generated pet commands; it does not rearrange the pet bar or change autocast.

## Your recommended controls

| Input | Function |
| --- | --- |
| W / S | Forward / backward |
| A / D | Strafe left / right |
| F / G | Personal mitigation / emergency survival, as supported by the class |
| T / Shift-T | Equipped trinket slots 13 / 14 |
| Grave, the physical key left of 1 | Selected mount |
| Alt-grave | Auto-run |
| Alt-wheel up / down | Camera zoom |
| Shift-Space / Ctrl-Space | Selected Healthstone / healing potion |
| Ctrl-T | Selected on-use bag or equipped item |
| Middle / Shift-middle / Ctrl-middle | Leave form / set focus / clear focus (focus only on supporting clients) |
| I / J / K / P | Bags / character / spellbook / talents |
| M / L / O | Map / quest log / social |
| F1–F5 / F6 | Self and party selection / focus selection (focus only on supporting clients) |

With wheel abilities enabled, Druid uses wheel up/down for Bear/Cat, Shift-wheel for Travel/Aquatic, and Ctrl-wheel for Moonkin/Prowl. With wheel abilities disabled, normal zoom is restored and affected abilities receive keyboard or recorded-button alternatives. The Binding preview is authoritative for those replacements.

The Mage profile preserves Frostbolt on 1, Fireball on Shift-1, Ice Barrier on F, and Ice Block on G. Advanced options can swap the two filler keys. Pinned overrides remain explicit.

## Mouse calibration and customization

WoW reports input events but does not provide a documented physical mouse-button-count query. **Record side buttons** captures the buttons you press. Remapped firmware inputs may appear as keyboard keys; use a binding row's capture control for those inputs. Recorded extra side buttons become usable allocation capacity. The addon does not invent unavailable mouse buttons.

Click a binding's key to replace it. The override remains pinned until reset. Conflicting keys are reported before Apply. Alt gameplay bindings, the primary mouse buttons, and core movement/menu keys are protected from accidental reassignment. Alt-wheel and Alt-grave are the intended exceptions.

Hot Swap creates no custom combat bars. It populates and enables Blizzard's original bars. The previous native contents and visibility are included in recovery snapshots. Clients with fewer extra bars can use direct macro shortcuts for overflow. The addon does not rewrite ElvUI, Bartender, or Dominos profiles; their binding overrides may affect the result.

Vehicle, possession and override paging use the game's native dispatcher and the same linked main-position bindings.

## Items, mounts, and presets

**Items** starts with the keybinding. Choose a binding on the left to see its selected item, availability and saved alternatives. **Inventory** browses carried on-use candidates; **Saved choices** includes items you have saved even when absent. Select a row and choose **Use this item** to stage it, or add an item ID to save a future choice. Each key can retain up to 32 alternatives. Choices do not switch automatically. Clear empties the selection while preserving that list.

Items also appear in the miniature spellbook and can be dropped onto keyboard positions. The selected item and its alternatives belong to the preset and travel through import/export. Missing items remain bound with a clear inventory notice; their reserved macro is inert until a compatible usable item is available. The installed selection is refreshed outside combat without adopting newer staged item edits.

Target choices are item-specific. Verified friendly items such as bandages support friendly mouseover, focus, target and self modes; verified hostile devices support hostile unit modes. Food and self-use consumables offer no unit-target modes, and ground devices retain their targeting reticle. Unknown target types are labeled unverified and expose only the item's default behavior. Equipped trinket keys continue to follow slots 13 and 14; other selected bag items follow IDs when bags are sorted. Unequipped armor never equips itself through a use key.

**Leveling**, **Dungeon**, and **PvP** are starting presets; add any custom modes you need. Each stores its own utility, potion, Healthstone, mount and equipment selections along with the complete binding setup. **Capture equipment** records the current gear. **Equip saved** explicitly requests the saved set outside combat after checking availability. Activating a binding mode does not equip gear automatically. Shared cooldowns, equip cooldowns, location restrictions and normal item rules still apply.

For mounts, select a collected mount from the journal where supported, enter `spell:12345` for a learned mount spell, or choose a carried mount item. Mounting exits druid form intentionally. The mount key only attempts to mount when unmounted.

Item spell information identifies candidates, not tactical suitability. Confirm the item choice in the menu. Automatic best-food/water selection is not implemented. The addon never chooses consumables based on your health or autonomously triggers combat actions.

## Recovery and removal

- The **Backups** tab lists snapshots named Character-Class-YYYY-MM-DD HH:MM:SS. Each activation records bindings, original bar contents and visibility before its changes; restores record an undo snapshot. Same-second names receive a unique suffix. Account and character binding sets, self-cast settings and the previous Hot Swap layout are retained.
- **Restore selected** restores a named snapshot. **Restore original setup** or `/hotswap restore` restores the original bindings and affected self-cast settings. Original restore removes generated macros only when their name and body still match the addon's ownership record. A macro you edited is preserved.
- Backups are stored per character in SavedVariables. WoW writes them to disk on reload or logout. They are not silently pruned and are not included in shared exports.
- Run Restore **before deleting or disabling the addon** to recover the pre-addon setup. Old custom-dock backups remain stored, but a snapshot requiring that retired dock cannot be activated directly. Restore the original setup, then use a native-bar preset. Saved presets remain available for editing.
- If the addon cannot load, WoW's normal Key Bindings settings remain available through Escape. You can select your account bindings or reset the character bindings there.
- Presets remain available after restoring a backup. Imported settings remain drafts until explicitly used.

## Compatibility and evidence

The local installed targets used for planning were Forever `1.60.1.70707` and Era `1.15.9.70576`. The final release targets Forever; Era / Hardcore is the current test client. Retail and other Classic expansions are not supported release targets.

See `docs/research.md` for player-source evidence and version-specific decisions, `docs/requirements.md` for the implemented requirement map, and `docs/compatibility.md` for tests and required live-client checks.

The requested top-20 player comparison is **not complete**: the available primary sources establish useful practices, but do not supply 20 verified complete layouts. The addon does not market its defaults as a proven global optimum. New Forever spells without a verified ID use learned English names, while the spellbook fallback still covers unmatched localized actions.

## Development checks

The addon uses Lua 5.1 syntax and no runtime dependencies. Tests are in the separate source archive. From its root, install `requirements-dev.txt`, then run `python tests/run_tests.py`. Tests execute the actual modules with simulated game APIs; they do not replace real combat and input testing.
