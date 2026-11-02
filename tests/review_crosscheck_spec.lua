local function crosscheckUI()
    local k=TestAddon; k:Init(); k.UI:Open(); Mock:ResetWrites(); return k,k.UI
end
function Tests.crosscheck_native_drop_rejects_changed_key_before_confirmation()
    local k,ui=crosscheckUI()
    Mock.cursor={'spell',1,'spell',Mock.spells[1].id}; ui:ReceiveSpellDrop('F')
    assert(ui.confirm:IsShown()); Mock.bindings.F='TARGETSELF'
    ui.confirm.acceptButton:Click()
    assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
    assert(ui.notice:find('changed while you were reviewing',1,true))
end
function Tests.crosscheck_minibook_drop_rejects_changed_native_slot_before_confirmation()
    local k,ui=crosscheckUI()
    Mock.bindings['1']='ACTIONBUTTON1'; Mock.actions[1]={'spell',Mock.spells[1].id}
    ui.libraryEntry={spellID=Mock.spells[1].id,label='Spell'}; ui:DropLibraryEntry('1')
    assert(ui.confirm:IsShown()); Mock.actions[1]={'spell',999999}
    ui.confirm.acceptButton:Click()
    assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
    assert(ui.notice:find('changed while you were reviewing',1,true))
end
function Tests.crosscheck_native_drop_rejects_combat_started_during_confirmation()
    local k,ui=crosscheckUI()
    Mock.cursor={'spell',1,'spell',Mock.spells[1].id}; ui:ReceiveSpellDrop('F')
    assert(ui.confirm:IsShown()); Mock.combat=true; ui.confirm.acceptButton:Click()
    assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
