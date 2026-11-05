local function wheelMenu()
    local k=TestAddon
    Mock.bindings={MOUSEWHEELUP="ACTIONBUTTON1",MOUSEWHEELDOWN="ACTIONBUTTON2",["1"]="ACTIONBUTTON3",F="OPENCHAT"}
    Mock.bindingInventory=nil
    Mock.actions={[1]={"spell",774},[2]={"spell",8936},[3]={"spell",5176}}
    k:Init(); k.UI:Open(); Mock:ResetWrites()
    return k,k.UI,k.UI.pages.Bindings.keyboard.keys
end
local function visible(frame) return frame and frame:IsShown() end
local function targetChoice(ui,label)
    ui.bindingMenu.targetMode:Click()
    assert(visible(ui.menu),"Targeting choices did not open")
    for _,row in ipairs(ui.menu.panel.rows) do
        if row:IsShown() and row.text:GetText():gsub("^> ","")==label then row:Click(); return end
    end
    error("Missing target choice "..label)
end

function Tests.binding_menu_keyboard_wheel_and_list_open_choices_without_recording()
    local k,ui,keys=wheelMenu(); local saved=k:Export()
    for _,key in ipairs({"1","MOUSEWHEELUP","MOUSEWHEELDOWN"}) do
        keys[key]:Click()
        assert(visible(ui.bindingMenu) and ui.bindingMenu.action.key==key,"Click skipped the action menu")
        assert(not visible(ui.capture),"Click immediately started rebinding")
        assert(ui.bindingMenu.rebind:IsShown() and ui.bindingMenu.change:IsShown())
        Mock:KeyDown("9"); Mock:KeyUp("9")
        local wheel=ui.bindingMenu:GetScript("OnMouseWheel")
        if wheel then wheel(ui.bindingMenu,1) end
        assert(not k.CurrentBindings:HasEdits(),"Browsing the menu recorded an accidental binding")
        ui.bindingMenu.done:Click(); Mock:Advance(0.05)
    end
    ui.pages.Bindings.modeButtons.List:Click()
    local row
    for _,candidate in ipairs(ui.pages.Bindings.list.rows) do
        if candidate:IsShown() and candidate.action.key=="MOUSEWHEELUP" then row=candidate; break end
    end
    assert(row,"List omitted wheel binding")
    row:Click(); assert(visible(ui.bindingMenu) and not visible(ui.capture))
    ui.bindingMenu.done:Click(); Mock:Advance(0.05)
    row.key:Click(); assert(visible(ui.bindingMenu) and not visible(ui.capture))
    assert(k:Export()==saved and #Mock.writes==0,"Opening menus changed live or preset data")
end

function Tests.binding_menu_current_mouseover_stays_on_wheel_and_changes_only_current_draft()
    local k,ui,keys=wheelMenu(); local saved=k:Export()
    keys.MOUSEWHEELUP:Click()
    assert(ui.bindingMenu.targetMode:IsShown() and ui.bindingMenu.targetMode:IsEnabled(),"Current spell lacks targeting choices")
    targetChoice(ui,"Mouseover")
    assert(visible(ui.bindingMenu) and not visible(ui.capture),"Targeting left the menu or started recording")
    local view=k.CurrentBindings:EditingView()
    assert(view.byKey.MOUSEWHEELUP.spellID==774 and view.byKey.MOUSEWHEELUP.targetMode=="mouseover")
    assert(view.byKey.MOUSEWHEELDOWN.spellID==8936 and not view.byKey.MOUSEWHEELDOWN.targetMode,"Targeting changed the other wheel action")
    assert(Mock.actions[1][1]=="spell" and Mock.actions[1][2]==774 and #Mock.writes==0,"Choosing targeting applied game changes")
    assert(k:Export()==saved and k.CurrentBindings:HasEdits(),"Current targeting changed the selected preset")
    ui.bindingMenu.done:Click(); Mock:Advance(0.05)
    assert(ui.apply:IsEnabled() and keys.MOUSEWHEELUP.targetBadge:GetText()=="M")
end

function Tests.binding_menu_change_key_requires_explicit_choice_then_records_wheel()
    local k,ui,keys=wheelMenu()
    keys["1"]:Click(); ui.bindingMenu.rebind:Click()
    assert(not visible(ui.bindingMenu) and visible(ui.capture),"Change key did not enter a separate capture")
    ui.capture:GetScript("OnMouseWheel")(ui.capture,1)
    if visible(ui.confirm) then ui.confirm.acceptButton:Click() end
    Mock:Advance(0.05)
    assert(k.CurrentBindings:HasEdits() and not visible(ui.capture))
    assert(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP.spellID==5176,"Explicit wheel capture did not move the selected action")
    assert(#Mock.writes==0,"Rebinding installed edits without Apply changes")
end

function Tests.binding_menu_escape_and_context_changes_close_the_menu_only()
    local k,ui,keys=wheelMenu()
    keys.MOUSEWHEELUP:Click(); Mock:KeyDown("ESCAPE"); Mock:KeyUp("ESCAPE"); Mock:Advance(0.05)
    assert(not visible(ui.bindingMenu) and ui.frame:IsShown() and not ui.escapeModal,"Escape closed the main window or retained the modal")
    keys.MOUSEWHEELUP:Click(); ui:ShowPage("Settings")
    assert(not visible(ui.bindingMenu) and not ui.escapeModal,"Page navigation retained a stale binding menu")
    ui:ShowPage("Bindings"); keys.MOUSEWHEELUP:Click()
    ui:SetBindingSource("draft")
    assert(not visible(ui.bindingMenu) and not ui.escapeModal,"Switching layouts retained a stale binding menu")
    ui:SetBindingSource("current"); keys.MOUSEWHEELUP:Click()
    Mock.combat=true; Mock:Fire("PLAYER_REGEN_DISABLED")
    assert(not visible(ui.bindingMenu) and not ui.escapeModal,"Combat retained a binding edit menu")
    assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end

function Tests.binding_menu_arbitrary_macro_explains_why_targeting_is_unavailable()
    local k,ui=wheelMenu()
    Mock.bindings.F="MACRO UserMacro"; Mock:Fire("UPDATE_BINDINGS"); Mock:Advance(0.2)
    ui.pages.Bindings.keyboard.keys.F:Click()
    assert(ui.bindingMenu.targetMode:IsShown() and not ui.bindingMenu.targetMode:IsEnabled(),"Unsupported targeting was silently hidden or enabled")
    assert(ui.bindingMenu.targetHint:GetText()~="","Unsupported action has no targeting explanation")
    assert(select(3,GetMacroInfo(1))=="/say preserved" and not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end

function Tests.binding_menu_replacement_opens_an_explicit_destination_without_rebinding()
    local k,ui,keys=wheelMenu(); local saved=k:Export()
    keys.MOUSEWHEELUP:Click(); ui.bindingMenu.change:Click()
    assert(not visible(ui.bindingMenu) and not visible(ui.capture),"Replace spell started key capture")
    assert(visible(ui.replacementPicker) and ui.replacementPicker.key=="MOUSEWHEELUP","Replacement lost the selected wheel destination")
    assert(not k.CurrentBindings:HasEdits() and k:Export()==saved and #Mock.writes==0,"Opening replacement edited the layout")
    local picker=ui.replacementPicker
    picker.search:SetText("Regrowth"); picker.search:GetScript("OnTextChanged")(picker.search,true)
    local row
    for _,candidate in ipairs(picker.list.rows) do
        if candidate:IsShown() and candidate.entry.spellID==8936 then row=candidate; break end
    end
    assert(row,"Search did not find replacement spell")
    row:Click()
    assert(visible(ui.confirm) and not k.CurrentBindings:HasEdits(),"Replacement skipped the configured review")
    ui.confirm.acceptButton:Click(); Mock:Advance(0.05)
    local view=k.CurrentBindings:EditingView()
    assert(view.byKey.MOUSEWHEELUP.spellID==8936 and view.byKey.MOUSEWHEELDOWN.spellID==8936,"Replacing the wheel spell moved another binding")
    assert(view.byKey["1"].spellID==5176 and Mock.actions[1][2]==774 and #Mock.writes==0)
    assert(k:Export()==saved,"Replacing a Current spell changed the selected preset")
end
local function replacementRow(ui,id)
    for _,row in ipairs(ui.replacementPicker.list.rows) do if row:IsShown() and row.entry.spellID==id then return row end end
    error("Missing replacement spell "..tostring(id))
end
function Tests.binding_menu_replacement_rejects_changed_destination_before_event_arrives()
    local k,ui,keys=wheelMenu(); k.db.preferences.confirmReplacements=false
    keys.MOUSEWHEELUP:Click(); ui.bindingMenu.change:Click()
    Mock.bindings.MOUSEWHEELUP="ACTIONBUTTON2"
    replacementRow(ui,8936):Click()
    assert(not visible(ui.replacementPicker) and not k.CurrentBindings:HasEdits(),"A stale picker replaced a different destination")
    assert(Mock.actions[1][2]==774 and Mock.actions[2][2]==8936 and #Mock.writes==0)
    assert(ui.notice and ui.notice:find("changed"),"Stale destination was not explained")
end
function Tests.binding_menu_replacement_checks_live_content_even_with_staged_targeting()
    local k,ui,keys=wheelMenu(); k.db.preferences.confirmReplacements=false
    keys.MOUSEWHEELUP:Click(); targetChoice(ui,"Mouseover"); ui.bindingMenu.change:Click()
    Mock.actions[1]={"spell",8936}
    replacementRow(ui,8936):Click()
    assert(not visible(ui.replacementPicker),"Live slot changes were masked by the staged preview")
    local entry=k.CurrentBindings:Edits().slots[1]
    assert(entry.spellID==774 and entry.targetMode=="mouseover","Stale replacement overwrote the earlier targeting edit")
    assert(#Mock.writes==0)
end
function Tests.binding_menu_staged_current_replacement_keeps_selected_slot()
    local k,ui,keys=wheelMenu(); k.db.preferences.confirmReplacements=false
    keys.MOUSEWHEELUP:Click(); targetChoice(ui,"Mouseover"); ui.bindingMenu.change:Click()
    replacementRow(ui,8936):Click()
    local entry=k.CurrentBindings:Edits().slots[1]
    assert(entry.spellID==8936 and not entry.targetMode,"Valid staged Current replacement was blocked or retained old targeting")
    assert(not k.CurrentBindings:Edits().keys.MOUSEWHEELUP and Mock.actions[1][2]==774 and #Mock.writes==0)
end
function Tests.binding_menu_current_route_events_close_stale_editors()
    local k,ui,keys=wheelMenu()
    for _,event in ipairs({"UPDATE_BINDINGS","ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","UPDATE_MACROS","UPDATE_SHAPESHIFT_FORM"}) do
        keys.MOUSEWHEELUP:Click(); Mock:Fire(event,1)
        assert(not visible(ui.bindingMenu),event.." retained the binding menu")
        Mock:Advance(0.2); keys.MOUSEWHEELUP:Click(); ui.bindingMenu.change:Click(); Mock:Fire(event,1)
        assert(not visible(ui.replacementPicker),event.." retained the replacement picker")
        Mock:Advance(0.2); keys.MOUSEWHEELUP:Click(); ui.bindingMenu.rebind:Click(); Mock:Fire(event,1)
        assert(not visible(ui.capture),event.." retained key capture")
        Mock:Advance(0.2)
    end
    assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.binding_menu_change_key_rejects_stale_source_before_capture_or_assignment()
    local k,ui,keys=wheelMenu()
    keys.MOUSEWHEELUP:Click(); Mock.bindings.MOUSEWHEELUP="ACTIONBUTTON2"; ui.bindingMenu.rebind:Click()
    assert(not visible(ui.capture) and not k.CurrentBindings:HasEdits(),"Change key accepted the stale menu action")
    keys.MOUSEWHEELUP:Click(); ui.bindingMenu.rebind:Click()
    assert(visible(ui.capture)); Mock.bindings.MOUSEWHEELUP="ACTIONBUTTON1"
    Mock:KeyDown("F9"); Mock:KeyUp("F9"); Mock:Advance(0.05)
    assert(not visible(ui.capture) and not k.CurrentBindings:HasEdits(),"Capture moved the old command after its source changed")
    assert(GetBindingAction("F9")=="" and #Mock.writes==0)
end
