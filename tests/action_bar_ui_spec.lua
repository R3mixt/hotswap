-- These fixtures model the public routing used by supported bar addons. They
-- exercise Hot Swap's menu and transaction path, not addon secure execution.
local function barUI(provider,key)
    local k=TestAddon
    local route={provider=provider,key=key or "MOUSEWHEELUP",slot=73,kind="action"}
    local frameName,mouse
    if provider=="Bartender4" then frameName,mouse="BT4Button7","Keybind"
    elseif provider=="ElvUI" then frameName,mouse="ElvUI_Bar1Button7","LeftButton"
    else frameName,mouse="DominosActionButton7Hotkey","HOTKEY" end
    if provider=="Dominos" then
        route.parent=CreateFrame("Button","DominosActionButton7",UIParent)
        route.parent.GetAction=false -- Dominos uses secure attributes, not LibActionButton.
        route.parent:SetAttribute("type","action"); route.parent:SetAttribute("action",route.slot)
        route.frame=CreateFrame("Button",frameName,route.parent)
        route.frame:SetAttribute("type","action"); route.frame:SetAttribute("useparent-action",true)
        function route:SetSlot(value) self.slot=value; self.parent:SetAttribute("action",value) end
    else
        route.frame=CreateFrame("Button",frameName,UIParent)
        route.frame.action=7 -- The display/button number is deliberately stale.
        route.frame:SetAttribute("type","action"); route.frame:SetAttribute("action",7)
        route.frame.GetAction=function() return route.kind,route.slot end
        function route:SetSlot(value) self.slot=value end
    end
    route.effective="CLICK "..frameName..":"..mouse
    Mock.bindings={[route.key]="ACTIONBUTTON1",MOUSEWHEELDOWN="ACTIONBUTTON2",F="OPENCHAT"}
    Mock.bindingInventory=nil
    Mock.actions={[1]={"spell",5176},[2]={"spell",339},[7]={"spell",5185},[73]={"spell",774},[74]={"spell",8936}}
    local base=GetBindingAction
    GetBindingAction=function(currentKey,checkOverride)
        local overridden=route.followSaved and base(currentKey)=="ACTIONBUTTON1" or not route.followSaved and currentKey==route.key
        if checkOverride and overridden then return route.effective end
        return base(currentKey)
    end
    k:Init(); k.UI:Open(); Mock:ResetWrites()
    return k,k.UI,route
end
local function clickTarget(ui,label)
    ui.bindingMenu.targetMode:Click()
    for _,row in ipairs(ui.menu.panel.rows) do
        if row:IsShown() and row.text:GetText():gsub("^> ","")==label then row:Click(); return end
    end
    error("Missing targeting option "..label)
end
local function chooseReplacement(ui,key,spellID)
    ui.pages.Bindings.keyboard.keys[key]:Click(); ui.bindingMenu.change:Click()
    local picker=ui.replacementPicker
    picker.search:SetText("Regrowth"); picker.search:GetScript("OnTextChanged")(picker.search,true)
    for _,row in ipairs(picker.list.rows) do
        if row:IsShown() and row.entry.spellID==spellID then row:Click(); return end
    end
    error("Replacement search omitted Regrowth")
end
local function apply(k)
    local result,why=k.Engine:ApplyCurrentEdits(); assert(result=="pending",why)
    local ok,message=Mock:Drain(); assert(ok,message)
end

