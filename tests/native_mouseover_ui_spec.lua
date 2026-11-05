local function nativeMouseoverUI(enabled)
    local k=TestAddon
    Mock.build="1.60.1"
    IsMouseoverCastSupported=function() return true end
    Mock.cvars.enableMouseoverCast=enabled and "1" or "0"
    Mock.cvars.autoSelfCast=enabled and "1" or "0"
    Mock.modified.MOUSEOVERCAST=enabled and "NONE" or "SHIFT"
    Mock.bindings={MOUSEWHEELUP="ACTIONBUTTON1",F="MACRO UserMacro"}
    Mock.bindingInventory=nil; Mock.actions={[1]={"spell",774}}
    k:Init(); k.UI:Open(); Mock:ResetWrites()
    return k,k.UI,k.UI.pages.Bindings.autoMouseover
end

function Tests.native_mouseover_ui_checkbox_stages_until_apply_and_creates_no_spell_macros()
    local k,ui,checkbox=nativeMouseoverUI(false)
    local saved=k:Export(); local account,character=GetNumMacros()
    assert(checkbox:IsShown() and checkbox:IsEnabled() and not checkbox:GetChecked())
    assert(not ui.pages.Bindings.form:IsShown() and not ui.pages.Bindings.follow:IsShown(),"Current checkbox overlaps old form controls")
    checkbox:Click()
    assert(checkbox:GetChecked() and k.CurrentBindings:GetNativeMouseoverState().pending)
    assert(ui.apply:IsEnabled() and ui.discard:IsEnabled())
    assert(Mock.cvars.enableMouseoverCast=="0" and Mock.cvars.autoSelfCast=="0" and Mock.modified.MOUSEOVERCAST=="SHIFT" and #Mock.writes==0)
    assert(k:Export()==saved,"Current checkbox changed the selected preset")
    ui.apply:Click(); assert(k.Engine.busy,"Apply button did not start the backed-up setting update")
    local ok,why=Mock:Drain(); assert(ok,why); Mock:Advance(0.2)
    assert(Mock.cvars.enableMouseoverCast=="1" and Mock.cvars.autoSelfCast=="1" and Mock.modified.MOUSEOVERCAST=="NONE")
    assert(checkbox:GetChecked() and not k.CurrentBindings:HasEdits() and not ui.apply:IsEnabled())
    assert(Mock.actions[1][1]=="spell" and Mock.actions[1][2]==774 and Mock.bindings.MOUSEWHEELUP=="ACTIONBUTTON1")
    assert(select(3,GetMacroInfo(GetMacroIndexByName("UserMacro")))=="/say preserved")
    local newAccount,newCharacter=GetNumMacros(); assert(account==newAccount and character==newCharacter,"Global mouseover allocated per-spell macros")
    assert(#k.Engine:ListBackups()==1 and k:Export()==saved)
end

function Tests.native_mouseover_ui_discard_restores_the_live_checkbox_without_writes()
    local k,ui,checkbox=nativeMouseoverUI(true)
    assert(checkbox:GetChecked()); checkbox:Click()
    assert(not checkbox:GetChecked() and k.CurrentBindings:HasEdits())
    ui.discard:Click()
    assert(ui.confirm:IsShown() and not checkbox:GetChecked(),"Discard did not wait for its confirmation")
    ui.confirm.acceptButton:Click(); Mock:Advance(0.05)
    assert(checkbox:GetChecked() and not k.CurrentBindings:HasEdits() and not ui.apply:IsEnabled())
    assert(Mock.cvars.enableMouseoverCast=="1" and Mock.cvars.autoSelfCast=="1" and Mock.modified.MOUSEOVERCAST=="NONE" and #Mock.writes==0)
end

function Tests.native_mouseover_ui_capability_and_combat_disable_the_checkbox()
    local k,ui,checkbox=nativeMouseoverUI(false)
    IsMouseoverCastSupported=function() return false end; ui:Refresh()
    assert(checkbox:IsShown() and not checkbox:IsEnabled() and not checkbox:GetChecked())
    assert(checkbox.tipDetail==k.API:GetNativeMouseoverState().reason,"Unsupported checkbox has no capability explanation")
    checkbox:Click(); assert(not k.CurrentBindings:HasEdits() and not checkbox:GetChecked() and #Mock.writes==0)
    IsMouseoverCastSupported=function() return true end; ui:Refresh(); assert(checkbox:IsEnabled())
    Mock.combat=true; Mock:Fire("PLAYER_REGEN_DISABLED"); Mock:Advance(0.2)
    assert(not checkbox:IsEnabled(),"Combat left the setting control enabled")
    checkbox:Click(); assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
    Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED"); Mock:Advance(0.2)
    assert(checkbox:IsEnabled(),"Leaving combat did not restore the setting control")
end

function Tests.native_mouseover_ui_preset_view_hides_checkbox_and_preserves_current_draft()
    local k,ui,checkbox=nativeMouseoverUI(false); local saved=k:Export()
    checkbox:Click(); assert(k.CurrentBindings:HasEdits())
    ui:SetBindingSource("draft")
    assert(not checkbox:IsShown() and ui.pages.Bindings.form:IsShown() and ui.pages.Bindings.follow:IsShown())
    ui:Refresh()
    assert(k.CurrentBindings:GetNativeMouseoverState().enabled and k.CurrentBindings:GetNativeMouseoverState().pending)
    assert(k:Export()==saved and Mock.cvars.enableMouseoverCast=="0" and #Mock.writes==0,"Opening a preset applied or overwrote Current's setting edit")
    ui:SetBindingSource("current")
    assert(checkbox:IsShown() and checkbox:GetChecked() and ui.apply:IsEnabled())
end
