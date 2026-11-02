local function hoverUI(allowFixtureOverflow)
    local k=TestAddon; k:Init()
    if allowFixtureOverflow then Mock:AllowFullCatalogMacros() end
    k.UI:Open(); k.UI:SetBindingSource("draft"); k.UI:ShowPage("Bindings"); k.UI.pages.Bindings.hoverBind:Click()
    return k,k.UI.hoverBindings
end
local function hover(k,id)
    local row=k.UI.hoverBindings.rows[id]; assert(row,"Missing hover binding: "..id)
    row:GetScript("OnEnter")(row)
    return row
end
local function press(key)
    Mock:KeyDown(key); Mock:KeyUp(key)
end

function Tests.hover_ui_all_planned_spells_include_unlearned_talents_and_repeated_edits_update_keyboard()
    local known={}
    for _,spell in ipairs(Mock.spells) do if spell.id~=24858 then known[#known+1]=spell end end
    Mock.spells=known
    local k,f=hoverUI(); k.db.preferences.showUnavailableBindings=false
    k.UI:RenderHoverBindings(); Mock:ResetWrites()
    local count=0
    for _,action in ipairs(k.UI.plan.actions) do if not action.kind and not action.builtin then
        assert(f.rows[action.id] and f.rows[action.id]:IsVisible(),"Hover editor omitted "..action.id); count=count+1
    end end
    assert(f.subtitle:GetText():find(tostring(count).." spells",1,true))
    local talent=hover(k,"druid.form_moonkin")
    assert(talent.state:GetText():find("Talent not learned",1,true) and talent.icon:GetTexture(),"Unlearned talent lost its name/icon/state")
    press("NUMPAD9")
    assert(k:GetSettings().bindingOverrides["druid.form_moonkin"]=="NUMPAD9" and f.active,"First hover assignment exited the mode")
    assert(talent.binding:GetText()=="NUMPAD9","Grid retained a stale key")
    hover(k,"druid.rejuvenation"); Mock.ctrl=true; press("9"); Mock.ctrl=false
    assert(k:GetSettings().bindingOverrides["druid.rejuvenation"]=="CTRL-9","Modified hover input did not stage its key")
    assert(k.UI.keyIndex["CTRL-9"][1].id=="druid.rejuvenation","Keyboard preview was not updated")
    assert(#Mock.writes==0 and k.dirty and not k.db.enabled,"Hover edits changed live game state")
    assert(#Mock.propagatedKeys==0,"Hover keys propagated into game actions")
    f.done:Click()
    assert(not f.active and not f:IsShown() and k:GetSettings().bindingOverrides["druid.rejuvenation"]=="CTRL-9","Done lost staged bindings")
end

function Tests.hover_ui_reserves_movement_alt_and_primary_mouse_buttons_but_supports_side_and_wheel_inputs()
    local k,f=hoverUI(); local row=hover(k,"druid.rejuvenation"); Mock:ResetWrites()
    press("W"); Mock.alt=true; press("9"); Mock.alt=false
    row:GetScript("OnMouseDown")(row,"LeftButton"); row:GetScript("OnMouseDown")(row,"RightButton")
    assert(not k:GetSettings().bindingOverrides["druid.rejuvenation"],"Hover input claimed Alt, movement or primary clicks")
    Mock.ctrl=true; Mock.shift=true
    row:GetScript("OnMouseDown")(row,"Button4")
    assert(k:GetSettings().bindingOverrides["druid.rejuvenation"]=="CTRL-SHIFT-BUTTON4","Side-button combination was not staged")
    row:GetScript("OnMouseWheel")(row,1)
    assert(k:GetSettings().bindingOverrides["druid.rejuvenation"]=="CTRL-SHIFT-MOUSEWHEELUP","Wheel combination was not staged")
    Mock.ctrl=false; Mock.shift=false
    row:GetScript("OnLeave")(row); press("NUMPAD8")
    assert(k:GetSettings().bindingOverrides["druid.rejuvenation"]=="CTRL-SHIFT-MOUSEWHEELUP","Leaving a row kept a stale hover target")
    assert(#Mock.writes==0 and #Mock.propagatedKeys==0)
end

function Tests.hover_ui_linked_form_slots_swap_immediately_without_confirmation()
    local k,f=hoverUI(); Mock:ResetWrites()
    hover(k,"druid.claw.cat"); press("NUMPAD8")
    for _,action in ipairs(k.UI.plan.actions) do if action.barSlot==1 then assert(action.key=="NUMPAD8","Linked form position did not follow hover binding") end end
    hover(k,"druid.claw.cat"); press("2")
    assert(not k.UI.confirm or not k.UI.confirm:IsShown(),"Hover swap required confirmation")
    assert(f:IsShown() and f.active and k.UI.hoverInput:IsShown(),"Immediate swap ended hover mode")
    for _,action in ipairs(k.UI.plan.actions) do
        if action.barSlot==1 then assert(action.key=="2","Swap failed to move every first position")
        elseif action.barSlot==2 then assert(action.key=="NUMPAD8","Swap failed to move every second position") end
    end
    assert(#Mock.writes==0 and #Mock.propagatedKeys==0,"Collision handling cast an action or applied the draft")
end

function Tests.hover_ui_escape_close_combat_and_page_changes_release_only_its_input_capture()
    local k,f=hoverUI()
    assert(k.UI.hoverInput:IsVisible() and k.UI.hoverMouseShield:IsShown() and not k.UI.tester:IsShown(),"Hover editor did not own preview input")
    press("ESCAPE"); Mock:Advance(0.1)
    assert(not f.active and not k.UI.hoverInput:IsShown() and not k.UI.hoverMouseShield:IsShown() and k.UI.frame:IsShown(),"Escape did not leave only hover mode")
    assert(#Mock.propagatedKeys==0,"Closing hover mode leaked Escape")
    k.UI:OpenHoverBindings(); k.UI:ShowPage("Setup")
    assert(not f.active and not k.UI.hoverInput:IsShown() and not k.UI.hoverMouseShield:IsShown(),"Page change retained capture")
    k.UI:ShowPage("Bindings"); k.UI:OpenHoverBindings(); k.UI.frame:Hide()
    assert(not f.active and not k.UI.hoverInput:IsVisible() and not k.UI.hoverMouseShield:IsShown(),"Closing the addon retained capture")
    k.UI:Open(); k.UI:SetBindingSource("draft"); k.UI:OpenHoverBindings()
    Mock.combat=true; Mock.strictInputRestrictions=true; Mock:Fire("PLAYER_REGEN_DISABLED")
    assert(not f.active and not k.UI.hoverInput:IsShown() and not k.UI.hoverMouseShield:IsShown(),"Combat retained hover input")
    k.UI:OpenHoverBindings(); assert(not f.active,"Hover input reopened in combat")
    Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
    assert(not f.active,"Leaving combat silently resumed edit capture")
end

function Tests.hover_ui_apply_uses_the_existing_preset_worker_and_releases_capture()
    local k,f=hoverUI(true); Mock.async=true
    hover(k,"druid.rejuvenation"); press("NUMPAD9")
    assert(not k.db.enabled and #k.Engine:ListBackups()==0,"Staging created a live backup")
    f.apply:Click(); if k.UI.saveDialog and k.UI.saveDialog:IsShown() then k.UI.saveDialog.overwrite:Click() end
    assert(k.Engine.busy and not f.active and not k.UI.hoverInput:IsShown() and not k.UI.hoverMouseShield:IsShown(),"Applying kept hover capture or bypassed the worker")
    local ok,why=Mock:Drain(); assert(ok,why); Mock:Advance(0.1)
    assert(k.db.appliedPreset==k.db.activePreset and GetBindingAction("NUMPAD9")~="","Apply did not install the selected preset binding")
    assert(#k.Engine:ListBackups()>0,"Apply skipped named recovery")
end

function Tests.hover_ui_opening_in_combat_never_creates_a_keyboard_sink()
    local k=TestAddon; k:Init(); Mock.combat=true; Mock.strictInputRestrictions=true
    k.UI:Open(); k.UI:SetBindingSource("draft"); k.UI:ShowPage("Bindings"); k.UI:OpenHoverBindings()
    assert(not k.UI.hoverBindings and not k.UI.hoverInput and not k.UI.hoverMouseShield,"First open in combat created an input consumer")
end

function Tests.hover_ui_hovering_is_cached_and_external_operations_release_the_editor()
    local k,f=hoverUI(true); Mock.async=true
    local scans=0
    for _,entry in ipairs({{k.API,"ScanSpellbook"},{k.API,"GetForms"},{k.Items,"Scan"},{k.Planner,"Build"}}) do
        local owner,name=entry[1],entry[2]; local original=owner[name]
        owner[name]=function(...) scans=scans+1; return original(...) end
    end
    for _=1,5 do hover(k,"druid.rejuvenation"); hover(k,"druid.form_moonkin"); Mock:Advance(0.1) end
    assert(scans==0,"Hovering or idle input rebuilt gameplay metadata")
    local width=f.list.child:GetWidth()
    for _,row in pairs(f.rows) do
        assert((row.point[2] or 0)+row:GetWidth()<=width+0.1,"A first-render card exceeded the grid width")
    end
    assert(k.Presets:Activate(k.db.activePreset)=="pending"); k.UI:Refresh()
    assert(not f.active and not k.UI.hoverInput:IsShown() and not k.UI.hoverMouseShield:IsShown(),"An externally started operation retained hover capture")
end
