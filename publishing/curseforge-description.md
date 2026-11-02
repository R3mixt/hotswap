# Hot Swap

Build a comfortable keyboard layout, keep it consistent across your class, and switch saved setups when your playstyle changes.

Hot Swap places spells and generated macros on **Blizzard's original action bars**. Its in-game keyboard opens on your current game bindings in edit mode, including native pet controls. Build your own Current layout with the spellbook or Hover bind, including future spells and missing items. Future reservations do not consume macro slots. Saved preset drafts provide a separate editor for Shift and Ctrl layers, mouse buttons, and optional wheel bindings. The interface uses WoW's own frames and controls.

**1.0.0 user-test build:** Classic Era and Hardcore are the current test clients; Forever is the final release target. Automated tests exercise the actual Lua modules with mocked WoW APIs. Live-client acceptance testing is still pending. Retail and other Classic expansions are not supported release targets.

## Set up your keys

- Inspect your current bindings first. On **Presets → Preview recommendations**, inspect a temporary layout for any of the nine Classic classes, then **Save as new preset** to keep a unique editable copy. Existing presets remain intact; previewing creates no saved preset or live changes. Druid uses the native Base, Cat, Bear, and Moonkin action pages; travel and aquatic forms share Base, and Prowl shares Cat.
- Edit Current directly or select a saved preset draft, then click a key to rebind it, or drag an action from the miniature spellbook. Browse class and spec groups, individual spell ranks, items, existing personal macros, and game controls.
- Choose **Bindings → Hover bind** for a scrollable grid of spells, including future talents and custom ranks. Hover an ability and press a key, a Shift/Ctrl combination, a side mouse button or the wheel. Hover binding changes do not require individual confirmations. Linked form positions and existing control protections still apply; Alt and primary mouse clicks remain reserved.
- See spell icons and tooltips before abilities are learned. Reserved bindings remain available as you level.
- Test key combinations in the keyboard view without casting spells.
- Record the mouse buttons your client receives and choose whether to use the wheel and middle click. Alt stays reserved for self-casting, with separate camera and movement shortcuts.
- Generate mouseover, focus, self, or cursor macros where the action and client support them. Your existing personal macro text is not imported or overwritten.

In Hover bind, **Done - keep draft** saves the edits in your preset without installing them; **Apply & save** installs them with a named backup. The wheel binds over a spell and scrolls over blank grid space. No spells cast while the mode is active. Escape closes a confirmation first, then leaves the mode; closing the window or entering combat also releases capture.

New generated macros use **character-specific slots only**. Ordinary spells and future reservations use native actions; conditional targeting and form behavior use macros where necessary. Existing owned account macros can be reused for upgrades; personal macros are never overwritten.

Current uses native actions for simple spells and items. Future spells and missing items reserve their positions without macros and activate outside combat when available. Macro-only Current actions wait for character macro space without blocking the rest of Apply. Preset drafts with targeting or other macro features may still need macro slots; their future positions remain reserved when space is limited.

## Keep items and modes organized

Trinket keys follow equipment slots **13 and 14**, so replacing a trinket does not require renaming a macro. Other item bindings follow item IDs. Save manual alternatives for each key, see when the selected item is missing, and choose a different saved item when needed. Missing items remain inactive until usable; the addon does not silently pick another alternative.

Create, duplicate, rename, import, and export complete presets. Leveling, Dungeon, and PvP provide starting modes. Assign shortcuts to switch saved setups **outside combat**. Edits stay separate from the layout currently installed until you choose **Apply & save**.

## Pet controls

The current view resolves bound pet-slot commands to Blizzard's native pet actions and icons. Hunter and warlock recommendations include pet abilities and attack/follow/passive commands. Presets do not save or restore pet-bar ordering, autocast settings or separate layouts for different pets; Blizzard retains those controls.

## Apply and recover

**Apply & save updates the keys assigned by your preset and preserves unrelated bindings and mouse controls.** It populates the original action bars, enables the extra bars it needs, and applies the selected self-cast settings. It records a named backup first, including bindings and affected bar contents. The Backups tab can restore a selected snapshot or the original setup.

When Hot Swap stops using a key from the previous layout, it restores that key's earlier binding only if the key still has Hot Swap's last assignment. Manual changes you made afterward are kept. Keys explicitly assigned by the new preset use its chosen actions.

Setup and recovery run in small steps with a progress indicator. They cannot start in combat; an operation already underway pauses if combat begins and resumes afterward. Wait for completion before testing the result. Restore your original setup before disabling or removing the addon.

## Window settings and troubleshooting

The **Settings** tab offers window opacity and scale, plus optional diagnostic logging that starts off. Logs stay local, retain the latest 200 entries, and can be viewed, copied or cleared. Opaque failure details remain readable independently of window transparency and explain whether nothing changed, recovery succeeded, or a backup needs attention.

New characters can inherit custom or missing controls from WoW's saved account bindings. Hot Swap makes no binding changes on a fresh character's login. Explicit Apply & save installs a character-specific layout while preserving the account map; it does not automatically repair account binding files.

## Get started

1. Install the `KeybindOptimizer` folder in your chosen client's `Interface/AddOns` directory. The folder name is retained for compatibility; the addon is displayed as **Hot Swap**.
2. Open **Hot Swap** from the Escape menu, the AddOns settings page, or `/hotswap`.
3. Choose your mouse options. Inspect actual bindings on **Bindings**, or use **Presets → Preview recommendations → Save as new preset** to create an editable draft. You can also edit an existing saved preset. Review it, then choose **Apply & save** outside combat; only that step installs the layout and records a backup.
4. Wait for completion and keep the backup until you have checked movement, forms, modifiers, and recovery in your client.

The defaults are configurable recommendations, not a verified worldwide optimum or a completed top-20-player consensus. Automatic best-food/water selection is not implemented. Hot Swap does not choose a combat rotation or trigger actions without your input.

**License: All Rights Reserved.**
