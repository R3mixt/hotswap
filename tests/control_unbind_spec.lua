local function controls()
 local k=TestAddon
 Mock.class='MAGE'; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 UnitClass=function() return 'Mage','MAGE',8 end
 Mock:Learn(133,'Fireball')
 Mock.bindings={W='MOVEFORWARD',UP='MOVEFORWARD',A='STRAFELEFT',D='STRAFERIGHT',LEFT='TURNLEFT',RIGHT='TURNRIGHT',SPACE='JUMP',
  BUTTON1='CAMERAORSELECTORMOVE',BUTTON2='TURNORACTION',['SHIFT-BUTTON1']='CAMERAORSELECTORMOVE',
  MOUSEWHEELUP='CAMERAZOOMIN',MOUSEWHEELDOWN='CAMERAZOOMOUT',F='OPENCHAT',G='OPENCHAT',ESCAPE='TOGGLEGAMEMENU'}
 Mock.bindingInventory=nil
 Mock.bindingSets[1]=k.Copy(Mock.bindings)
 k:Init(); Mock:ResetWrites()
 return k,k.CurrentBindings
end
local function applyCurrent(k)
 assert(k.Engine:ApplyCurrentEdits()=='pending')
 local ok,why=Mock:Drain(); assert(ok,why)
end
local function clear(k,key)
 local action=k.CurrentBindings:EditingView().byKey[key]
 assert(action,'Missing control '..key)
 local ok,why=k.CurrentBindings:ClearKey(action); assert(ok,why)
end

