local function currentMage()
 local k=TestAddon; Mock.class='MAGE'; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 UnitClass=function() return 'Mage','MAGE',8 end
 Mock:Learn(133,'Fireball'); Mock:Learn(116,'Frostbolt')
 Mock.bindings={['1']='ACTIONBUTTON1',['2']='ACTIONBUTTON2',F='OPENCHAT',G='TARGETSELF',BUTTON1='CAMERAORSELECTORMOVE',BUTTON2='TURNORACTION'}
 Mock.bindingInventory=nil; Mock.actions={[1]={'spell',133},[2]={'spell',133},[40]={'spell',133}}
 k:Init(); Mock:ResetWrites(); return k
end
function Tests.current_edit_sparse_rebind_preserves_preset_and_unrelated_controls()
 local k=currentMage(); local saved=k:Export(); local account=k.Copy(Mock.bindingSets[1])
 k.UI:Open(); assert(k.UI.library:IsShown())
 assert(k.UI:AssignBinding(k.UI.bindingPlan.byKey.F,'F9'))
 assert(#Mock.writes==0 and k:Export()==saved and k.UI.apply:IsEnabled())
 assert(k.UI.bindingPlan.byKey.F9.command=='OPENCHAT' and not k.UI.bindingPlan.byKey.F)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(Mock.bindings.F9=='OPENCHAT' and not Mock.bindings.F and Mock.bindings.G=='TARGETSELF')
 assert(Mock.actions[40][2]==133 and k:Export()==saved and not k.db.enabled)
 for key,value in pairs(account) do assert(Mock.bindingSets[1][key]==value) end
 assert(not k.CurrentBindings:HasEdits() and #k.Engine:ListBackups()==1)
end
function Tests.current_edit_live_slot_and_aliases_preview_then_apply()
 local k=currentMage(); Mock.bindings['ALT-1']='ACTIONBUTTON1'
 assert(k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'1'))
 local view=k.CurrentBindings:EditingView()
 assert(view.byKey['1'].spellID==116 and view.byKey['ALT-1'].spellID==116)
 assert(Mock.actions[1][2]==133 and #Mock.writes==0)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(Mock.actions[1][2]==116 and Mock.actions[2][2]==133 and Mock.bindings['1']=='ACTIONBUTTON1')
end
function Tests.current_edit_external_change_rejected_before_backup()
 local k=currentMage(); assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey.F,'F9'))
 Mock.bindings.F='TARGETSELF'; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits(); assert(ok==false and why:find('changed'))
 assert(#Mock.writes==0 and #k.Engine:ListBackups()==0 and k.CurrentBindings:HasEdits())
end
function Tests.current_edit_write_failure_restores_controls_and_retains_draft()
 local k=currentMage(); assert(k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'1'))
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey.F,'F9'))
 local set=SetBinding; SetBinding=function(key,command,...) if key=='F9' and command then return false end return set(key,command,...) end
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok=Mock:Drain(); assert(not ok)
 assert(Mock.actions[1][2]==133 and Mock.bindings.F=='OPENCHAT' and not Mock.bindings.F9)
 assert(k.CurrentBindings:HasEdits())
