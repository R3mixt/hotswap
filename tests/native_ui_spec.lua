-- Full-catalog transaction fixtures explicitly use synthetic character capacity; capacity tests retain 30.
local function nativeUI()
    TestAddon:Init(); Mock:AllowFullCatalogMacros(); Mock.async=true
    TestAddon.UI:Open(); TestAddon.UI:SetBindingSource("draft")
    return TestAddon
end
local function eq(a,b,why) assert(a==b,(why or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function action(k,id)
    for _,entry in ipairs(k.UI.plan.actions) do if entry.id==id then return entry end end
    error("Missing action "..id)
end
local function watch(owner,name)
    local original=owner[name]; local count={value=0}
    owner[name]=function(...) count.value=count.value+1; return original(...) end
    return count
end

function Tests.native_ui_recommendations_require_save_and_apply_before_starting_the_worker()
    local k=nativeUI()
    k:UpdateSetting("bindingOverrides",{["druid.rejuvenation"]="SHIFT-F24"})
    local count=#k.Presets:List(); Mock:ResetWrites()
    k.UI:ShowPage("Presets"); k.UI.pages.Presets.recommendations:Click()
    eq(k.UI.bindingSource,"recommendation","Preview did not identify its unsaved source")
    eq(#k.Presets:List(),count,"Preview created a preset before review")
    assert(not k.Engine.busy and #Mock.writes==0,"Preview applied game changes")
    assert(k.UI.saveRecommendation:IsShown() and not k.UI.apply:IsShown(),"Preview skipped explicit draft creation")
    k.UI.saveRecommendation:Click(); k.UI.saveDialog.new:Click(); k.UI.nameDialog.input:SetText("Recommended Druid"); k.UI.nameDialog.save:Click()
    eq(k.UI.bindingSource,"draft","Saving did not open an editable draft")
    eq(#k.Presets:List(),count+1,"Saving failed to create a new preset")
    assert(not k.db.enabled and #Mock.writes==0,"Saving a draft activated its bindings")
    eq(k.db.presets.Leveling.settings.bindingOverrides["druid.rejuvenation"],"SHIFT-F24","Recommendation discarded the earlier draft")
    k.UI.apply:Click(); if k.UI.saveDialog and k.UI.saveDialog:IsShown() then k.UI.saveDialog.overwrite:Click() end
    assert(k.Engine.busy and k.UI.busyOverlay:IsVisible(),"Explicit Apply skipped the bounded worker")
    local planCalls=watch(k.Planner,"Build")
    for _=1,5 do k.UI:Refresh() end
    eq(planCalls.value,0,"Progress rebuilt the plan")
    assert(not k.UI.apply:IsEnabled(),"Apply remains available during installation")
    local ok,why,frames=Mock:Drain(); assert(ok,why); assert(frames>1,"Setup did not yield across frames")
    Mock:Advance(0.2)
    eq(k.db.appliedPreset,"Recommended Druid","Wrong draft was installed")
    eq(Mock.bindings["1"],"ACTIONBUTTON1","Apply bypassed the native main bar")
    assert(not _G.KBO_ActionDock,"Apply created a replacement combat bar")
end

function Tests.native_ui_busy_cover_releases_capture_and_escape_closes_only_the_window()
    local k=nativeUI(); k.UI:ShowPage("Bindings")
    k.UI:BeginActionCapture(action(k,"druid.rejuvenation"))
    assert(k.UI.capture:IsShown(),"Rebind fixture did not capture input")
    eq(k.Presets:Activate("Leveling"),"pending","Setup fixture was not asynchronous")
    k.UI:Refresh()
    assert(not k.UI.capture:IsShown() and not k.UI.capture.keyboard,"Busy state retained rebind input")
    assert(not k.UI.tester:IsShown() and not k.UI.testMouseShield:IsShown(),"Progress blocked gameplay input")
    assert(not k.UI.escapeModal,"Progress retained an Escape modal")
    Mock.combat=true; Mock.strictInputRestrictions=true; Mock:Fire("PLAYER_REGEN_DISABLED")
    Mock:ResetWrites(); Mock:Advance(0.2)
    assert(k.Engine.busy and k.Engine.job.paused,"Combat did not pause the pending worker")
    eq(k.UI.busyOverlay.title:GetText(),"Paused for combat","Pause is not visible")
    eq(#Mock.writes,0,"Busy UI or paused worker mutated protected state during combat")
    Mock:KeyDown("ESCAPE")
    assert(not k.UI.frame:IsShown(),"Escape could not close progress")
    assert(k.Engine.busy,"Closing the window cancelled the worker")
    Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
    local ok,why=Mock:Drain(); assert(ok,why)
    assert(not k.UI.frame:IsShown(),"Background completion reopened a closed window")
    k.UI:Open(); k.UI:SetBindingSource("draft")
    assert(k.UI.tester:IsShown() and not k.UI.busyOverlay:IsShown(),"Reopening retained stale progress input state")
end

function Tests.native_ui_form_events_follow_cached_native_pages_without_rebuilding_or_writes()
    local k=nativeUI(); local forms=k.API:GetForms()
    Mock.formIndex=forms.cat.index; k.UI:ShowPage("Bindings")
    eq(k.UI.formFilter,"cat","Initial preview did not follow the current form")
    local builds=watch(k.Planner,"Build"); local spells=watch(k.API,"ScanSpellbook")
    local formsRead=watch(k.API,"GetForms"); local items=watch(k.Items,"Scan")
    Mock:ResetWrites()
    for _,entry in ipairs({{"bear","bear","druid.maul.bear"},{"moonkin","moonkin","druid.wrath.moonkin"},{"travel","caster","druid.wrath.caster"},{"aquatic","caster","druid.wrath.caster"},{"cat","cat","druid.claw.cat"}}) do
        Mock.formIndex=forms[entry[1]].index; Mock:Fire("UPDATE_SHAPESHIFT_FORM")
        eq(k.UI.formFilter,entry[2],entry[1].." preview page")
        eq(k.UI.pages.Bindings.keyboard.keys["1"].action.id,entry[3],entry[1].." primary action")
    end
    Mock.stealth=true; Mock:Fire("UPDATE_STEALTH")
    eq(k.UI.formFilter,"cat","Prowl created a nonnative action page")
    k.UI:SetActionPage("bear")
    Mock.formIndex=forms.cat.index; Mock:Fire("UPDATE_SHAPESHIFT_FORM")
    eq(k.UI.formFilter,"bear","A pinned preview changed with the character")
    k.UI:SetFollowForm(true)
    eq(k.UI.formFilter,"cat","Follow form did not resume")
    eq(builds.value,0,"Form preview rebuilt the plan")
    eq(spells.value,0,"Form preview rescanned spells")
    eq(formsRead.value,0,"Form preview repeatedly queried spell metadata")
    eq(items.value,0,"Form preview rescanned inventory")
    eq(#Mock.writes,0,"Inspecting action pages changed protected game state")
end

function Tests.native_ui_rebinding_and_reset_link_each_native_position_across_all_forms()
    local k=nativeUI(); k.UI:ShowPage("Bindings"); k.UI:SetActionPage("cat")
    Mock:ResetWrites()
    assert(k.UI:AssignBinding(action(k,"druid.claw.cat"),"U"))
    local count=0
    for _,entry in ipairs(k.UI.plan.actions) do
        if entry.barSlot==1 and entry.form~="all" then
            count=count+1; eq(entry.key,"U",entry.id.." linked key")
            eq(k.db.settings.bindingOverrides[entry.id],"U",entry.id.." saved override")
        end
    end
    eq(count,4,"Native form group omitted or invented a page")
    k.UI.selectedAction=action(k,"druid.claw.cat"); k.UI:BindingDetail(k.UI.selectedAction)
    assert(k.UI.pages.Bindings.detail.note:GetText():find("every form",1,true),"Linked edit is not explained")
    k.UI.pages.Bindings.detail.reset:Click()
    for _,entry in ipairs(k.UI.plan.actions) do
        if entry.barSlot==1 and entry.form~="all" then eq(entry.key,"1",entry.id.." reset key"); assert(not k.db.settings.bindingOverrides[entry.id]) end
    end
    eq(#Mock.writes,0,"Editing native-position bindings installed game state before Use preset")
end

function Tests.native_ui_confirmed_swap_moves_both_native_positions_across_every_form()
    local k=nativeUI(); k.UI:ShowPage("Bindings"); k.UI:SetActionPage("cat")
    Mock:ResetWrites()
    assert(not k.UI:AssignBinding(action(k,"druid.claw.cat"),"2"),"Linked slot swap bypassed review")
    assert(k.UI.confirm:IsShown(),"Linked slot swap has no review")
    eq(action(k,"druid.claw.cat").key,"1","Swap changed the source before confirmation")
    local finish=k.UI.confirm.callback; k.UI.confirm:Hide(); finish()
    for _,entry in ipairs(k.UI.plan.actions) do
        if entry.form~="all" and (entry.barSlot==1 or entry.barSlot==2) then
            eq(entry.key,entry.barSlot==1 and "2" or "1",entry.id.." swapped position")
        end
    end
    eq(action(k,"druid.rejuvenation").key,"Q","Slot swap moved a persistent utility action")
    eq(#k.UI.plan.errors,0,"Linked swap left overlapping bindings")
    eq(#Mock.writes,0,"Confirming a linked swap installed live bindings")
end

local function libraryEntry(k,options,match)
    for _,entry in ipairs(k.Library:List(options or {})) do if match(entry) then return entry end end
    error("Library fixture was not found")
end
local function accept(k)
    assert(k.UI.confirm and k.UI.confirm:IsShown(),"Expected a replacement review")
    k.UI.confirm.acceptButton:Click(); Mock:Advance(0.05)
end

function Tests.native_ui_spellbook_uses_real_tabs_rank_filter_and_bounded_rows()
    local k=nativeUI(); k.UI:ShowPage("Bindings")
    local book=k.UI.library
    assert(book and book:IsVisible(),"The spellbook did not open beside the keyboard")
    for _,name in ipairs({"spells","items","game","chat","emotes","macros"}) do assert(book.tabs[name],"Missing library tab "..name) end
    assert(book.point[2]==k.UI.frame and book.point[3]=="TOPRIGHT","Spellbook overlaps the keyboard instead of sitting beside it")
    local before=#book.entries
    book.ranks:Click()
    assert(k.UI.libraryRanks and #book.entries>before,"Show ranks did not expose separate exact ranks")
    local rank=libraryEntry(k,{tab="spells",showRanks=true},function(e) return e.spellID==5176 and e.rank=="Rank 1" end)
    assert(rank.descriptor and not rank.actionID,"Exact rank incorrectly reuses the highest-rank family action")
    assert(#book.list.rows<=math.ceil(book.list.sf:GetHeight()/40)+1,"Spellbook allocated all rank rows at once")
    book.tabs.macros:Click()
    eq(k.UI.libraryTab,"macros","Macro tab did not switch the library")
    assert(not book.ranks:IsShown(),"Spell-only rank control appeared for macros")
    assert(book.entries[1] and book.entries[1].label=="UserMacro","Existing player macros are missing")
    book.tabs.spells:Click(); book.category:Click()
    assert(k.UI.menu:IsShown(),"Spell categories cannot be selected")
    k.UI:CloseMenu()
    k.UI.pages.Bindings.modeButtons.List:Click()
    assert(not book:IsShown(),"The spellbook covered list view")
end

function Tests.native_ui_spellbook_drag_cancel_never_stages_or_touches_the_game_cursor()
    local k=nativeUI(); k.UI:ShowPage("Bindings")
    local entry=libraryEntry(k,{tab="spells"},function(e) return e.actionID=="druid.rejuvenation" end)
    local stages=watch(k.Library,"Stage"); local places=watch(k.Library,"Place")
    local before=k:Export(); Mock:ResetWrites()
    PickupSpell=function() error("Library drag touched the native cursor") end
    ClearCursor=function() error("Library drag changed the native cursor") end
    k.UI:StartLibraryDrag(entry)
    assert(k.UI.libraryGhost:IsShown() and k.UI.libraryDrag==entry,"Drag has no custom icon preview")
    k.UI:FinishLibraryDrag()
    assert(not k.UI.libraryDrag and not k.UI.libraryEntry and not k.UI.libraryGhost:IsShown(),"Release outside a key did not cancel the drag")
    eq(stages.value,0,"Merely dragging staged a custom action"); eq(places.value,0,"Canceled drag changed an action")
    eq(k:Export(),before,"Canceled drag changed preset data"); eq(#Mock.writes,0,"Canceled drag changed game state")
    k.UI.libraryEntry=entry; Mock:KeyDown("ESCAPE"); Mock:Advance(0.05)
    assert(not k.UI.libraryEntry and k.UI.frame:IsShown(),"Escape did not cancel click-to-place before closing the window")
end

function Tests.native_ui_spell_drop_changes_only_the_reviewed_native_page_and_preserves_source()
    local k=nativeUI(); k.UI:ShowPage("Bindings"); k.UI:SetActionPage("caster")
    local entry=libraryEntry(k,{tab="spells"},function(e) return e.actionID=="druid.rejuvenation" end)
    local before=k:Export(); Mock:ResetWrites()
    k.UI:StartLibraryDrag(entry)
    local cap=k.UI.pages.Bindings.keyboard.keys["1"]
    cap:GetScript("OnReceiveDrag")(cap)
    assert(k.UI.confirm:IsShown() and not k.UI.libraryDrag,"Drop did not enter replacement review")
    eq(k:Export(),before,"Drop changed the preset before replacement was accepted")
    k.UI.confirm.cancelButton:Click(); Mock:Advance(0.05)
    eq(k:Export(),before,"Canceling replacement changed the preset")
    k.UI.libraryEntry=entry; k.UI:KeyboardKeyClick("1"); accept(k)
    local base=action(k,"druid.wrath.caster")
    eq(base.name,"Rejuvenation","Dropped family was not installed on the selected page")
    eq(base.key,"1","Dropping an action moved the destination key"); eq(base.barSlot,1,"Dropping an action moved its native slot")
    eq(action(k,"druid.claw.cat").name,"Claw","Base replacement changed Cat")
    eq(action(k,"druid.maul.bear").name,"Maul","Base replacement changed Bear")
    eq(action(k,"druid.wrath.moonkin").name,"Wrath","Base replacement changed Moonkin")
    eq(action(k,"druid.rejuvenation").key,"Q","Dropping a copy moved its source utility binding")
    eq(#Mock.writes,0,"Library replacement installed live action bars before Use preset")
end

function Tests.native_ui_empty_key_drop_and_rejected_drop_keep_only_successful_custom_actions()
    local k=nativeUI(); k.UI:ShowPage("Bindings")
    local entry=libraryEntry(k,{tab="emotes"},function(e) return e.id=="emote.WAVE" end)
    local before=k:Export(); Mock:ResetWrites()
    k.UI.libraryEntry=entry
    assert(not k.UI:DropLibraryEntry("ALT-NUMPAD9"),"Reserved self-cast key accepted an emote")
    eq(k:Export(),before,"Rejected key drop left a staged custom action behind")
    assert(not next(k:GetSettings().customActions),"Rejected drop leaked its action descriptor")
    k.UI.libraryEntry=entry
    assert(k.UI:DropLibraryEntry("NUMPAD9"),"Empty-key drop did not bind the chosen emote")
    local id=next(k:GetSettings().customActions)
    assert(id and action(k,id).key=="NUMPAD9","Successful drop did not retain its custom action and binding")
    eq(#Mock.writes,0,"Creating a custom library binding changed game state")
end

function Tests.native_ui_target_menu_changes_targeting_without_rebinding_and_badges_match()
    local k=nativeUI(); k.UI:ShowPage("Bindings")
    local cap=k.UI.pages.Bindings.keyboard.keys.Q; cap:Click()
    assert(k.UI.capture:IsShown() and k.UI.capture.targetMode:IsShown(),"Spell click did not expose targeting controls")
    local before=action(k,"druid.rejuvenation").key; Mock:ResetWrites()
    k.UI.capture.targetMode:Click()
    assert(k.UI.menu:IsShown(),"Target mode choices are inaccessible")
    Mock:KeyDown("9"); Mock:KeyUp("9")
    eq(action(k,"druid.rejuvenation").key,before,"Typing while choosing targeting unexpectedly rebound the spell")
    k.UI:CloseMenu(); k.UI:SetActionTarget("self")
    eq(action(k,"druid.rejuvenation").key,before,"Changing targeting moved the binding")
    eq(action(k,"druid.rejuvenation").targetMode,"self","Target mode did not save")
    k.UI.captureDone:Click(); Mock:Advance(0.05)
    eq(k.UI.pages.Bindings.keyboard.keys.Q.targetBadge:GetText(),"S","Self targeting badge is wrong")
    eq(#Mock.propagatedKeys,0,"Target editor leaked a key to gameplay")
    local a=action(k,"druid.wrath.caster")
    local modes=k.Library:TargetModes(a)
    for _,mode in ipairs(modes) do assert(mode~="self" and mode~="cursor","Harmful spell offered unsupported targeting") end
    eq(#Mock.writes,0,"Editing targeting installed live game state")
end

function Tests.native_ui_rank_drop_preserves_page_binding_and_busy_state_cancels_library_drag()
    local k=nativeUI(); k.UI:ShowPage("Bindings"); k.UI:SetActionPage("caster")
    local rank=libraryEntry(k,{tab="spells",showRanks=true},function(e) return e.spellID==5176 and e.rank=="Rank 1" end)
    k.UI.libraryEntry=rank; k.UI:KeyboardKeyClick("1"); accept(k)
    local base=action(k,"druid.wrath.caster")
    eq(base.selectedSpellID,5176,"Rank drop silently upgraded to highest rank")
    eq(base.selectedRank,"Rank 1","Rank drop lost its explicit rank")
    eq(base.key,"1","Rank drop moved native position")
    k.UI:StartLibraryDrag(rank)
    eq(k.Presets:Activate(k.db.activePreset),"pending","Busy fixture did not start")
    k.UI:Refresh()
    assert(not k.UI.library:IsShown() and not k.UI.libraryGhost:IsShown() and not k.UI.libraryDrag,"Running setup left the spellbook draggable")
    local ok,why=Mock:Drain(); assert(ok,why); Mock:Advance(0.2)
    assert(k.UI.library:IsVisible(),"Completion did not restore the spellbook beside the keyboard")
end

function Tests.native_ui_item_drop_keeps_missing_choices_and_uses_verified_target_controls()
    Mock.itemInfo[1251]={name="Linen Bandage",effect="Linen Bandage"}
    Mock.itemInfo[1710]={name="Greater Healing Potion",effect="Healing Potion"}
    Mock.bagItems[0]={{id=1251,count=3}}
    local k=nativeUI(); k.UI:ShowPage("Bindings"); k.UI:SetActionPage("caster")
    assert(k.Items:AddAlternative("item.utility",1710)); k.UI:Refresh()
    k.UI.library.tabs.items:Click()
    local missing=libraryEntry(k,{tab="items"},function(e) return e.itemID==1710 end)
    assert(not missing.known and missing.availability:find("Not in",1,true),"Saved missing item was hidden or marked usable")
    local missingRow
    for _,row in ipairs(k.UI.library.list.rows) do if row:IsShown() and row.entry.itemID==1710 then missingRow=row end end
    assert(missingRow and missingRow.rank:GetText():find("Not in",1,true),"Spellbook omitted missing-item status")
    assert(not missingRow.tipLocked and missingRow.tipItemID==1710,"Item tooltip falsely labels an item as an unlearned spell")
    k.UI.libraryEntry=missing
    assert(k.UI:DropLibraryEntry("NUMPAD9"),"A missing item cannot be bound in advance")
    local missingAction=action(k,next(k:GetSettings().customActions))
    assert(missingAction.kind=="item" and not missingAction.known and missingAction.itemID==1710,"Missing item reservation lost its identity")
    k.UI:BeginActionCapture(missingAction)
    assert(not k.UI.capture.targetMode:IsShown(),"Unverified item offered targeting controls")
    k.UI:EndCapture(); Mock:Advance(0.05)
    local bandage=libraryEntry(k,{tab="items"},function(e) return e.itemID==1251 end)
    k.UI.libraryEntry=bandage; k.UI:KeyboardKeyClick("1"); accept(k)
    k.UI.pages.Bindings.keyboard.keys["1"]:Click()
    assert(k.UI.capture.targetMode:IsShown(),"Verified unit-target item omitted targeting controls")
    k.UI:SetActionTarget("self"); k.UI.captureDone:Click(); Mock:Advance(0.05)
    local placed=action(k,"druid.wrath.caster")
    eq(placed.itemID,1251,"Bandage drop lost its item identity")
    eq(placed.targetMode,"self","Item replacement lost its configured target mode")
    assert(placed.body and placed.body:find("[@player]",1,true),"Item's target choice did not affect its use macro")
    eq(k.UI.pages.Bindings.keyboard.keys["1"].targetBadge:GetText(),"S","Item targeting badge disagrees with selected mode")
    eq(action(k,"druid.claw.cat").name,"Claw","Item drop changed another form page")
end

function Tests.native_ui_apply_and_save_buttons_install_drafts_and_save_game_bindings()
    local k=nativeUI(); k.UI:ShowPage("Presets")
    local page=k.UI.pages.Presets
    eq(k.UI.apply:GetText(),"Apply & save","Footer final action has the old label")
    eq(page.usePreset:GetText(),"Apply & save","Preset final action differs from the footer")
    eq(k.UI.apply:GetWidth(),128,"Apply label has insufficient button space")
    assert(page.detail.description:GetText():find("Draft edits are kept automatically",1,true),"Automatic draft saving is unexplained")
    assert(k.UI.apply.tipDetail:find("macros",1,true) and k.UI.apply.tipDetail:find("save the game's bindings",1,true),"Final action does not explain installation and saving")
    local function selectDraft(name)
        Mock:ResetWrites()
        local prior=k.db.appliedPreset
        for _,row in ipairs(page.list.rows) do if row.presetName==name then row:Click(); break end end
        eq(k.db.activePreset,name,"Preset list did not select its draft")
        eq(k.db.appliedPreset,prior,"Selecting a draft switched the active game setup")
        eq(#Mock.writes,0,"Selecting a preset wrote live game state")
        assert(page.detail.state:GetText():find("draft",1,true),"Selected preset was not identified as a draft")
    end
    selectDraft("Dungeon")
    Mock:AllowFullCatalogMacros() -- Explicit opt-in for this full Druid installation fixture.
    k.UI.apply:Click(); if k.UI.saveDialog and k.UI.saveDialog:IsShown() then k.UI.saveDialog.overwrite:Click() end
    assert(k.Engine.busy,"Footer Apply & save did not start installation")
    local ok,why=Mock:Drain(); assert(ok,why); Mock:Advance(0.2)
    eq(k.db.appliedPreset,"Dungeon","Footer Apply & save installed a different preset")
    assert(#k.Engine:ListBackups()>0,"Applying a draft omitted its backup")
    local saved=false
    for _,write in ipairs(Mock.writes) do if write[1]=="savebindings" then saved=true end end
    assert(saved,"Apply & save did not save the game's bindings")
    selectDraft("PvP")
    Mock:AllowFullCatalogMacros()
    page.usePreset:Click(); if k.UI.saveDialog and k.UI.saveDialog:IsShown() then k.UI.saveDialog.overwrite:Click() end
    assert(k.Engine.busy,"Preset Apply & save did not start installation")
    ok,why=Mock:Drain(); assert(ok,why); Mock:Advance(0.2)
    eq(k.db.appliedPreset,"PvP","Preset Apply & save installed a different draft")
    assert(page.detail.state:GetText()=="This preset is active","Successful apply still displays an unapplied draft")
end
