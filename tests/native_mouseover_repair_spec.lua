local function repairFixture(detached)
 local k=TestAddon; Mock.class='DRUID'; Mock.spells={}; Mock.catalog={}; Mock:Learn(774,'Rejuvenation')
 k:Init(); k.API:InvalidateSpellbook()
 local body='#showtooltip Rejuvenation\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] Rejuvenation'
 local name=k.Macros:Name(body); local index=CreateMacro(name,774,body,true); k.db.ownedMacros[name]=body
 local entry={spellID=774,name='Rejuvenation',label='Rejuvenation',targetMode='mouseover',detached=detached,
  body=body,macroName=name,command='MACRO '..name,content={kind='macro',name=name,body=body}}
 k.db.currentLayout={keys={F9=k.Copy(entry)},slots={[47]=k.Copy(entry)}}
 Mock.actions={[47]={'macro',index}}; Mock.bindings={MOUSEWHEELUP='MULTIACTIONBAR4BUTTON11',F9='MACRO '..name,G='OPENCHAT'}
 Mock.bindingInventory=nil; Mock.bindingSet=2; Mock.bindingSets[2]=k.Copy(Mock.bindings)
 Mock.cvars.enableMouseoverCast='0'; Mock.cvars.autoSelfCast='0'; Mock.modified.MOUSEOVERCAST='NONE'
 k.CurrentBindings:Invalidate(); Mock:ResetWrites()
 return k,name,body
end
function Tests.native_mouseover_repair_applies_exact_owned_slot_and_direct_key_even_when_native_already_enabled()
 local k,name,body=repairFixture(true)
 Mock.cvars.enableMouseoverCast='1'; Mock.cvars.autoSelfCast='1'
 local ok,message=k.CurrentBindings:SetNativeMouseover(true); assert(ok and message:find('2 older healing',1,true))
 assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:GetNativeMouseoverState().repairCount==2 and #Mock.writes==0)
 local view=k.CurrentBindings:EditingView()
 assert(view.byKey.F9.targetMode=='mouseover' and view.byKey.MOUSEWHEELUP.targetMode=='mouseover')
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local applied,why=Mock:Drain(); assert(applied,why)
 local current=k.NativeBars:ReadSlot(47)
 assert(current.body:find('[help,nodead][@player] Rejuvenation',1,true) and current.name~=name)
 assert(GetBindingAction('F9')=='MACRO '..current.name and GetBindingAction('MOUSEWHEELUP')=='MULTIACTIONBAR4BUTTON11')
 assert(not k.db.currentLayout.slots[47].detached and not k.db.currentLayout.keys.F9.detached)
end
function Tests.native_mouseover_repair_preserves_personally_edited_bodies_at_capture()
 local k,name=repairFixture(true)
 EditMacro(GetMacroIndexByName(name),name,774,'/say personal'); Mock:ResetWrites()
 assert(k.CurrentBindings:SetNativeMouseover(true))
 assert(k.CurrentBindings:GetNativeMouseoverState().repairCount==0 and #Mock.writes==0)
 local prepared=k.CurrentBindings:PrepareEdits(k.Copy(k.CurrentBindings:Edits()))
 assert(not next(prepared.slots) and not next(prepared.keys))
 assert(k.db.currentLayout.slots[47].detached and k.db.currentLayout.keys.F9.detached)
end
function Tests.native_mouseover_repair_rechecks_ownership_before_any_backup_or_write()
 local k,name=repairFixture(true); assert(k.CurrentBindings:SetNativeMouseover(true))
 k.db.ownedMacros[name]=nil; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find('repair changed',1,true) and #Mock.writes==0 and #k.Engine:ListBackups()==0)
 assert(k.CurrentBindings:HasEdits() and k.NativeBars:ReadSlot(47).name==name)
end
function Tests.native_mouseover_repair_full_macro_bank_never_clears_working_heals()
 local k,name=repairFixture(true); local _,count=GetNumMacros()
 for i=count+1,MAX_CHARACTER_MACROS do CreateMacro('Personal'..i,1,'/say '..i,true) end
 assert(k.CurrentBindings:SetNativeMouseover(true)); Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find('macro space',1,true) and #Mock.writes==0 and #k.Engine:ListBackups()==0)
 assert(k.NativeBars:ReadSlot(47).name==name and GetBindingAction('F9')=='MACRO '..name)
 assert(k.CurrentBindings:HasEdits() and not k.db.currentLayout.slots[47].pending)
end
function Tests.native_mouseover_repair_draft_blocks_automatic_refresh_until_apply()
 local k,name=repairFixture(false); assert(k.CurrentBindings:SetNativeMouseover(true))
 k.CurrentBindings:QueueRefresh(); Mock:Advance(0.1)
 assert(not k.Engine.busy and #Mock.writes==0,'Automatic maintenance applied an explicit checkbox repair before Apply')
 assert(k.NativeBars:ReadSlot(47).name==name and GetBindingAction('F9')=='MACRO '..name)
 assert(k.CurrentBindings:GetNativeMouseoverState().repairCount==2)
end
function Tests.native_mouseover_repair_failure_rolls_back_bodies_routes_and_detached_ownership()
 local k,name,body=repairFixture(true); assert(k.CurrentBindings:SetNativeMouseover(true))
 local set=C_CVar.SetCVar
 C_CVar.SetCVar=function(key,value) if key=='autoSelfCast' and tostring(value)=='1' then return false end return set(key,value) end
 assert(k.Engine:ApplyCurrentEdits()=='pending'); assert(not Mock:Drain())
 assert(k.NativeBars:ReadSlot(47).name==name and k.NativeBars:ReadSlot(47).body==body)
 assert(GetBindingAction('F9')=='MACRO '..name and GetBindingAction('MOUSEWHEELUP')=='MULTIACTIONBAR4BUTTON11')
 assert(k.db.currentLayout.slots[47].detached and k.db.currentLayout.keys.F9.detached and k.CurrentBindings:HasEdits())
 assert(Mock.cvars.enableMouseoverCast=='0' and not k.db.recoveryRequired)
end
function Tests.native_mouseover_repair_direct_key_rechecks_body_at_binding_write()
 local k,name=repairFixture(true); k.db.currentLayout.slots={}; Mock.actions={}
 assert(k.CurrentBindings:SetNativeMouseover(true))
 local replacement=k.CurrentBindings:EditingView().byKey.F9.command
 assert(k.Engine:ApplyCurrentEdits()=='pending')
 for i=1,1000 do
  if k.Engine.job and k.Engine.job.message=='Editing current keys' then break end
  Mock:Advance(0.016)
 end
 assert(k.Engine.job and k.Engine.job.message=='Editing current keys','Fixture did not reach deferred binding writes')
 EditMacro(GetMacroIndexByName(name),name,774,'/say edited during apply'); Mock:ResetWrites()
 assert(not Mock:Drain())
 for _,write in ipairs(Mock.writes) do
  assert(not (write[1]=='binding' and write[2]=='F9' and write[3]==replacement),'Changed macro lost its key before the last ownership check')
 end
 assert(GetBindingAction('F9')=='MACRO '..name and select(3,GetMacroInfo(GetMacroIndexByName(name)))=='/say edited during apply')
 assert(k.CurrentBindings:HasEdits())
end
