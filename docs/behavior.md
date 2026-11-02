# Hot Swap 1.0 behavior contract

This is the player-facing contract for version 1.0.0. Automated checks execute the real Lua modules against simulated WoW APIs. Protected execution, actual spell casting, physical input delivery, and other addons still require Classic Era user testing.

## Opening and editing

Every opening selects **Bindings → Current** and opens the miniature spellbook. Current is built from the game's binding map and action slots, including supported pet and third-party action buttons. It is never replaced by a recommendation. Pending edits are shown as a draft over Current; opening does not apply them. **Discard edits** returns to the live layout.

Drag a spell from the miniature spellbook or Blizzard's spellbook to a keyboard key. Click placement and Hover bind offer alternatives. Use **Game spellbook** to open the native book. While it is visible, outside mouse clicks use normal game behavior so its spells can be dragged; the editor mouse shield resumes when it closes. Select a modifier layer to edit that combination. A native action-slot replacement affects aliases of that slot; rebinding a key changes the command assigned to that key. Form-linked positions share their key across pages. Unsupported commands, reserved inputs and incompatible collisions produce an explanation instead of being forced through.

**Apply changes** installs Current edits only, preserving unrelated controls and action slots. **Apply & save** installs the selected preset's assigned keys. Both operate outside combat and save a named recovery snapshot. A changed live binding or slot can invalidate a Current draft; review it again instead of overwriting an external edit.

**Settings → Window** has independent **Confirm replacing a binding** and **Confirm swapping bindings** switches. Both start enabled and remain local to the character. Replacement acceptance rechecks that the reviewed destination has not changed. Disabling them skips those editing prompts; it does not bypass validation or the confirmation required for a recovery/reset operation.

The miniature spellbook has separate **Movement** and **Camera** sections. Movement includes forward/backward, strafe, turn, jump and other movement commands supported by the running client. Camera includes zoom, saved views and the native combined selection/camera and turn/interact mouse controls. **Game** contains the remaining targeting and interface commands. Search and categories narrow each section; controls remain available in these lists even when they have no assigned key.

To leave a control unbound, select **Bindings → Current**, select its bound keyboard key or mouse control, and choose **Clear key**. Confirm the edit, then use **Apply changes** outside combat. The same command is available from the binding-detail panel in List view. Clearing affects that key only; clear each alias if you want the command to have no bindings at all. Apply creates a recovery backup. The unbound state persists across reload and automatic maintenance. To restore it, choose the command from Movement or Camera and assign it to a key, or restore a backup.

Current permits explicit clearing and reassignment of camera/movement commands on the primary mouse buttons. Spell, item and arbitrary macro placement on those buttons remains restricted, and Escape stays reserved. Disabling a combined mouse control also removes its game-world selection or interaction behavior until rebound; the clear confirmation explains this.

**Settings → Controls → Keep current movement** and **Keep camera and selection** govern preset application, including preserving deliberately unbound controls. They do not prevent explicit Current edits. If those options are off, explicitly applying a preset can install that preset's movement/camera assignments again. A protected preset key must be released before assigning another action to it.

## Spells, macros and automatic maintenance

Simple casts and supported exact ranks use native spell actions or direct spell bindings. An unlearned spell reserves its key and metadata without a placeholder macro. Learning it fills the owned reservation outside combat. Higher-rank family choices follow the learned family; an explicit rank waits for that rank. Maintenance uses the installed layout, never an unapplied draft, and preserves manual changes to owned keys or slots.

New presets leave **Allow utility macros to leave form** off to minimize macro use. Leave form manually when required, or enable that Setup option and review its macro cost. Existing saved preferences are preserved.

Macros are for behavior that a plain spell action cannot provide: conditional targeting, form guards/cancellation, combinations, and applicable item or utility behavior. Newly generated macros are character-specific. The old account-overflow setting no longer grants permission to create account macros. Existing owned account macros may remain reusable for upgrade/recovery; personal or externally edited macros are not overwritten. A layout that genuinely needs more character macro slots fails preflight with a capacity explanation.