for _,provider in ipairs({"Bartender4","ElvUI","Dominos"}) do
    local owner=provider
    Tests["action_bar_ui_"..owner:lower().."_shows_effective_wheel_spell_instead_of_saved_native_slot"]=function()
        local k,ui,route=barUI(owner); local saved=k:Export()
        local cap=ui.pages.Bindings.keyboard.keys[route.key]
        assert(cap.action.spellID==774 and cap.action.liveSlot==73,"Current showed the saved native slot or guessed the addon button number")
        assert(cap.action.effectiveCommand==route.effective and cap.action.command=="ACTIONBUTTON1","Effective and saved binding commands were conflated")
        cap:Click()
        assert(ui.bindingMenu:IsShown() and ui.bindingMenu.action.spellID==774)
        assert(ui.bindingMenu.key:GetText():find(owner,1,true) and ui.pages.Bindings.detail.desc:GetText():find(owner,1,true),"Supported bar owner is absent from the edit context")
        assert(cap.tipDetail:find(owner,1,true),"Key tooltip omitted its action-bar owner")
        assert(ui.bindingMenu.targetMode:IsEnabled(),"Supported bar spell has no targeting editor")
        assert(not k.CurrentBindings:HasEdits() and k:Export()==saved and #Mock.writes==0)
    end
end

function Tests.action_bar_ui_bartender_mouseover_changes_only_the_effective_slot()
    local k,ui,route=barUI("Bartender4"); local saved=k:Export()
    ui.pages.Bindings.keyboard.keys[route.key]:Click(); clickTarget(ui,"Mouseover")
    local staged=k.CurrentBindings:EditingView().byKey[route.key]
    assert(staged.liveSlot==73 and staged.spellID==774 and staged.targetMode=="mouseover")
    assert(staged.currentEntry.body:find("[@mouseover,help,nodead]",1,true))
    assert(Mock.actions[73][1]=="spell" and Mock.actions[1][2]==5176 and #Mock.writes==0)
    ui.bindingMenu.done:Click(); apply(k)
    assert(Mock.actions[73][1]=="macro" and Mock.actions[1][1]=="spell" and Mock.actions[1][2]==5176,"Apply changed the saved slot instead of the effective slot")
    local _,_,body=GetMacroInfo(Mock.actions[73][2]); assert(body:find("[@mouseover,help,nodead]",1,true))
    assert(Mock.bindings[route.key]=="ACTIONBUTTON1" and GetBindingAction(route.key,true)==route.effective,"Targeting rewrote the addon-owned route")
    assert(route.frame.action==7 and route.frame:GetAttribute("action")==7,"Editing wrote addon button state")
    assert(k:Export()==saved and #k.Engine:ListBackups()==1)
end

for _,data in ipairs({{"ElvUI","BUTTON4"},{"Dominos","MOUSEWHEELUP"}}) do
    local owner,key=data[1],data[2]
    Tests["action_bar_ui_"..owner:lower().."_replacement_keeps_key_and_uses_effective_slot"]=function()
        local k,ui,route=barUI(owner,key); local saved=k:Export()
        chooseReplacement(ui,key,8936)
        assert(ui.confirm:IsShown() and not k.CurrentBindings:HasEdits(),"Replacement skipped its configured review")
        ui.confirm.acceptButton:Click(); Mock:Advance(0.05)
        assert(k.CurrentBindings:EditingView().byKey[key].spellID==8936 and #Mock.writes==0)
        apply(k)
        assert(Mock.actions[73][1]=="spell" and Mock.actions[73][2]==8936,"Replacement missed the addon effective slot")
        assert(Mock.actions[1][2]==5176 and Mock.actions[7][2]==5185 and Mock.actions[2][2]==339,"Replacement touched unrelated native/button-number slots")
        assert(Mock.bindings[key]=="ACTIONBUTTON1" and GetBindingAction(key,true)==route.effective and k:Export()==saved)
    end
end

function Tests.action_bar_ui_page_change_during_replacement_review_rejects_stale_destination()
    local k,ui,route=barUI("Dominos")
    chooseReplacement(ui,route.key,8936)
    assert(ui.confirm:IsShown()); route:SetSlot(74)
    ui.confirm.acceptButton:Click(); Mock:Advance(0.05)
    assert(not k.CurrentBindings:HasEdits(),"Confirmation applied to a slot the user did not review")
    assert(Mock.actions[73][2]==774 and Mock.actions[74][2]==8936 and #Mock.writes==0)
    assert(#k.Engine:ListBackups()==0)
end

function Tests.action_bar_ui_page_change_after_targeting_stages_rejects_before_backup()
    local k,ui,route=barUI("ElvUI")
    ui.pages.Bindings.keyboard.keys[route.key]:Click(); clickTarget(ui,"Mouseover")
    ui.bindingMenu.done:Click(); route:SetSlot(74); Mock:ResetWrites()
    local ok,why=k.Engine:ApplyCurrentEdits()
    assert(ok==false and why,"Apply accepted an addon action page that changed after review")
    assert(#Mock.writes==0 and #k.Engine:ListBackups()==0,"Stale action route was detected after writes or backup")
    assert(k.CurrentBindings:HasEdits() and Mock.actions[73][2]==774 and Mock.actions[74][2]==8936)
end

function Tests.action_bar_ui_replaced_override_after_targeting_rejects_before_backup()
    local k,ui,route=barUI("Bartender4")
    ui.pages.Bindings.keyboard.keys[route.key]:Click(); clickTarget(ui,"Mouseover")
    ui.bindingMenu.done:Click()
    local other=CreateFrame("Button","ElvUI_Bar1Button8",UIParent)
    other.GetAction=function() return "action",73 end
    route.effective="CLICK ElvUI_Bar1Button8:LeftButton"; Mock:ResetWrites()
    local ok,why=k.Engine:ApplyCurrentEdits()
    assert(ok==false and why,"Replacing the effective binding escaped stale-route validation because its slot matched")
    assert(#Mock.writes==0 and #k.Engine:ListBackups()==0 and k.CurrentBindings:HasEdits())
end

for _,state in ipairs({"custom-macro","unknown-addon"}) do
    local unavailable=state
    Tests["action_bar_ui_"..unavailable:gsub("-","_").."_remains_inspectable_with_disabled_edits_and_reason"]=function()
        local k,ui,route=barUI("Bartender4")
        if unavailable=="custom-macro" then route.kind="macro"
        else route.effective="CLICK UnknownActionButton7:LeftButton" end
        Mock:Fire("UPDATE_BINDINGS"); Mock:Advance(0.2)
        local cap=ui.pages.Bindings.keyboard.keys[route.key]
        local why=cap.action.actionBarError
        assert(why and cap.tipDetail:find(why,1,true),"Unsupported route has no visible tooltip explanation")
        cap:Click()
        local menu,detail=ui.bindingMenu,ui.pages.Bindings.detail
        assert(menu:IsShown() and menu.targetHint:GetText()==why,"Unsupported route cannot be inspected or has a generic targeting hint")
        for _,name in ipairs({"targetMode","rebind","change","clear"}) do assert(not menu[name]:IsEnabled(),"Unsupported route enabled "..name) end
        for _,name in ipairs({"rebind","change","reset"}) do assert(not detail[name]:IsEnabled(),"Detail bypasses disabled "..name) end
        assert(detail.desc:GetText()==why and detail.tipDetail:find(why,1,true))
        ui:BeginActionCapture(cap.action); ui:OpenReplacementPicker(cap.action)
        assert(not ui.capture or not ui.capture:IsShown())
        assert(not ui.replacementPicker or not ui.replacementPicker:IsShown())
        assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
        menu.done:Click(); Mock:Advance(0.05)
        ui.pages.Bindings.keyboard.keys.MOUSEWHEELDOWN:Click()
        assert(ui.bindingMenu.targetMode:IsEnabled() and ui.bindingMenu.change:IsEnabled() and ui.bindingMenu.rebind:IsEnabled(),"One unsupported route disabled unrelated native bindings")
    end
end

function Tests.action_bar_ui_override_change_while_menu_open_requires_reselection()
    local k,ui,route=barUI("Bartender4")
    ui.pages.Bindings.keyboard.keys[route.key]:Click()
    local other=CreateFrame("Button","ElvUI_Bar1Button8",UIParent)
    other.GetAction=function() return "action",73 end
    route.effective="CLICK ElvUI_Bar1Button8:LeftButton"
    ui.bindingMenu.change:Click()
    assert(not ui.bindingMenu:IsShown() and (not ui.replacementPicker or not ui.replacementPicker:IsShown()),"A stale menu opened a replacement flow for a newly routed action")
    assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end

function Tests.action_bar_ui_change_key_preserves_effective_spell_when_addon_remaps_its_override()
    local k,ui,route=barUI("Bartender4"); route.followSaved=true
    ui.pages.Bindings.keyboard.keys[route.key]:Click(); ui.bindingMenu.rebind:Click()
    Mock:KeyDown("F9"); Mock:KeyUp("F9"); Mock:Advance(0.05)
    assert(k.CurrentBindings:EditingView().byKey.F9.spellID==774,"Rebind preview showed the saved native spell instead of the active addon spell")
    apply(k)
    k.CurrentBindings:Invalidate()
    local view=k.CurrentBindings:EditingView()
    assert(view.byKey.F9.spellID==774 and view.byKey.F9.liveSlot==73,"Successful rebind changed which spell the key activates")
    assert(GetBindingAction("F9")=="ACTIONBUTTON1" and GetBindingAction("F9",true)==route.effective)
    assert(GetBindingAction(route.key)=="" and GetBindingAction(route.key,true)=="","Old addon-owned key remained active after a successful move")
    assert(Mock.actions[1][2]==5176 and Mock.actions[73][2]==774 and not k.CurrentBindings:HasEdits())
end

function Tests.action_bar_ui_frozen_override_rebind_rolls_back_instead_of_installing_wrong_spell()
    local k,ui,route=barUI("Bartender4")
    ui.pages.Bindings.keyboard.keys[route.key]:Click(); ui.bindingMenu.rebind:Click()
    Mock:KeyDown("F9"); Mock:KeyUp("F9"); Mock:Advance(0.05)
    assert(k.CurrentBindings:HasEdits())
    assert(k.Engine:ApplyCurrentEdits()=="pending")
    local ok,why=Mock:Drain()
    assert(ok==false and why,"Apply reported success although the addon retained the old override and F9 would cast another spell")
    assert(GetBindingAction(route.key)=="ACTIONBUTTON1" and GetBindingAction(route.key,true)==route.effective)
    assert(GetBindingAction("F9")=="" and Mock.actions[1][2]==5176 and Mock.actions[73][2]==774,"Rollback did not restore the original binding layout")
    assert(k.CurrentBindings:HasEdits(),"Failed rebind discarded the user's pending draft")
end
