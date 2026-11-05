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
 assert(GetBindingAction('F9')=='' and GetBindingAction('G')=='TARGETSELF')
 assert(k.CurrentBindings:EditingView().byKey.F9.spellID==999 and k.db.currentLayout.keys.F9.pending)
end
function Tests.character_login_replaces_foreign_selected_draft_without_deleting_it()
 local k=currentMage(); local foreign={id='p99',sourceClass='WARLOCK',settings=k.Copy(k.defaults),items={},equipment={}}
 k.db.presets={Warlock=foreign}; k.db.activePreset='Warlock'; k.db.schema=2
 k:Init(); assert(k.db.activePreset~='Warlock' and k.db.presets.Warlock==foreign)
 assert(#k.Presets:List()==1 and k.db.presets[k.db.activePreset].sourceClass=='MAGE')
 assert(not k.Presets:Select('Warlock')); assert(#Mock.writes==0)
 Mock:AllowFullCatalogMacros()
 local ok,why=k.Presets:Activate(k.db.activePreset); assert(ok,why)
 assert(k.db.appliedPlan.class=='MAGE')
end
function Tests.character_login_disables_foreign_installed_plan_without_writes()
 local k=currentMage(); k.db.enabled=true; k.db.appliedPlan={class='WARLOCK',actions={}}
 Mock:ResetWrites(); Mock:Fire('PLAYER_LOGIN'); Mock:Advance(0.2)
 assert(not k.db.enabled and k.db.appliedPlan.class=='WARLOCK' and not k.Engine.busy)
 for _,write in ipairs(Mock.writes) do assert(write[1]~='binding' and write[1]~='action') end
end
function Tests.current_edit_future_native_slot_uses_no_macro_and_activates_after_learning()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 local account,character=GetNumMacros()
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'F9'))
 k.CurrentBindings.edits=nil; k:Init()
 assert(k.CurrentBindings:EditingView().byKey['1'].known==false and #Mock.writes==0)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(not Mock.actions[1] and Mock.actions[2][2]==133 and GetBindingAction('F9')=='')
 local a,c=GetNumMacros(); assert(a==account and c==character)
 k:Init(); assert(k.CurrentBindings:EditingView().byKey['1'].spellID==999)
 Mock.combat=true; Mock:Learn(999,'Future'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1)
 assert(not k.Engine.busy and not Mock.actions[1])
 Mock.combat=false; Mock:Fire('PLAYER_REGEN_ENABLED'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(Mock.actions[1][1]=='spell' and Mock.actions[1][2]==999 and GetBindingAction('F9')=='SPELL Future')
 assert(k.CurrentBindings:EditingView().byKey['1'].known)
end

function Tests.current_edit_missing_item_reserves_without_macro_then_uses_native_item()
 local k=currentMage(); local entry={label='Future potion',descriptor={kind='item',itemID=1710}}
 local account,character=GetNumMacros()
 assert(k.CurrentBindings:StageEntry(entry,'2')); assert(k.CurrentBindings:StageEntry(entry,'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(not Mock.actions[2] and GetBindingAction('F9')=='' and k.CurrentBindings:EditingView().byKey['2'].itemID==1710)
 Mock.itemInfo[1710]={name='Potion',effect='Heal'}; Mock.bagItems[0]={{id=1710,count=2}}
 Mock:Fire('BAG_UPDATE_DELAYED'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(Mock.actions[2][1]=='item' and Mock.actions[2][2]==1710 and GetBindingAction('F9')=='ITEM item:1710')
 local a,c=GetNumMacros(); assert(a==account and c==character)
end

function Tests.current_edit_exact_future_rank_waits_for_that_rank_without_macro()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',rank='Rank 2',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,rank='Rank 2',label='Future Rank 2'},'1'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 Mock:Learn(998,'Future','Rank 1'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1)
 assert(not Mock.actions[1] and not k.Engine.busy)
 Mock:Learn(999,'Future','Rank 2'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(Mock.actions[1][2]==999)
end

function Tests.current_edit_future_write_failure_rolls_back_macro_and_retains_persistent_draft()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 assert(k.CurrentBindings:StageEntry({spellID=133,label='Fireball'},'F9'))
 local set=SetBinding; SetBinding=function(key,command,...) if key=='F9' and command then return false end return set(key,command,...) end
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(not Mock:Drain())
 assert(Mock.actions[1][2]==133 and GetMacroIndexByName(k.Macros:Name('#showtooltip Future\n/cast Future'))==0)
 k:Init(); assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:EditingView().byKey.F9.spellID==133)
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
 local body='#showtooltip Future\n/cast Future'; local name=k.Macros:Name(body)
 local index=CreateMacro(name,1,body,true); k.db.ownedMacros[name]=body
 Mock.actions[1]={'macro',index}; Mock.bindings.F9='MACRO '..name; Mock.bindingInventory=nil
 local entry={spellID=999,name='Future',label='Future',body=body,macroName=name,nativeMacro=true,command='MACRO '..name,content={kind='macro',name=name,body=body}}
 k.db.currentLayout={keys={F9=k.Copy(entry)},slots={[1]=k.Copy(entry)}}
 k.CurrentBindings:Invalidate()
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
function Tests.current_edit_full_macro_banks_do_not_block_future_reservations()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 local _,count=GetNumMacros(); for i=count+1,MAX_CHARACTER_MACROS do CreateMacro('Personal'..i,1,'/say '..i,true) end
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1')); Mock:ResetWrites()
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(not Mock.actions[1] and k.db.currentLayout.slots[1].pending)
 for _,write in ipairs(Mock.writes) do assert(write[1]~='createmacro' and write[1]~='deletemacro') end
end

function Tests.current_edit_reserved_rebind_preserves_same_key_and_moves_without_macros()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 local action=k.CurrentBindings:EditingView().byKey.F9
 assert(k.CurrentBindings:Rebind(action,'F9') and not k.CurrentBindings:HasEdits())
 assert(k.CurrentBindings:Rebind(action,'F8'))
 local view=k.CurrentBindings:EditingView(); assert(not view.byKey.F9 and view.byKey.F8.spellID==999)
 Mock:ResetWrites()
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 assert(not k.db.currentLayout.keys.F9 and k.db.currentLayout.keys.F8.pending)
 for _,write in ipairs(Mock.writes) do assert(write[1]~='createmacro') end
 Mock:Learn(999,'Future'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(GetBindingAction('F9')=='' and GetBindingAction('F8')=='SPELL Future')
end

function Tests.current_edit_temporary_slot_outside_backup_is_not_mutated()
 local k=currentMage(); Mock.bindings.F='EXTRAACTIONBUTTON1'
 ExtraActionButton1={action=201,GetAttribute=function(_,name) if name=="type" then return "action" elseif name=="action" then return 201 end end}
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
function Tests.current_edit_legacy_fourteen_reservations_with_nine_free_slots_apply_without_macros()
 local k=currentMage()
 local _,count=GetNumMacros(); for i=count+1,MAX_CHARACTER_MACROS-9 do CreateMacro('Personal'..i,1,'/say '..i,true) end
 local draft={keys={},entries={},slots={},expectedKeys={},expectedSlots={}}
 for i=1,14 do
  local id=9000+i; local name='Future '..i; Mock.catalog[id]={id=id,name=name,icon=id}
  local body='#showtooltip '..name..'\n/cast '..name; local key='CTRL-F'..i
  draft.keys[key]='MACRO '..k.Macros:Name(body); draft.expectedKeys[key]=''
  draft.entries[key]={spellID=id,name=name,label=name,body=body,futureBody=body,command=draft.keys[key]}
 end
 k.db.currentEditDraft=draft; k:Init(); Mock:ResetWrites()
 local beforeAccount,beforeCharacter=GetNumMacros()
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 local account,character=GetNumMacros(); assert(account==beforeAccount and character==beforeCharacter)
 for i=1,14 do local key='CTRL-F'..i; assert(GetBindingAction(key)=='' and k.CurrentBindings:EditingView().byKey[key].spellID==9000+i) end
 assert(GetBindingAction('G')=='TARGETSELF' and not k.CurrentBindings:HasEdits())
end
function Tests.current_edit_migration_cleans_only_unreferenced_owned_macros()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 local body='#showtooltip Future\n/cast Future'; local name=k.Macros:Name(body)
 local index=CreateMacro(name,1,body,true); k.db.ownedMacros[name]=body
 Mock.actions[1]={'macro',index}; Mock.bindings.F9='MACRO '..name; Mock.bindingInventory=nil
 Mock.bindingSet=2; Mock.bindingSets[2]=k.Copy(Mock.bindings)
 local entry={spellID=999,name='Future',label='Future',body=body,macroName=name,command='MACRO '..name,content={kind='macro',name=name,body=body}}
 k.db.currentLayout={keys={F9=k.Copy(entry)},slots={[1]=k.Copy(entry)}}
 local personal=CreateMacro('Personal',1,'/say keep',true)
 k.CurrentBindings:QueueRefresh(); Mock:Advance(0.1); assert(Mock:Drain()); Mock:Advance(0.1)
 assert(not Mock.actions[1] and GetBindingAction('F9')=='' and GetMacroIndexByName(name)==0)
 assert(GetMacroIndexByName('Personal')>0)
end
function Tests.current_edit_refresh_preserves_personal_slot_and_key_changes_permanently()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 Mock.actions[1]={'spell',116}; Mock.bindings.F9='OPENCHAT'
 Mock:Learn(999,'Future'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1)
 assert(not k.Engine.busy and Mock.actions[1][2]==116 and GetBindingAction('F9')=='OPENCHAT')
 Mock.actions[1]=nil; Mock.bindings.F9=nil; Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1)
 assert(not k.Engine.busy and not Mock.actions[1] and GetBindingAction('F9')=='')
end
function Tests.current_edit_refresh_does_not_apply_or_discard_pending_user_draft()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 assert(k.CurrentBindings:StageEntry({spellID=999,label='Future'},'1'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(Mock:Drain())
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:EditingView().byKey.F,'F8'))
 Mock:Learn(999,'Future'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(Mock.actions[1][2]==999 and GetBindingAction('F')=='OPENCHAT' and GetBindingAction('F8')=='')
 assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:EditingView().byKey.F8.command=='OPENCHAT')
end
function Tests.current_edit_macro_only_action_waits_for_character_space_without_account_overflow()
 local k=currentMage(); local _,count=GetNumMacros()
 for i=count+1,MAX_CHARACTER_MACROS do CreateMacro('Personal'..i,1,'/say '..i,true) end
 local account,character=GetNumMacros()
 assert(k.CurrentBindings:StageEntry({label='Wave',descriptor={kind='emote',emote='WAVE'}},'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(GetBindingAction('F9')=='' and k.db.currentLayout.keys.F9.pending)
 local a,c=GetNumMacros(); assert(a==account and c==character)
 DeleteMacro(GetMacroIndexByName('Personal'..MAX_CHARACTER_MACROS)); Mock:Fire('UPDATE_MACROS'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(GetBindingAction('F9'):match('^MACRO KBO_'))
 a,c=GetNumMacros(); assert(a==account and c==character)
end