function Tests.controls_clear_movement_camera_and_mouse_are_sparse_and_saved()
 local k,c=controls(); local before=k.Copy(Mock.bindings)
 local keys={'W','A','D','LEFT','RIGHT','SPACE','MOUSEWHEELUP','MOUSEWHEELDOWN','BUTTON1','BUTTON2'}
 for _,key in ipairs(keys) do clear(k,key) end
 local view=c:EditingView()
 for _,key in ipairs(keys) do assert(not view.byKey[key] and GetBindingAction(key)==before[key]) end
 assert(#Mock.writes==0 and view.byKey.UP and view.byKey['SHIFT-BUTTON1'])
 applyCurrent(k)
 for _,key in ipairs(keys) do assert(GetBindingAction(key)=='' and not Mock.bindingSets[2][key]) end
 assert(GetBindingAction('UP')=='MOVEFORWARD' and GetBindingAction('SHIFT-BUTTON1')=='CAMERAORSELECTORMOVE')
 assert(GetBindingAction('G')=='OPENCHAT' and GetBindingAction('ESCAPE')=='TOGGLEGAMEMENU')
 for key,command in pairs(before) do assert(Mock.bindingSets[1][key]==command) end
 LoadBindings(2); k:Init(); Mock:Fire('PLAYER_LOGIN'); Mock:Fire('SPELLS_CHANGED'); Mock:Fire('PLAYER_REGEN_ENABLED'); Mock:Advance(.2); assert(Mock:Drain())
 for _,key in ipairs(keys) do assert(GetBindingAction(key)=='','Control resurrected: '..key) end
 assert(not c:HasEdits() and c:RefreshEdits()==nil)
end

function Tests.controls_clear_draft_survives_init_and_discard_leaves_live_keys()
 local k,c=controls(); clear(k,'BUTTON2'); clear(k,'W')
 c.edits=nil; k:Init()
 assert(c:HasEdits() and not c:EditingView().byKey.BUTTON2 and not c:EditingView().byKey.W)
 c:Discard()
 assert(c:EditingView().byKey.BUTTON2 and c:EditingView().byKey.W and #Mock.writes==0)
end

function Tests.controls_clear_pending_reservations_and_native_slot_keys()
 local k,c=controls(); Mock.catalog[999]={id=999,name='Future',icon=999}
 SetBinding('1','ACTIONBUTTON1'); c:Invalidate()
 assert(c:StageEntry({spellID=999,label='Future'},'1'))
 assert(c:StageEntry({spellID=999,label='Future'},'F9'))
 clear(k,'1'); clear(k,'F9'); applyCurrent(k)
 assert(GetBindingAction('1')=='' and GetBindingAction('F9')=='' and not k.db.currentLayout.keys.F9)
 Mock:Learn(999,'Future'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(.2); assert(Mock:Drain())
 assert(GetBindingAction('1')=='' and GetBindingAction('F9')=='')
end

function Tests.controls_clearing_one_modified_mouse_alias_preserves_other_aliases()
 local k=controls(); clear(k,'SHIFT-BUTTON1'); applyCurrent(k)
 assert(GetBindingAction('SHIFT-BUTTON1')=='' and GetBindingAction('BUTTON1')=='CAMERAORSELECTORMOVE')
 local backup=k.Engine:ListBackups()[1]; assert(backup)
 local ok,why=k.Engine:RestoreBackup(backup.id); assert(ok,why)
 assert(GetBindingAction('SHIFT-BUTTON1')=='CAMERAORSELECTORMOVE' and GetBindingAction('BUTTON1')=='CAMERAORSELECTORMOVE')
end

function Tests.controls_clearing_primary_buttons_can_be_restored_from_backup()
 local k=controls(); clear(k,'BUTTON1'); clear(k,'BUTTON2'); applyCurrent(k)
 local backup=k.Engine:ListBackups()[1]
 assert(GetBindingAction('BUTTON1')=='' and GetBindingAction('BUTTON2')=='')
 local ok,why=k.Engine:RestoreBackup(backup.id); assert(ok,why)
 assert(GetBindingAction('BUTTON1')=='CAMERAORSELECTORMOVE' and GetBindingAction('BUTTON2')=='TURNORACTION')
end

function Tests.controls_clear_failure_rolls_back_and_retains_the_draft()
 local k,c=controls(); Mock:AllowFullCatalogMacros(); assert(k:Apply())
 k.db.appliedPlan.mouseBindingsVersion=nil
 clear(k,'BUTTON2'); clear(k,'W')
 local set=SetBinding; local failed=false
 SetBinding=function(key,command,...)
  if key=='W' and not command and not failed then failed=true; return false end
  return set(key,command,...)
 end
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(not Mock:Drain())
 assert(GetBindingAction('W')=='MOVEFORWARD' and GetBindingAction('BUTTON2')=='TURNORACTION')
 assert(c:HasEdits() and c:Edits().keys.W==false and c:Edits().keys.BUTTON2==false)
 assert(k.db.appliedPlan.mouseBindingsVersion==nil,'Failed edit retired legacy recovery')
end

function Tests.controls_explicit_primary_clear_retires_legacy_mouse_recovery()
 local k,c=controls(); Mock:AllowFullCatalogMacros(); assert(k:Apply())
 k.db.appliedPlan.mouseBindingsVersion=nil
 clear(k,'W'); applyCurrent(k)
 assert(k.db.appliedPlan.mouseBindingsVersion==nil,'Unrelated key edit retired legacy recovery')
 assert(SetBinding('SHIFT-BUTTON1','CAMERAORSELECTORMOVE')); c:Invalidate()
 clear(k,'SHIFT-BUTTON1'); applyCurrent(k)
 assert(k.db.appliedPlan.mouseBindingsVersion==nil,'Modified alias edit retired legacy recovery')
 clear(k,'BUTTON2'); applyCurrent(k)
 assert(k.db.appliedPlan.mouseBindingsVersion==1)
 Mock:Fire('PLAYER_LOGIN'); Mock:Advance(.2); assert(Mock:Drain())
 assert(GetBindingAction('BUTTON2')=='' and GetBindingAction('BUTTON1')=='CAMERAORSELECTORMOVE')
end

function Tests.controls_supported_system_entries_restore_primary_mouse_without_macros()
 local k,c=controls(); clear(k,'BUTTON1'); clear(k,'BUTTON2'); applyCurrent(k)
 local account,character=GetNumMacros()
 assert(c:StageEntry({label='Camera',descriptor={kind='system',command='CAMERAORSELECTORMOVE'}},'BUTTON1'))
 assert(c:StageEntry({label='Turn',descriptor={kind='system',command='TURNORACTION'}},'BUTTON2'))
 assert(c:StageEntry({label='Move',descriptor={kind='system',command='MOVEFORWARD'}},'CTRL-BUTTON2'))
 applyCurrent(k)
 assert(GetBindingAction('BUTTON1')=='CAMERAORSELECTORMOVE' and GetBindingAction('BUTTON2')=='TURNORACTION')
 assert(GetBindingAction('CTRL-BUTTON2')=='MOVEFORWARD')
 local a,b=GetNumMacros(); assert(a==account and b==character)
end

function Tests.controls_primary_mouse_rebinds_allow_controls_and_reject_other_actions()
 local k,c=controls()
 assert(c:Rebind(c:EditingView().byKey.BUTTON2,'F9'))
 assert(c:Rebind(c:EditingView().byKey.F9,'CTRL-BUTTON2'))
 assert(not c:Rebind(c:EditingView().byKey.F,'BUTTON2'))
 assert(not c:StageEntry({spellID=133,label='Fireball'},'BUTTON1'))
 assert(not c:StageEntry({descriptor={kind='item',itemID=1710}},'SHIFT-BUTTON2'))
 assert(not c:StageEntry({descriptor={kind='system',command='OPENCHAT'}},'BUTTON2'))
 assert(not c:StageEntry({spellID=133,descriptor={kind='system',command='MOVEFORWARD'}},'BUTTON2'))
 assert(not c:StageEntry({descriptor={kind='system',command='UNSUPPORTED_CAMERA'}},'BUTTON2'))
 assert(not c:StageEntry({descriptor={kind='system',command='MOVEFORWARD'}},'ESCAPE'))
 assert(not c:ClearKey(c:EditingView().byKey.ESCAPE))
 assert(not c:Rebind(c:EditingView().byKey.ESCAPE,'F10'))
 applyCurrent(k)
 assert(GetBindingAction('BUTTON2')=='' and GetBindingAction('CTRL-BUTTON2')=='TURNORACTION' and GetBindingAction('F9')=='')
 assert(GetBindingAction('BUTTON1')=='CAMERAORSELECTORMOVE' and GetBindingAction('F')=='OPENCHAT')
end

function Tests.controls_clear_remains_unbound_after_protected_preset_and_maintenance()
 local k,c=controls(); Mock:AllowFullCatalogMacros()
 assert(k:Apply())
 for _,key in ipairs({'W','A','D','BUTTON1','BUTTON2','ALT-MOUSEWHEELUP'}) do clear(k,key) end
 applyCurrent(k)
 Mock:Fire('PLAYER_LOGIN'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(.2); assert(Mock:Drain())
 for _,key in ipairs({'W','A','D','BUTTON1','BUTTON2','ALT-MOUSEWHEELUP'}) do assert(GetBindingAction(key)=='','Login restored '..key) end
 k:UpdateSetting('preserveMovement',true); k:UpdateSetting('preserveCamera',true)
 local ok,why=k:Apply(); assert(ok,why)
 for _,key in ipairs({'W','A','D','BUTTON1','BUTTON2','ALT-MOUSEWHEELUP'}) do assert(GetBindingAction(key)=='','Protected preset restored '..key) end
 Mock:Learn(116,'Frostbolt'); Mock:Fire('SPELLS_CHANGED'); Mock:Fire('PLAYER_REGEN_ENABLED'); Mock:Advance(.2); assert(Mock:Drain())
 for _,key in ipairs({'W','A','D','BUTTON1','BUTTON2','ALT-MOUSEWHEELUP'}) do assert(GetBindingAction(key)=='','Maintenance restored '..key) end
end

function Tests.controls_capture_clear_cancel_and_accept_use_the_selected_alias()
 local k,c=controls(); k.UI:Open(); local ui=k.UI
 ui.pages.Bindings.keyboard.keys.W:Click()
 assert(ui.capture:IsShown() and ui.capture.clear:IsShown())
 assert(ui.captureNote:GetText():find('Apply changes',1,true) and not ui.captureNote:GetText():find('Apply & save',1,true))
 ui.capture.clear:Click(); assert(not ui.capture:IsShown() and ui.confirm:IsShown())
 ui.confirm.cancelButton:Click(); assert(not c:HasEdits())
 ui:BeginActionCapture(ui.bindingPlan.byKey.BUTTON2); ui.capture.clear:Click()
 assert(ui.confirm.detail:GetText():find('no longer turn',1,true) and ui.confirm.detail:GetText():find('interact with targets',1,true))
 ui.selectedAction=ui.bindingPlan.byKey.W
 ui.confirm.acceptButton:Click()
 assert(c:Edits().keys.BUTTON2==false and c:Edits().keys.W==nil and #Mock.writes==0)
 ui:BeginActionCapture(ui.bindingPlan.byKey.F); ui.capture.clear:Click(); ui.confirm.acceptButton:Click()
 assert(c:Edits().keys.F==false and c:EditingView().byKey.G.command=='OPENCHAT')
 ui:PromptClearCurrent(ui.bindingPlan.byKey.BUTTON1)
 assert(ui.confirm.detail:GetText():find('select targets in the world',1,true) and ui.confirm.detail:GetText():find('control the camera',1,true))
 ui.confirm.cancelButton:Click()
 ui:BeginActionCapture(ui.bindingPlan.byKey.ESCAPE); assert(not ui.capture.clear:IsShown())
 ui:EndCapture(); ui:SetBindingSource('draft'); ui:BeginActionCapture(ui.plan.byID and ui.plan.byID['system.MOVEFORWARD'] or ui.plan.actions[1])
 assert(not ui.capture.clear:IsShown())
end

function Tests.controls_clear_rejects_external_changes_during_confirmation_and_before_apply()
 local k,c=controls(); k.UI:Open(); local ui=k.UI
 ui:PromptClearCurrent(ui.bindingPlan.byKey.W)
 SetBinding('W','OPENCHAT'); Mock:ResetWrites(); ui.confirm.acceptButton:Click()
 assert(not c:HasEdits() and GetBindingAction('W')=='OPENCHAT' and #Mock.writes==0)
 assert(ui.bindingPlan.byKey.W.command=='OPENCHAT')
 clear(k,'BUTTON2'); SetBinding('BUTTON2','MOVEFORWARD'); Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find('changed') and #Mock.writes==0 and c:HasEdits())
end

function Tests.controls_capture_allows_primary_mouse_only_for_current_controls()
 local k,c=controls(); k.UI:Open(); local ui=k.UI
 k.db.preferences.confirmReplacements=false
 ui:BeginActionCapture(ui.bindingPlan.byKey.W); ui:CaptureInput('BUTTON2')
 assert(c:Edits().keys.BUTTON2=='MOVEFORWARD' and c:Edits().keys.W==false)
 c:Discard(); ui.currentBindingPlan=nil; ui:Refresh()
 ui:BeginActionCapture(ui.bindingPlan.byKey.F); ui:CaptureInput('BUTTON1')
 assert(not c:HasEdits() and ui.capture:IsShown())
end

function Tests.controls_rebind_rejects_stale_primary_source_during_capture_and_confirmation()
 local k,c=controls(); k.UI:Open(); local ui=k.UI
 local selected=ui.bindingPlan.byKey.BUTTON2
 ui:BeginActionCapture(selected)
 SetBinding('BUTTON2','OPENCHAT'); Mock:ResetWrites()
 ui:CaptureInput('F9')
 assert(not c:HasEdits() and #Mock.writes==0 and GetBindingAction('BUTTON2')=='OPENCHAT')
 ui:EndCapture(); SetBinding('BUTTON2','TURNORACTION'); c:Invalidate(); ui.currentBindingPlan=nil; ui:Refresh()
 ui:BeginActionCapture(ui.bindingPlan.byKey.BUTTON2); ui:CaptureInput('F')
 assert(ui.confirm:IsShown())
 SetBinding('BUTTON2','OPENCHAT'); Mock:ResetWrites(); ui.confirm.acceptButton:Click()
 assert(not c:HasEdits() and #Mock.writes==0 and GetBindingAction('F')=='OPENCHAT' and GetBindingAction('BUTTON2')=='OPENCHAT')
end

function Tests.controls_rebind_rejects_stale_staged_command_and_external_source()
 local k,c=controls()
 assert(c:Rebind(c:EditingView().byKey.BUTTON2,'F9'))
 local selected=c:EditingView().byKey.F9
 assert(c:StageEntry({descriptor={kind='system',command='MOVEFORWARD'}},'F9'))
 local ok,why=c:Rebind(selected,'F10')
 assert(not ok and why:find('changed') and c:Edits().keys.F9=='MOVEFORWARD' and c:Edits().keys.F10==nil and #Mock.writes==0)
 selected=c:EditingView().byKey.F9
 SetBinding('F9','OPENCHAT'); Mock:ResetWrites()
 ok,why=c:Rebind(selected,'F10')
 assert(not ok and why:find('changed') and c:Edits().keys.F10==nil and #Mock.writes==0 and GetBindingAction('F9')=='OPENCHAT')
end

function Tests.controls_pending_identity_change_rejects_stale_clear_and_rebind()
 local k,c=controls()
 Mock.catalog[998]={id=998,name='Pending A',icon=998}; Mock.catalog[999]={id=999,name='Pending B',icon=999}
 assert(c:StageEntry({spellID=998,label='Pending A'},'F9'))
 local selected=c:EditingView().byKey.F9
 assert(c:StageEntry({spellID=999,label='Pending B'},'F9'))
 local ok,why=c:ClearKey(selected); assert(not ok and why:find('changed'))
 ok,why=c:Rebind(selected,'F10'); assert(not ok and why:find('changed'))
 assert(c:Edits().entries.F9.spellID==999 and c:Edits().keys.F10==nil and #Mock.writes==0)
 applyCurrent(k)
 selected=c:EditingView().byKey.F9
 assert(c:StageEntry({spellID=998,label='Pending A'},'F9'))
 Mock:ResetWrites()
 assert(not c:ClearKey(selected) and not c:Rebind(selected,'F10'))
 assert(c:Edits().entries.F9.spellID==998 and c:Edits().keys.F10==nil and #Mock.writes==0)
 clear(k,'F9'); assert(c:Edits().entries.F9==nil)
end

function Tests.controls_replacement_confirmation_rechecks_live_and_pending_destinations()
 local k,c=controls(); k.UI:Open(); local ui=k.UI
 ui:BeginActionCapture(ui.bindingPlan.byKey.W); ui:CaptureInput('BUTTON2')
 assert(ui.confirm:IsShown())
 SetBinding('BUTTON2','OPENCHAT'); Mock:ResetWrites(); ui.confirm.acceptButton:Click()
 assert(not c:HasEdits() and GetBindingAction('BUTTON2')=='OPENCHAT' and #Mock.writes==0)
 Mock.catalog[998]={id=998,name='Pending A',icon=998}; Mock.catalog[999]={id=999,name='Pending B',icon=999}
 assert(c:StageEntry({spellID=998,label='Pending A'},'F9'))
 ui.currentBindingPlan=nil; ui:Refresh()
 ui:BeginActionCapture(ui.bindingPlan.byKey.W); ui:CaptureInput('F9'); assert(ui.confirm:IsShown())
 assert(c:StageEntry({spellID=999,label='Pending B'},'F9'))
 ui.confirm.acceptButton:Click()
 assert(c:Edits().entries.F9.spellID==999 and c:Edits().keys.W==nil and #Mock.writes==0)
end
