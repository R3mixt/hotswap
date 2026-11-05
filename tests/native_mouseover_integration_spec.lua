local function ready()
 local k=TestAddon
 IsMouseoverCastSupported=function() return true end
 k:Init()
 Mock.cvars.enableMouseoverCast="0"; Mock.cvars.autoSelfCast="0"; Mock.modified.MOUSEOVERCAST="SHIFT"
 Mock.bindings={MOUSEWHEELUP="ACTIONBUTTON1",F="MACRO UserMacro",G="OPENCHAT",BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION"}
 Mock.bindingSet=2; Mock.bindingSets[2]=k.Copy(Mock.bindings); Mock.bindingInventory=nil
 Mock.actions={[1]={"spell",774},[2]={"macro",GetMacroIndexByName("UserMacro")}}
 k.CurrentBindings:Invalidate(); Mock:ResetWrites()
 return k
end
local function sameMap(actual,expected)
 for key,value in pairs(expected) do assert(actual[key]==value,"Changed value at "..tostring(key)) end
 for key,value in pairs(actual) do assert(expected[key]==value,"Unexpected value at "..tostring(key)) end
end
local function apply(k)
 local status,why=k.Engine:ApplyCurrentEdits(); assert(status=="pending",why)
 local ok,message=Mock:Drain(); assert(ok,message)
end
function Tests.native_mouseover_integration_rejected_setting_restores_all_targeting_preferences()
 local k=ready(); assert(k.CurrentBindings:SetNativeMouseover(true))
 local originalBindings=k.Copy(Mock.bindings); local originalModified=k.Copy(Mock.modified); local originalCVars=k.Copy(Mock.cvars)
 local set=SetCVar; local rejected=false
 SetCVar=function(name,value)
  if name=="autoSelfCast" and tostring(value)=="1" and not rejected then rejected=true; return false end
  return set(name,value)
 end
 C_CVar.SetCVar=SetCVar
 assert(k.Engine:ApplyCurrentEdits()=="pending")
 local ok=Mock:Drain(); assert(not ok and rejected)
 sameMap(Mock.bindings,originalBindings); sameMap(Mock.modified,originalModified); sameMap(Mock.cvars,originalCVars)
 assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:GetNativeMouseoverState().enabled)
 assert(not k.db.recoveryRequired)
end
function Tests.native_mouseover_integration_external_preference_change_rejects_before_backup()
 local k=ready(); assert(k.CurrentBindings:SetNativeMouseover(true))
 Mock.modified.MOUSEOVERCAST="CTRL"; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and type(why)=="string" and #Mock.writes==0 and #k.Engine:ListBackups()==0)
 assert(Mock.modified.MOUSEOVERCAST=="CTRL" and Mock.cvars.enableMouseoverCast=="0")
 assert(k.CurrentBindings:HasEdits())
end
function Tests.native_mouseover_integration_unsupported_client_cvar_does_not_grant_capability()
 local k=ready(); IsMouseoverCastSupported=function() return false end
 local state=k.API:GetNativeMouseoverState()
 assert(not state.supported and state.reason and Mock.cvars.enableMouseoverCast~=nil)
 local ok,why=k.CurrentBindings:SetNativeMouseover(true)
 assert(not ok and type(why)=="string" and not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.native_mouseover_integration_setting_only_apply_preserves_controls_and_named_restore()
 local k=ready()
 local savedModifiers={}; local save=SaveBindings
 SaveBindings=function(bindingSet) save(bindingSet); savedModifiers[bindingSet]=k.Copy(Mock.modified) end
 local originalBindings=k.Copy(Mock.bindings); local originalModified=k.Copy(Mock.modified); local originalCVars=k.Copy(Mock.cvars)
 local name,icon,body=GetMacroInfo(GetMacroIndexByName("UserMacro")); local account,character=GetNumMacros()
 assert(k.CurrentBindings:SetNativeMouseover(true)); apply(k)
 sameMap(Mock.bindings,originalBindings)
 assert(Mock.actions[1][1]=="spell" and Mock.actions[1][2]==774 and Mock.actions[2][1]=="macro")
 local newName,newIcon,newBody=GetMacroInfo(GetMacroIndexByName("UserMacro")); local newAccount,newCharacter=GetNumMacros()
 assert(name==newName and icon==newIcon and body==newBody and account==newAccount and character==newCharacter)
 assert(Mock.cvars.enableMouseoverCast=="1" and Mock.modified.MOUSEOVERCAST=="NONE" and Mock.cvars.autoSelfCast=="1")
 assert(savedModifiers[2] and savedModifiers[2].MOUSEOVERCAST=="NONE","Applied mouseover modifier was not saved")
 assert(not k.CurrentBindings:HasEdits() and not k.db.enabled and not k.db.appliedPlan)
 local backups=k.Engine:ListBackups(); assert(#backups==1)
 local ok,why=k.Engine:RestoreBackup(backups[1].id); assert(ok,why)
 if ok=="pending" then local done,message=Mock:Drain(); assert(done,message) end
 sameMap(Mock.bindings,originalBindings); sameMap(Mock.modified,originalModified); sameMap(Mock.cvars,originalCVars)
 assert(savedModifiers[2] and savedModifiers[2].MOUSEOVERCAST=="SHIFT","Restored mouseover modifier was not saved")
end
local function savedModifierSets(k)
 local sets={[1]=k.Copy(Mock.modified),[2]=k.Copy(Mock.modified)}
 sets[1].MOUSEOVERCAST="ALT"; sets[2].MOUSEOVERCAST="NONE"
 local load,save=LoadBindings,SaveBindings
 LoadBindings=function(bindingSet) load(bindingSet); Mock.modified=k.Copy(sets[bindingSet]) end
 SaveBindings=function(bindingSet) save(bindingSet); sets[bindingSet]=k.Copy(Mock.modified) end
 return sets
end
function Tests.native_mouseover_integration_backup_preserves_unsaved_modifier_before_applying()
 local k=ready(); local sets=savedModifierSets(k)
 assert(Mock.modified.MOUSEOVERCAST=="SHIFT" and sets[2].MOUSEOVERCAST=="NONE")
 assert(k.CurrentBindings:SetNativeMouseover(true)); apply(k)
 local backup=k.db.bindingBackups[k.Engine:ListBackups()[1].id]
 assert(backup.snapshot.modified.MOUSEOVERCAST=="SHIFT")
 assert(Mock.modified.MOUSEOVERCAST=="NONE" and sets[2].MOUSEOVERCAST=="NONE" and Mock.bindingSet==2)
 assert(Mock.cvars.enableMouseoverCast=="1" and Mock.cvars.autoSelfCast=="1")
end
function Tests.native_mouseover_integration_failed_inactive_read_retains_unsaved_modifier()
 local k=ready(); savedModifierSets(k)
 local originalBindings=k.Copy(Mock.bindings); local count=GetNumBindings; local failed=false
 GetNumBindings=function()
  if Mock.bindingSet==1 and not failed then failed=true; error("inactive binding read rejected") end
  return count()
 end
 assert(k.CurrentBindings:SetNativeMouseover(true))
 assert(k.Engine:ApplyCurrentEdits()=="pending"); local ok=Mock:Drain()
 assert(not ok and failed and Mock.modified.MOUSEOVERCAST=="SHIFT" and Mock.bindingSet==2)
 assert(Mock.cvars.enableMouseoverCast=="0" and Mock.cvars.autoSelfCast=="0")
 sameMap(Mock.bindings,originalBindings)
 assert(k.CurrentBindings:HasEdits() and not k.db.recoveryRequired)
end
