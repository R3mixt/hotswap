local function targetingSetup()
 local k=TestAddon
 Mock.class='DRUID'; Mock.spells={}; Mock.catalog={}; Mock.forms={}; Mock.build='1.15.9'
 Mock:Learn(774,'Rejuvenation'); Mock:Learn(339,'Entangling Roots'); Mock:Learn(768,'Cat Form')
 Mock.bindings={MOUSEWHEELUP='SPELL Rejuvenation',MOUSEWHEELDOWN='ACTIONBUTTON1',['ALT-MOUSEWHEELDOWN']='ACTIONBUTTON1',F='OPENCHAT',BUTTON1='CAMERAORSELECTORMOVE',BUTTON2='TURNORACTION'}
 Mock.bindingInventory=nil; Mock.actions={[1]={'spell',339},[40]={'spell',768}}
 k:Init(); Mock:ResetWrites(); return k
end
local function contains(values,wanted)
 for _,value in ipairs(values) do if value==wanted then return true end end
 return false
end
local function applyCurrent(k)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
end
function Tests.current_targeting_direct_wheel_is_staged_and_preserves_other_controls()
 local k=targetingSetup(); local preset=k:Export(); local original=k.Copy(Mock.modified)
 local action=k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP
 assert(contains(k.CurrentBindings:TargetModes(action),'mouseover'))
 assert(k.CurrentBindings:SetTargetMode(action,'mouseover'))
 local staged=k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP
 assert(staged.targetMode=='mouseover' and staged.targeting=='help' and staged.kind=='spell')
 assert(staged.currentEntry.body:find('[mod:alt,@player][@mouseover,help,nodead][help,nodead][@player]',1,true))
 assert(#Mock.writes==0 and k:Export()==preset and GetBindingAction('MOUSEWHEELUP')=='SPELL Rejuvenation')
 applyCurrent(k)
 local command=GetBindingAction('MOUSEWHEELUP'); assert(command:match('^MACRO KBO_'))
 local _,_,body=GetMacroInfo(GetMacroIndexByName(command:sub(7)))
 assert(body:find('/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] Rejuvenation',1,true))
 assert(GetBindingAction('MOUSEWHEELDOWN')=='ACTIONBUTTON1' and GetBindingAction('F')=='OPENCHAT')
 assert(Mock.actions[40][2]==768 and not k.db.enabled and k:Export()==preset)
 for name,value in pairs(original) do assert(Mock.modified[name]==value) end
 assert(#k.Engine:ListBackups()==1 and k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP.targetMode=='mouseover')
end
function Tests.current_targeting_native_slot_aliases_reopen_and_default_restores_raw_spell()
 local k=targetingSetup()
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN,'mouseover'))
 local view=k.CurrentBindings:EditingView()
 assert(view.byKey.MOUSEWHEELDOWN.targetMode=='mouseover' and view.byKey['ALT-MOUSEWHEELDOWN'].targetMode=='mouseover')
 applyCurrent(k)
 assert(Mock.actions[1][1]=='macro' and GetBindingAction('MOUSEWHEELDOWN')=='ACTIONBUTTON1')
 local _,_,body=GetMacroInfo(Mock.actions[1][2]); assert(body:find('[@mouseover,harm,nodead][harm,nodead]',1,true))
 k:Init(); local action=k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN
 assert(action.kind=='spell' and action.targetMode=='mouseover')
 assert(k.CurrentBindings:SetTargetMode(action,'default')); applyCurrent(k)
 assert(Mock.actions[1][1]=='spell' and Mock.actions[1][2]==339)
 assert(GetBindingAction('MOUSEWHEELDOWN')=='ACTIONBUTTON1' and GetBindingAction('ALT-MOUSEWHEELDOWN')=='ACTIONBUTTON1')
 assert(not k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN.targetMode)
