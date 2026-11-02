local function releaseUI()
    local k=TestAddon; k:Init(); k.UI:Open(); Mock:ResetWrites(); return k,k.UI
end
function Tests.release_ui_confirmation_preferences_are_local_and_independent()
    local k,ui=releaseUI(); local before=k:Export(); ui:ShowPage('Settings')
    local page=ui.pages.Settings; page.sectionButtons.Window:Click()
    assert(page.confirmReplacements:GetChecked() and page.confirmSwaps:GetChecked())
    page.confirmReplacements:Click()
    assert(not ui:ShouldConfirmBinding('replace') and ui:ShouldConfirmBinding('swap'))
    page.confirmSwaps:Click()
    assert(not ui:ShouldConfirmBinding('swap'))
    assert(k:Export()==before and #Mock.writes==0)
    k:Init(); assert(not ui:ShouldConfirmBinding('replace') and not ui:ShouldConfirmBinding('swap'))
end
function Tests.release_ui_native_spellbook_drop_confirm_cancel_and_accept()
    local k,ui=releaseUI(); local id=Mock.spells[1].id
    Mock.cursor={'spell',1,'spell',id}
    local cap=ui.pages.Bindings.keyboard.keys.F
    cap:GetScript('OnReceiveDrag')(cap)
    assert(ui.confirm and ui.confirm:IsShown() and not k.CurrentBindings:HasEdits())
    assert(not Mock.cursor,'Accepted drag payload retained the cursor')
    ui.confirm:Hide(); assert(not k.CurrentBindings:HasEdits())
    k.SettingsUI:SetLocalPreference('confirmReplacements',false)
    Mock.cursor={'spell',1,'spell',id}; cap:GetScript('OnReceiveDrag')(cap)
    assert(k.CurrentBindings:HasEdits() and not Mock.cursor and #Mock.writes==0)
    assert(ui.bindingPlan.byKey.F.spellID==id)
end
function Tests.release_ui_native_spellbook_legacy_index_lookup_and_invalid_payload()
    local k,ui=releaseUI(); local id=Mock.spells[1].id
    Mock.cursor={'spell',1,'spell'}
    assert(ui:ReceiveSpellDrop('F12'))
    assert(ui.bindingPlan.byKey.F12.spellID==id and not Mock.cursor)
    Mock.cursor={'item',1710}; assert(not ui:ReceiveSpellDrop('F11') and Mock.cursor)
    Mock.cursor={'spell',999999,'spell'}; assert(not ui:ReceiveSpellDrop('F11') and Mock.cursor)
    assert(#Mock.writes==0)
end
function Tests.release_ui_drop_respects_combat_recommendation_and_modal()
    local k,ui=releaseUI(); local id=Mock.spells[1].id
    Mock.cursor={'spell',1,'spell',id}; Mock.combat=true
    assert(not ui:ReceiveSpellDrop('F12') and not k.CurrentBindings:HasEdits() and Mock.cursor)
    Mock.combat=false; ui:Confirm('Test','Test',function() end)
    assert(not ui:ReceiveSpellDrop('F12') and not k.CurrentBindings:HasEdits())
    ui.confirm:Hide(); ui.bindingSource='recommendation'
    assert(not ui:ReceiveSpellDrop('F12'))
    ui.libraryEntry={spellID=id,label='Spell'}; assert(not ui:DropLibraryEntry('F12'))
    assert(#Mock.writes==0)
end
function Tests.release_ui_native_spellbook_is_mouse_accessible_and_shield_returns()
    local k,ui=releaseUI(); assert(ui.testMouseShield:IsShown())
    SpellBookFrame=CreateFrame('Frame'); SpellBookFrame:Show(); Mock:Advance(0.1)
    assert(not ui.testMouseShield:IsShown())
    assert(ui.pages.Bindings.keyboard.note:GetText():find('normal game controls',1,true))
    SpellBookFrame:Hide(); Mock:Advance(0.1); assert(ui.testMouseShield:IsShown())
end
function Tests.release_ui_default_reset_always_requires_confirmation()
    local k,ui=releaseUI(); ui:ShowPage('Safety')
    k.db.preferences.confirmReplacements=false; k.db.preferences.confirmSwaps=false
    ui.pages.Safety.defaults:Click()
    assert(ui.confirm:IsShown() and ui.confirm.title:GetText():find('default keybinds',1,true))
    assert(#Mock.writes==0)
end

function Tests.release_ui_swap_can_be_disabled_without_disabling_apply_review()
    local k,ui=releaseUI(); ui:SetBindingSource('draft'); ui:SetActionPage('cat')
    local source
    for _,a in ipairs(ui.plan.actions) do if a.id=='druid.claw.cat' then source=a end end
    assert(source and source.key=='1')
    k.SettingsUI:SetLocalPreference('confirmSwaps',false)
    assert(ui:AssignBinding(source,'2'))
    assert(not ui.confirm or not ui.confirm:IsShown())
    for _,a in ipairs(ui.plan.actions) do
        if a.form~='all' and (a.barSlot==1 or a.barSlot==2) then assert(a.key==(a.barSlot==1 and '2' or '1')) end
    end
    assert(#Mock.writes==0 and k.dirty)
end
function Tests.release_ui_game_spellbook_button_opens_and_restores_mouse_access()
    local k,ui=releaseUI()
    ToggleSpellBook=function(bank) assert(bank=='spell'); SpellBookFrame=CreateFrame('Frame'); SpellBookFrame:Show() end
    ui.library.nativeBook:Click()
    assert(SpellBookFrame:IsShown() and not ui.testMouseShield:IsShown())
    assert(ui.library.tabs.game.tipDetail:find('movement, camera',1,true))
end