end
function Tests.current_edit_rebind_then_place_uses_staged_destination()
 local k=currentMage(); assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey['1'],'F9'))
 assert(k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(Mock.actions[1][2]==116 and Mock.bindings.F9=='ACTIONBUTTON1' and not Mock.bindings['1'])
end
function Tests.current_edit_future_spell_is_reserved_without_prefilling()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 local ok,why=k.CurrentBindings:StageEntry({spellID=999,label='Future'},'F9')
 assert(ok,why); assert(k.CurrentBindings:HasEdits() and #Mock.writes==0)
 assert(k.CurrentBindings:EditingView().byKey.F9.spellID==999)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 assert(GetBindingAction('F9'):find('MACRO KBO_',1,true) and GetBindingAction('G')=='TARGETSELF')
end
function Tests.character_login_replaces_foreign_selected_draft_without_deleting_it()
 local k=currentMage(); local foreign={id='p99',sourceClass='WARLOCK',settings=k.Copy(k.defaults),items={},equipment={}}
 k.db.presets={Warlock=foreign}; k.db.activePreset='Warlock'; k.db.schema=2
 k:Init(); assert(k.db.activePreset~='Warlock' and k.db.presets.Warlock==foreign)
 assert(#k.Presets:List()==1 and k.db.presets[k.db.activePreset].sourceClass=='MAGE')
 assert(not k.Presets:Select('Warlock')); assert(#Mock.writes==0)
 k:GetSettings().allowAccountMacros=true
 local ok,why=k.Presets:Activate(k.db.activePreset); assert(ok,why)
 assert(k.db.appliedPlan.class=='MAGE')
end
function Tests.character_login_disables_foreign_installed_plan_without_writes()
 local k=currentMage(); k.db.enabled=true; k.db.appliedPlan={class='WARLOCK',actions={}}
 Mock:ResetWrites(); Mock:Fire('PLAYER_LOGIN'); Mock:Advance(0.2)
 assert(not k.db.enabled and k.db.appliedPlan.class=='WARLOCK' and not k.Engine.busy)
 for _,write in ipairs(Mock.writes) do assert(write[1]~='binding' and write[1]~='action') end
end
function Tests.current_edit_future_native_slot_reserves_macro_and_survives_learning_reload()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 k.CurrentBindings.edits=nil; k:Init()
 assert(k.CurrentBindings:EditingView().byKey['1'].known==false and #Mock.writes==0)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(Mock.actions[1][1]=='macro' and Mock.actions[2][2]==133)
 local _,_,body=GetMacroInfo(Mock.actions[1][2]); assert(body=='#showtooltip Future\n/cast Future')
 k:Init(); local a=k.CurrentBindings:EditingView().byKey['1']; assert(a.spellID==999 and not a.known)
 Mock:Learn(999,'Future'); k.API:InvalidateSpellbook(); k.CurrentBindings:Invalidate()
 a=k.CurrentBindings:EditingView().byKey['1']; assert(a.known and a.label=='Future')
end
function Tests.current_edit_unavailable_item_native_and_direct_work_without_inventory()
 local k=currentMage(); local entry={label='Future potion',descriptor={kind='item',itemID=1710}}
 assert(k.CurrentBindings:StageEntry(entry,'2')); assert(k.CurrentBindings:StageEntry(entry,'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 local _,_,body=GetMacroInfo(Mock.actions[2][2]); assert(body=='#showtooltip item:1710\n/use item:1710')
 assert(GetBindingAction('F9'):find('MACRO KBO_',1,true) and k.CurrentBindings:EditingView().byKey['2'].itemID==1710)
end
function Tests.current_edit_exact_future_rank_and_macro_collision_are_preserved()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',rank='Rank 2',icon=999}
 local body='#showtooltip Future(Rank 2)\n/cast Future(Rank 2)'
 local name=k.Macros:Name(body); CreateMacro(name,1,'/say personal',true)
 assert(k.CurrentBindings:StageEntry({spellID=999,rank='Rank 2',label='Future Rank 2'},'1'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 local actual,_,written=GetMacroInfo(Mock.actions[1][2]); assert(written==body and actual~=name)
 assert(k.CurrentBindings:EditingView().byKey['1'].spellID==999)
end
function Tests.current_edit_future_write_failure_rolls_back_macro_and_retains_persistent_draft()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'F9'))
 local set=SetBinding; SetBinding=function(key,command,...) if key=='F9' and command then return false end return set(key,command,...) end
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(not Mock:Drain())
 assert(Mock.actions[1][2]==133 and GetMacroIndexByName(k.Macros:Name('#showtooltip Future\n/cast Future'))==0)
 k:Init(); assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:EditingView().byKey.F9.spellID==999)
end
function Tests.current_edit_external_native_change_is_not_mislabeled_as_saved_spell()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 Mock.actions[1]={'spell',116}; k.CurrentBindings:Invalidate()
 assert(k.CurrentBindings:EditingView().byKey['1'].spellID==116)
end
function Tests.current_edit_discard_and_clear_key_never_touch_other_bindings()
 local k=currentMage(); assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey.F,'F9'))
 k.CurrentBindings:Discard(); k:Init(); assert(not k.CurrentBindings:HasEdits())
 assert(k.CurrentBindings:ClearKey(k.CurrentBindings:Get().byKey.F))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 assert(GetBindingAction('F')=='' and GetBindingAction('G')=='TARGETSELF')
end
function Tests.current_edit_hover_catalog_includes_unlearned_and_uses_only_chosen_key()
 local k=currentMage()
 for _,a in ipairs(k.Profiles:Get('MAGE','era')) do for _,id in ipairs(a.spellIDs or {}) do Mock.catalog[id]={id=id,name=a.name,icon=id} end end
 k:GetSettings().flavor='era'; k.db.preferences.showUnavailableBindings=false
 k.UI:Open(); k.UI:OpenHoverBindings(); local f=k.UI.hoverBindings
 local chosen; for _,row in pairs(f.rows) do if row.action.known==false and row.action.spellID then chosen=row; break end end
 assert(chosen and f.active)
 local exported=k:Export(); k.UI:HoverBindingEnter(chosen); k.UI:HoverBindingInput('F9')
 assert(k.CurrentBindings:HasEdits() and f.active and #Mock.writes==0 and k:Export()==exported)
 assert(k.UI.bindingPlan.byKey.F9.spellID==chosen.action.spellID)
 assert(k.UI.bindingPlan.byKey.F.command=='OPENCHAT' and not k.UI.bindingPlan.byKey.F8)
end
function Tests.current_edit_catalog_does_not_inherit_preset_replacements()
 local k=currentMage()
 for _,a in ipairs(k.Profiles:Get('MAGE','era')) do for _,id in ipairs(a.spellIDs or {}) do Mock.catalog[id]={id=id,name=a.name,icon=id} end end
 k:GetSettings().flavor='era'; k:GetSettings().actionOverrides['mage.fireball']={replacement={kind='item',itemID=1710}}
 k.Presets:Changed()
 local entries=k.Library:List({tab='spells',current=true}); local found=false
 for _,e in ipairs(entries) do if e.name=='Fireball' then found=true end end
 assert(found and #Mock.writes==0)
end
function Tests.current_edit_add_missing_item_via_spellbook_keeps_current_mode()
 local k=currentMage(); k.UI:Open(); k.UI.library.tabs.items:Click(); k.UI.library.addItem:Click()
 k.UI.nameDialog.input:SetText('1710'); k.UI.nameDialog.save:Click(); Mock:Advance(0.05)
 assert(k.UI.bindingSource=='current' and k.db.currentItems[1710])
 local found; for _,entry in ipairs(k.Library:List({tab='items',current=true})) do if entry.itemID==1710 then found=entry end end
 assert(found and #Mock.writes==0)
end
function Tests.current_edit_named_restore_recreates_future_macros_without_touching_personal_collision()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 local name=GetBindingAction('F9'):match('^MACRO (.+)$')
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:EditingView().byKey.G,'F8'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 local backup=k.Engine:ListBackups()[1].id
 EditMacro(GetMacroIndexByName(name),name,1,'/say personal')
 local ok,why=k.Engine:RestoreBackup(backup); assert(ok,why)
 local restored=GetBindingAction('F9'):match('^MACRO (.+)$'); assert(restored and restored~=name)
 local _,_,personal=GetMacroInfo(GetMacroIndexByName(name)); assert(personal=='/say personal')
 local view=k.CurrentBindings:EditingView(); assert(view.byKey['1'].spellID==999 and view.byKey.F9.spellID==999)
 assert(GetBindingAction('G')=='TARGETSELF' and GetBindingAction('F8')=='')
end
function Tests.current_edit_macro_budget_failure_makes_no_game_changes()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 local _,max=GetNumMacros(); for i=max+1,MAX_CHARACTER_MACROS do CreateMacro('Personal'..i,1,'/say '..i,true) end
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1')); Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits(); assert(not ok and why:find('macro'))
 assert(#Mock.writes==0 and k.CurrentBindings:HasEdits())
end
function Tests.current_edit_temporary_slot_outside_backup_is_not_mutated()
 local k=currentMage(); Mock.bindings.F='EXTRAACTIONBUTTON1'
 ExtraActionButton1={action=201,GetAttribute=function() return 201 end}
 k.CurrentBindings:Invalidate()
 local ok,why=k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'F')
 assert(not ok and why:find('temporary') and not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.current_edit_hover_rebind_occupied_key_is_immediate_but_normal_capture_confirms()
 local k=currentMage(); k.UI:Open(); k.UI:OpenHoverBindings(); local f=k.UI.hoverBindings
 local row; for _,candidate in pairs(f.rows) do if candidate.action.spellID==133 then row=candidate; break end end
 assert(row and row.action.currentBinding)
 k.UI:HoverBindingEnter(row); k.UI:HoverBindingInput('F')
 assert(not k.UI.confirm or not k.UI.confirm:IsShown())
 assert(f.active and f:IsShown() and k.UI.hoverInput:IsShown())
 assert(k.UI.bindingPlan.byKey.F.command=='ACTIONBUTTON1' and not k.UI.bindingPlan.byKey['1'])
 assert(GetBindingAction('F')=='OPENCHAT' and #Mock.writes==0)
 k.UI:CloseHoverBindings(); k.UI:AssignBinding(k.UI.bindingPlan.byKey.F,'G')
 assert(k.UI.confirm:IsShown() and GetBindingAction('G')=='TARGETSELF')
end
function Tests.current_edit_hover_new_ability_replaces_occupied_slot_without_confirmation()
 local k=currentMage()
 for _,a in ipairs(k.Profiles:Get('MAGE','era')) do for _,id in ipairs(a.spellIDs or {}) do Mock.catalog[id]={id=id,name=a.name,icon=id} end end
 k:GetSettings().flavor='era'; k.UI:Open(); k.UI:OpenHoverBindings(); local f=k.UI.hoverBindings
 local row; for _,candidate in pairs(f.rows) do if candidate.action.known==false and candidate.action.spellID and not candidate.action.currentBinding then row=candidate; break end end
 assert(row); local id=row.action.spellID
 k.UI:HoverBindingEnter(row); k.UI:HoverBindingInput('2')
 assert(not k.UI.confirm or not k.UI.confirm:IsShown())
 assert(f.active and f:IsShown() and k.UI.bindingPlan.byKey['2'].spellID==id)
 assert(Mock.actions[2][2]==133 and #Mock.writes==0)
 k.UI:HoverBindingInput('F9')
 assert(f.active and k.UI.bindingPlan.byKey.F9.spellID==id and not k.UI.bindingPlan.byKey['2'])
 assert(#Mock.writes==0)
end