end
function Tests.current_targeting_rejects_personal_macros_forms_and_unknown_spell_types()
 local k=targetingSetup(); Mock:Learn(999,'Mystery'); Mock.bindings.F='MACRO UserMacro'
 GetMacroSpell=function() return 774 end
 Mock.bindings.G='SPELL Cat Form'; Mock.bindings.H='SPELL Mystery'; k.CurrentBindings:Invalidate()
 local view=k.CurrentBindings:EditingView()
 for _,key in ipairs({'F','G','H'}) do
  assert(#k.CurrentBindings:TargetModes(view.byKey[key])==1)
  assert(not k.CurrentBindings:SetTargetMode(view.byKey[key],'mouseover'))
 end
 assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.current_targeting_edited_owned_macro_is_not_rewritten()
 local k=targetingSetup()
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP,'mouseover')); applyCurrent(k)
 local name=GetBindingAction('MOUSEWHEELUP'):sub(7); EditMacro(GetMacroIndexByName(name),name,1,'/say personal')
 k.CurrentBindings:Invalidate(); Mock:ResetWrites()
 local action=k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP
 assert(action.kind=='macroref' and not action.currentEntry)
 assert(not k.CurrentBindings:SetTargetMode(action,'target') and #Mock.writes==0)
end
function Tests.current_targeting_future_spell_waits_without_macro_then_keeps_target_mode()
 local k=targetingSetup(); Mock.catalog[5185]={id=5185,name='Healing Touch',icon=5185}
 assert(k.CurrentBindings:StageEntry({spellID=5185,label='Healing Touch'},'MOUSEWHEELDOWN'))
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN,'mouseover'))
 local account,character=GetNumMacros(); applyCurrent(k)
 assert(not Mock.actions[1] and k.db.currentLayout.slots[1].pending)
 local a,c=GetNumMacros(); assert(a==account and c==character)
 Mock.combat=true; Mock:Learn(5185,'Healing Touch'); Mock:Fire('SPELLS_CHANGED'); Mock:Advance(0.1)
 assert(not Mock.actions[1] and not k.Engine.busy)
 Mock.combat=false; Mock:Fire('PLAYER_REGEN_ENABLED'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(Mock.actions[1][1]=='macro')
 local _,_,body=GetMacroInfo(Mock.actions[1][2]); assert(body:find('[@mouseover,help,nodead]',1,true))
 assert(k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN.targetMode=='mouseover')
end
function Tests.current_targeting_full_macro_bank_reserves_then_recovers()
 local k=targetingSetup(); local _,count=GetNumMacros()
 for i=count+1,MAX_CHARACTER_MACROS do CreateMacro('Personal'..i,1,'/say '..i,true) end
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP,'mouseover')); applyCurrent(k)
 assert(GetBindingAction('MOUSEWHEELUP')=='' and k.db.currentLayout.keys.MOUSEWHEELUP.pending)
 assert(k.db.currentLayout.keys.MOUSEWHEELUP.targetMode=='mouseover')
 DeleteMacro(GetMacroIndexByName('Personal1')); Mock:Fire('UPDATE_MACROS'); Mock:Advance(0.1); assert(Mock:Drain())
 assert(GetBindingAction('MOUSEWHEELUP'):match('^MACRO KBO_'))
 assert(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP.targetMode=='mouseover')
end
function Tests.current_targeting_focus_capability_changes_reject_before_backup()
 local k=targetingSetup(); Mock:SetBindingCommandAvailable('TARGETFOCUS',true); Mock:SetBindingCommandAvailable('FOCUSTARGET',true); k.API:InvalidateBindingCommands()
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP,'focus'))
 Mock:SetBindingCommandAvailable('TARGETFOCUS',false); Mock:SetBindingCommandAvailable('FOCUSTARGET',false); k.API:InvalidateBindingCommands(); Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find('targeting') and #Mock.writes==0 and #k.Engine:ListBackups()==0)
 assert(k.CurrentBindings:HasEdits())
end
function Tests.current_targeting_preserves_exact_rank()
 local k=targetingSetup(); Mock.spells[1].rank='Rank 1'; Mock:Learn(1430,'Rejuvenation','Rank 2')
 Mock.actions[1]={'spell',774}; k.API:InvalidateSpellbook(); k.CurrentBindings:Invalidate()
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN,'mouseover')); applyCurrent(k)
 local _,_,body=GetMacroInfo(Mock.actions[1][2]); assert(body:find('Rejuvenation(Rank 1)',1,true))
end
function Tests.current_targeting_current_target_self_and_resurrection_keep_validity_rules()
 local k=targetingSetup()
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP,'target'))
 assert(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP.currentEntry.body:find('[mod:alt,@player][help,nodead]',1,true))
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP,'self'))
 assert(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP.currentEntry.body:find('[@player] Rejuvenation',1,true))
 Mock:Learn(20484,'Rebirth'); k.API:InvalidateSpellbook()
 assert(k.CurrentBindings:StageEntry({spellID=20484,label='Rebirth'},'MOUSEWHEELDOWN'))
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN,'mouseover'))
 local body=k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN.currentEntry.body
 assert(body:find('[@mouseover,help,dead][help,dead]',1,true) and not body:find('@player',1,true))
 assert(not contains(k.CurrentBindings:TargetModes(k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN),'self'))
