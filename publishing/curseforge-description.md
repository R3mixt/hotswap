# Hot Swap

Build a comfortable keyboard layout, keep it consistent across your class, and switch saved setups when your playstyle changes.

Hot Swap places spells and generated macros on **Blizzard's original action bars**. Its in-game keyboard editor shows what each key does, including Shift and Ctrl layers, mouse buttons, and optional wheel bindings. The interface uses WoW's own frames and controls.

**0.4.2 beta:** Classic Era and Hardcore are the current test clients; Forever is the final release target. Automated tests exercise the actual Lua modules with mocked WoW APIs. Live-client acceptance testing is still pending. Retail and other Classic expansions are not supported release targets.

## Set up your keys

- Start with recommended layouts for all nine Classic classes, then customize them. Druid uses the native Base, Cat, Bear, and Moonkin action pages; travel and aquatic forms share Base, and Prowl shares Cat.
- Click a key to rebind it, or drag an action from the miniature spellbook. Browse class and spec groups, individual spell ranks, items, existing personal macros, and game controls.
- See spell icons and tooltips before abilities are learned. Reserved bindings remain available as you level.
- Test key combinations in the keyboard view without casting spells.
- Record the mouse buttons your client receives and choose whether to use the wheel and middle click. Alt stays reserved for self-casting, with separate camera and movement shortcuts.
- Generate mouseover, focus, self, or cursor macros where the action and client support them. Your existing personal macro text is not imported or overwritten.

Generated macros use **character-specific slots by default**. Each preset can opt into **Settings → Action bars → Allow account-wide macro overflow** when it needs extra shared slots. Existing owned account macros are reused without being moved; personal macros are never overwritten.

If space is limited, future spell keys, icons and tooltips stay reserved in the editor while their native bar positions remain empty. Managed positions fill outside combat as you learn spells, subject to available macro space. This does not change your visibility preferences. Fully learned layouts can still exceed the character bank: free macro slots or explicitly enable account-wide overflow when needed.

## Keep items and modes organized

Trinket keys follow equipment slots **13 and 14**, so replacing a trinket does not require renaming a macro. Other item bindings follow item IDs. Save manual alternatives for each key, see when the selected item is missing, and choose a different saved item when needed. Missing items remain inactive until usable; the addon does not silently pick another alternative.

Create, duplicate, rename, import, and export complete presets. Leveling, Dungeon, and PvP provide starting modes. Assign shortcuts to switch saved setups **outside combat**. Edits stay separate from the layout currently installed until you choose **Apply & save**.

## Apply and recover

**Apply & save updates the keys assigned by your preset and preserves unrelated bindings and mouse controls.** It populates the original action bars, enables the extra bars it needs, and applies the selected self-cast settings. It records a named backup first, including bindings and affected bar contents. The Backups tab can restore a selected snapshot or the original setup.

When Hot Swap stops using a key from the previous layout, it restores that key's earlier binding only if the key still has Hot Swap's last assignment. Manual changes you made afterward are kept. Keys explicitly assigned by the new preset use its chosen actions.

Setup and recovery run in small steps with a progress indicator. They cannot start in combat; an operation already underway pauses if combat begins and resumes afterward. Wait for completion before testing the result. Restore your original setup before disabling or removing the addon.

## Window settings and troubleshooting

The **Settings** tab offers window opacity and scale, plus optional diagnostic logging that starts off. Logs stay local, retain the latest 200 entries, and can be viewed, copied or cleared. Opaque failure details remain readable independently of window transparency and explain whether nothing changed, recovery succeeded, or a backup needs attention.

## Get started

1. Install the `KeybindOptimizer` folder in your chosen client's `Interface/AddOns` directory. The folder name is retained for compatibility; the addon is displayed as **Hot Swap**.
2. Open **Hot Swap** from the Escape menu, the AddOns settings page, or `/hotswap`.
3. Choose your mouse options. **Optimize** creates and installs a recommended preset with a backup. Alternatively, edit a preset in **Bindings** and **Items**, review it, then choose **Apply & save** outside combat.
4. Wait for completion and keep the backup until you have checked movement, forms, modifiers, and recovery in your client.

The defaults are configurable recommendations, not a verified worldwide optimum or a completed top-20-player consensus. Automatic best-food/water selection is not implemented. Hot Swap does not choose a combat rotation or trigger actions without your input.

**License: All Rights Reserved.**
