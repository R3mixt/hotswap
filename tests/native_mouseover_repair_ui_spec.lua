local function legacyMouseoverUI()
    local k=TestAddon
    Mock.build="1.60.1"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
    Mock:Learn(774,"Rejuvenation"); Mock:Learn(8936,"Regrowth"); Mock:Learn(5185,"Healing Touch")
    IsMouseoverCastSupported=function() return true end
    Mock.cvars.enableMouseoverCast="0"; Mock.cvars.autoSelfCast="0"; Mock.modified.MOUSEOVERCAST="NONE"
    Mock.bindings={MOUSEWHEELUP="ACTIONBUTTON1",MOUSEWHEELDOWN="ACTIONBUTTON2",G="OPENCHAT",F="MACRO UserMacro"}
    Mock.bindingInventory=nil; Mock.actions={}; k:Init()
    k.db.ownedMacros=k.db.ownedMacros or {}; k.db.currentLayout={keys={},slots={}}
    local old={}
    for slot,spell in ipairs({{774,"Rejuvenation"},{8936,"Regrowth"}}) do
        local body="#showtooltip "..spell[2].."\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] "..spell[2]
        local name=k.Macros:Name(body)
        CreateMacro(name,spell[1],body,true); k.db.ownedMacros[name]=body
        local entry={spellID=spell[1],name=spell[2],label=spell[2],targetMode="mouseover",detached=true,body=body,macroName=name,
            command="MACRO "..name,content={kind="macro",name=name,body=body}}
        k.db.currentLayout.slots[slot]=entry; old[slot]=entry
    end
    -- Macro indices can move as the character bank sorts; use final indices.
    for slot,entry in ipairs(old) do Mock.actions[slot]={"macro",GetMacroIndexByName(entry.macroName)} end
    k.CurrentBindings:Invalidate(); k.UI:Open(); Mock:ResetWrites()
    return k,k.UI,k.UI.pages.Bindings.autoMouseover,old
end

function Tests.native_mouseover_repair_ui_checkbox_previews_owned_legacy_heals_before_apply()
    local k,ui,checkbox,old=legacyMouseoverUI()
    assert(ui.bindingPlan.byKey.MOUSEWHEELUP.kind=="macroref" and not checkbox:GetChecked())
    checkbox:Click()
    local view=ui.bindingPlan
    assert(checkbox:GetChecked() and k.CurrentBindings:GetNativeMouseoverState().repairCount==2)
    for _,key in ipairs({"MOUSEWHEELUP","MOUSEWHEELDOWN"}) do
        assert(view.byKey[key].kind=="spell" and view.byKey[key].targetMode=="mouseover")
        assert(view.byKey[key].currentEntry.body:find("[help,nodead][@player]",1,true),"Checkbox preview kept the old heal without self fallback")
        assert(ui.pages.Bindings.keyboard.keys[key].targetBadge:GetText()=="M")
    end
    assert(#Mock.writes==0 and ui.apply:IsEnabled())
    for _,entry in ipairs(old) do
        assert(entry.detached and select(3,GetMacroInfo(GetMacroIndexByName(entry.macroName)))==entry.body,"Staging modified or re-adopted the installed macro")
    end
    ui.apply:Click(); assert(k.Engine.busy)
    local ok,why=Mock:Drain(); assert(ok,why); Mock:Advance(0.2)
    for slot=1,2 do
        assert(Mock.actions[slot][1]=="macro")
        local _,_,body=GetMacroInfo(Mock.actions[slot][2]); assert(body:find("[help,nodead][@player]",1,true))
    end
    assert(select(3,GetMacroInfo(GetMacroIndexByName("UserMacro")))=="/say preserved")
    assert(not k.CurrentBindings:HasEdits() and #k.Engine:ListBackups()==1)
end

function Tests.native_mouseover_repair_ui_discard_removes_repair_preview_without_readopting_cache()
    local k,ui,checkbox,old=legacyMouseoverUI()
    checkbox:Click(); assert(k.CurrentBindings:GetNativeMouseoverState().repairCount==2)
    ui.discard:Click(); assert(ui.confirm:IsShown())
    ui.confirm.acceptButton:Click(); Mock:Advance(0.05)
    assert(not checkbox:GetChecked() and not k.CurrentBindings:HasEdits() and not ui.apply:IsEnabled())
    assert(ui.bindingPlan.byKey.MOUSEWHEELUP.kind=="macroref" and not ui.bindingPlan.byKey.MOUSEWHEELUP.currentEntry)
    for _,entry in ipairs(old) do
        assert(entry.detached and select(3,GetMacroInfo(GetMacroIndexByName(entry.macroName)))==entry.body)
    end
    assert(Mock.cvars.enableMouseoverCast=="0" and #Mock.writes==0 and #k.Engine:ListBackups()==0)
end

function Tests.native_mouseover_repair_ui_unchecking_keeps_prior_spell_and_key_edits()
    local k,ui,checkbox,old=legacyMouseoverUI()
    assert(k.CurrentBindings:StageEntry({spellID=5185,label="Healing Touch"},"MOUSEWHEELUP"))
    assert(k.CurrentBindings:Rebind(k.CurrentBindings:EditingView().byKey.G,"F9"))
    ui.currentBindingPlan=nil; ui:Refresh()
    checkbox:Click()
    assert(k.CurrentBindings:GetNativeMouseoverState().repairCount==1,"Checkbox repair replaced an existing spell edit")
    assert(ui.bindingPlan.byKey.MOUSEWHEELUP.spellID==5185 and ui.bindingPlan.byKey.MOUSEWHEELDOWN.targetMode=="mouseover")
    checkbox:Click()
    assert(not checkbox:GetChecked() and k.CurrentBindings:HasEdits() and ui.apply:IsEnabled())
    assert(ui.bindingPlan.byKey.MOUSEWHEELUP.spellID==5185,"Unchecking lost the user's earlier spell replacement")
    assert(ui.bindingPlan.byKey.F9.command=="OPENCHAT" and not ui.bindingPlan.byKey.G,"Unchecking lost the user's earlier key edit")
    assert(ui.bindingPlan.byKey.MOUSEWHEELDOWN.kind=="macroref" and not ui.bindingPlan.byKey.MOUSEWHEELDOWN.currentEntry,"Unchecking retained a checkbox-generated repair")
    assert(k.CurrentBindings:Edits().slots[1].spellID==5185 and not k.CurrentBindings:Edits().slots[2])
    assert(old[1].detached and old[2].detached and #Mock.writes==0)
end

function Tests.native_mouseover_repair_ui_reenable_stages_repairs_when_native_setting_is_already_on()
    local k,ui,checkbox=legacyMouseoverUI()
    Mock.cvars.enableMouseoverCast="1"; Mock.cvars.autoSelfCast="1"; ui:Refresh()
    assert(checkbox:GetChecked() and not k.CurrentBindings:HasEdits())
    checkbox:Click(); assert(not checkbox:GetChecked())
    checkbox:Click()
    assert(checkbox:GetChecked() and k.CurrentBindings:GetNativeMouseoverState().repairCount==2)
    assert(k.CurrentBindings:HasEdits() and ui.apply:IsEnabled(),"Ending at the original native setting discarded explicit legacy macro repairs")
    assert(ui.bindingPlan.byKey.MOUSEWHEELUP.currentEntry.body:find("[help,nodead][@player]",1,true))
    assert(Mock.cvars.enableMouseoverCast=="1" and #Mock.writes==0)
end