Learning a spell does not autonomously cast it. Combat blocks new protected setup writes; pending maintenance resumes after combat. New uncatalogued spell families may require reviewing and applying a recommendation rather than silently consuming an unassigned key.

## Presets and transfer

Selecting, previewing, editing and importing presets do not install bindings. Recommendation preview is separate from Current. Save the recommendation to a named draft, review it, then apply explicitly. Preset activation shortcuts operate outside combat.

**Import / export** exports a selected preset or the collection as a `KBO2` text code. Use **Select text**, Ctrl+C, and paste it elsewhere. To keep a downloaded profile, save the code in a plain-text `.hotswap` file. To import that file, open it in a text editor, select all, copy, and paste the complete code into Hot Swap's import box. WoW addons cannot use a normal filesystem file picker or read an arbitrary downloaded file. The addon never executes imported Lua or macro code.

Import adds uniquely named presets and leaves the selected preset, its working settings, current edits, local preferences and live layout unchanged. Select the imported preset in **Presets** to review it. Name collisions receive a suffix; conflicting imported shortcuts are cleared. Unsupported classes, malformed records and oversized payloads are rejected. Existing local presets remain available. Sharing excludes personal backups, diagnostics and local appearance/confirmation preferences. Referenced user macros must exist locally and match their reviewed identity before use.

## Recovery and errors

**Backups → Restore default keys** resets the current character's bindings to the client's defaults, with confirmation and a prior named backup. This is distinct from **Restore original setup**, which recovers the setup captured before Hot Swap's first apply, and **Restore selected**, which recovers a named snapshot. Default keybind reset does not restore default action-bar contents or delete presets.

Preflight errors stop before installation. Transaction failures attempt rollback and preserve recovery data; a failed rollback is explicitly reported. Do not interpret an error as proof that nothing changed: use the operation's Details message and named backup. Optional diagnostics keep a bounded local log; copied logs are never uploaded automatically. WoW persists SavedVariables on reload or logout.

## Other action-bar addons

Hot Swap uses the native action slots and binding commands where possible. Supported Bartender/Dominos button bindings can be displayed through their live action-slot attributes. Hot Swap does not rewrite another addon's profiles, paging rules or override bindings. Consequently custom overrides can still take precedence over saved bindings. Verify the actual button action, form paging and combat behavior with each addon enabled separately before relying on the combination.

## User acceptance sequence

1. Open `/hotswap`, inspect Current against the game, close from another tab, and reopen. Confirm Current is selected and no bindings changed.
2. Drag a learned spell from each spellbook onto an empty key and an occupied key. Test both confirmation switches, cancel, apply, and discard. Try Shift/Ctrl and a form-specific action.
3. Reserve an unlearned spell, apply, learn it, and verify it activates without a placeholder macro. Repeat with combat deferral, a higher rank and an explicit lower rank.
4. Import a downloaded `.hotswap` code while a local draft exists. Confirm the draft and preferences remain, duplicate names survive, and imported bindings install only after explicit apply.
5. Bind commands through the separate Movement and Camera sections. Clear keyboard, wheel and primary mouse bindings in Current, apply, and reload; verify the cleared keys stay empty and other aliases remain. Restore the controls from the spellbook or a backup. Check chat, Escape, search typing and Hover bind; closing and entering combat must release editor capture.
6. Restore defaults, inspect the named backup, then restore that backup. Confirm other characters/account bindings and current bar contents are unchanged by the default reset.
7. With diagnostics enabled, exercise apply/restore and reload. Inspect error Details if any operation fails. Verify saved presets and current edits survive reload.
8. Repeat relevant checks with Bartender and Dominos individually, including form changes and actual combat use. Record client/addon versions and the exact failing key if a conflict occurs.

Pet bar order/autocast, automatic equipment swapping on preset activation, automatic best-food selection, and combat rotation automation are outside this contract. Equipment activation is an explicit separate request. Era does not gain focus support by selecting another catalog.