end
function Tests.current_targeting_no_self_spell_never_gains_alt_self_or_self_mode()
 local k=targetingSetup(); Mock.class='PRIEST'; Mock.build='1.60.1'; Mock.spells={}; Mock:Learn(999,'Divine Grace')
 Mock.bindings.MOUSEWHEELUP='SPELL Divine Grace'; k:Init(); k.API:InvalidateSpellbook(); k.CurrentBindings:Invalidate()
 local action=k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP
 assert(not contains(k.CurrentBindings:TargetModes(action),'self'))
 assert(k.CurrentBindings:SetTargetMode(action,'mouseover'))
 local body=k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP.currentEntry.body
 assert(body:find('[nomod:alt,@mouseover,help,nodead][nomod:alt,help,nodead]',1,true) and not body:find('@player',1,true))
end
function Tests.current_targeting_verified_item_uses_existing_target_rules()
 local k=targetingSetup(); Mock.itemInfo[1251]={name='Linen Bandage',effect='Heal'}; Mock.bagItems[0]={{id=1251,count=2}}
 Mock.bindings.MOUSEWHEELUP='ITEM item:1251'; k.Items:Scan(); k.CurrentBindings:Invalidate()
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELUP,'mouseover')); applyCurrent(k)
 local name=GetBindingAction('MOUSEWHEELUP'):sub(7); local _,_,body=GetMacroInfo(GetMacroIndexByName(name))
 assert(body:find('/use [mod:alt,@player][@mouseover,help,nodead][help,nodead] item:1251',1,true))
end
function Tests.current_targeting_failure_restores_native_slot_and_keeps_draft()
 local k=targetingSetup()
 assert(k.CurrentBindings:SetTargetMode(k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN,'mouseover'))
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:EditingView().byKey.F,'F9'))
 local original=SetBinding; SetBinding=function(key,command,...) if key=='F9' and command then return false end return original(key,command,...) end
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(not Mock:Drain())
 assert(Mock.actions[1][1]=='spell' and Mock.actions[1][2]==339 and GetBindingAction('F')=='OPENCHAT')
 assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:EditingView().byKey.MOUSEWHEELDOWN.targetMode=='mouseover')
end
function Tests.current_targeting_saved_mouseover_refresh_adds_final_self_fallback()
 local k=targetingSetup()
 local body='#showtooltip Rejuvenation\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] Rejuvenation'
 local name=k.Macros:Name(body); CreateMacro(name,1,body,true); k.db.ownedMacros[name]=body
 Mock.bindings.MOUSEWHEELUP='MACRO '..name
 k.db.currentLayout={keys={MOUSEWHEELUP={spellID=774,name='Rejuvenation',label='Rejuvenation',targetMode='mouseover',targeting='help',
  body=body,macroName=name,command='MACRO '..name,content={kind='macro',name=name,body=body}}},slots={}}
 k.CurrentBindings:Invalidate(); k.CurrentBindings:QueueRefresh(); Mock:Advance(0.1); assert(Mock:Drain())
 local updated=GetBindingAction('MOUSEWHEELUP'):match('^MACRO (.+)$'); assert(updated and updated~=name)
 local _,_,replacement=GetMacroInfo(GetMacroIndexByName(updated))
 assert(replacement:find('[mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] Rejuvenation',1,true))
 assert(GetBindingAction('MOUSEWHEELDOWN')=='ACTIONBUTTON1' and GetBindingAction('F')=='OPENCHAT')
end
function Tests.current_targeting_fallback_refresh_preserves_manually_changed_macro()
 local k=targetingSetup()
 local body='#showtooltip Rejuvenation\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] Rejuvenation'
 local name=k.Macros:Name(body); CreateMacro(name,1,body,true); k.db.ownedMacros[name]=body
 Mock.bindings.MOUSEWHEELUP='MACRO '..name
 k.db.currentLayout={keys={MOUSEWHEELUP={spellID=774,name='Rejuvenation',label='Rejuvenation',targetMode='mouseover',
  body=body,macroName=name,command='MACRO '..name,content={kind='macro',name=name,body=body}}},slots={}}
 EditMacro(GetMacroIndexByName(name),name,1,'/say keep my changes'); Mock:ResetWrites()
 k.CurrentBindings:Invalidate(); k.CurrentBindings:QueueRefresh(); Mock:Advance(0.1)
 assert(not k.Engine.busy and #Mock.writes==0 and k.db.currentLayout.keys.MOUSEWHEELUP.detached)
 local _,_,personal=GetMacroInfo(GetMacroIndexByName(name))
 assert(personal=='/say keep my changes' and GetBindingAction('MOUSEWHEELUP')=='MACRO '..name)
end
