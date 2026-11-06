-- Current-profile persistence is independent of both editable preset drafts
-- and the undo snapshot recorded before each installation.
local function equal(a,b,path)
 path=path or "value"
 if type(a)~="table" or type(b)~="table" then
  assert(a==b,path..": expected "..tostring(b)..", got "..tostring(a)); return
 end
 for key,value in pairs(b) do equal(a[key],value,path.."."..tostring(key)) end
 for key in pairs(a) do assert(b[key]~=nil,path..": unexpected "..tostring(key)) end
end
local function run(k,method)
 local ok,why=k.Engine[method](k.Engine)
 if ok=="pending" then ok,why=Mock:Drain() end
 return ok,why
end
local function requireRun(k,method)
 local ok,why=run(k,method); assert(ok,tostring(why)); return why
end
local function mage()
 local k=TestAddon; Mock.class="MAGE"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 UnitClass=function() return "Mage","MAGE",8 end
 Mock:Learn(133,"Fireball"); Mock:Learn(116,"Frostbolt")
 Mock.bindings={ ["1"]="ACTIONBUTTON1",["2"]="ACTIONBUTTON2",F="OPENCHAT",G="TARGETSELF",
  BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION" }
 Mock.actions={[1]={"spell",133},[2]={"spell",116},[40]={"spell",133}}
 Mock.bindingInventory=nil; k:Init(); Mock:ResetWrites(); return k
end
local function draft(k)
 assert(k.CurrentBindings:StageEntry({spellID=116,label="Frostbolt"},"1"))
 k:UpdateSetting("wheel",false)
 return k.Copy(k.CurrentBindings.edits),k.Copy(k.db.presets),k.Copy(k.db.settings)
end
local function assertDrafts(k,current,presets,settings)
 equal(k.CurrentBindings.edits,current,"Current draft")
 equal(k.db.currentEditDraft,current,"Persisted Current draft")
 equal(k.db.presets,presets,"Preset drafts")
 equal(k.db.settings,settings,"Editing settings")
end

function Tests.current_profile_sync_reads_unsaved_live_controls_without_writes_or_applying_drafts()
 local k=mage(); Mock.bindingSet=1
 Mock.bindingSets[1]={F="TARGETSELF",BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION"}
 Mock.bindingSets[2]={G="OPENCHAT"}
 Mock.bindings.F12="TOGGLEBACKPACK"
 Mock.modified.SELFCAST="CTRL"; Mock.modified.MOUSEOVERCAST="SHIFT"
 Mock.cvars.autoSelfCast="1"; Mock.cvars.enableMouseoverCast="0"
 local current,presets,settings=draft(k)
 local bindings=k.Copy(Mock.bindings); local sets=k.Copy(Mock.bindingSets)
 local actions=k.Copy(Mock.actions); local modified=k.Copy(Mock.modified); local cvars=k.Copy(Mock.cvars)
 Mock:ResetWrites(); requireRun(k,"SyncCurrentProfile")
 assert(#Mock.writes==0,"Sync temporarily changed game controls while reading them")
 assert(k.db.currentProfile and k.db.currentProfile.snapshot,"Sync did not persist a Current profile")
 local snapshot=k.db.currentProfile.snapshot
 equal(snapshot.bindings,bindings,"Saved live bindings")
 assert(snapshot.bindingSet==1 and snapshot.native.actions[1].id==133,"Sync saved the staged draft instead of live state")
 assert(snapshot.bindings.BUTTON1=="CAMERAORSELECTORMOVE" and snapshot.bindings.BUTTON2=="TURNORACTION","Sync omitted hidden mouse controls")
 equal(Mock.bindings,bindings); equal(Mock.bindingSets,sets); equal(Mock.actions,actions)
 equal(Mock.modified,modified); equal(Mock.cvars,cvars)
 assert(GetCurrentBindingSet()==1)
 assertDrafts(k,current,presets,settings)
end

function Tests.current_profile_successful_current_apply_remembers_result_instead_of_undo_snapshot()
 local k=mage()
 assert(k.CurrentBindings:StageEntry({spellID=116,label="Frostbolt"},"1"))
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey.F,"F9"))
 requireRun(k,"ApplyCurrentEdits")
 assert(k.db.currentProfile,"Successful Current Apply did not capture an installed profile")
 local saved=k.db.currentProfile.snapshot
 assert(saved.native.actions[1].id==116 and saved.bindings.F9=="OPENCHAT" and not saved.bindings.F)
 local undo=k.db.bindingBackups[k.Engine:ListBackups()[1].id].snapshot
 assert(undo.native.actions[1].id==133 and undo.bindings.F=="OPENCHAT","Fixture did not distinguish result from undo state")
 Mock.actions[1]={"spell",133}; Mock.bindings.F9=nil; Mock.bindings.F="TARGETSELF"
 requireRun(k,"ReapplyCurrentProfile")
 assert(select(2,GetActionInfo(1))==116 and GetBindingAction("F9")=="OPENCHAT" and GetBindingAction("F")=="")
end

function Tests.current_profile_successful_preset_apply_remembers_installed_native_layout()
 local k=mage(); local ok,why=k:Apply(); assert(ok,why)
 assert(k.db.currentProfile and k.db.currentProfile.enabled,"Preset Apply did not save its installed profile")
 assert(k.db.currentProfile.appliedPreset==k.db.appliedPreset,"Saved Current profile missed the finalized preset identity")
 assert(k.db.currentProfile.appliedPresetSignature==k.db.appliedPresetSignature,"Saved Current profile missed the finalized preset signature")
 local installed=k.NativeBars:Snapshot(); local bindings=k.Copy(Mock.bindings)
 assert(installed.actions[1],"Fixture needs an installed primary spell")
 Mock.actions[1]={"item",1234}; Mock.bindings["1"]="OPENCHAT"
 requireRun(k,"ReapplyCurrentProfile")
 assert(k.NativeBars:SameContent(k.NativeBars:ReadSlot(1),installed.actions[1]))
 equal(Mock.bindings,bindings,"Reapplied preset bindings")
end

function Tests.current_profile_named_restore_remembers_restored_result_instead_of_undo()
 local k=mage()
 assert(k.CurrentBindings:StageEntry({spellID=116,label="Frostbolt"},"1"))
 requireRun(k,"ApplyCurrentEdits")
 local id=k.Engine:ListBackups()[1].id
 local ok,why=k.Engine:RestoreBackup(id)
 if ok=="pending" then ok,why=Mock:Drain() end
 assert(ok,why)
 assert(select(2,GetActionInfo(1))==133 and k.db.currentProfile.snapshot.native.actions[1].id==133)
 assert(k.db.bindingBackups[k.Engine:ListBackups()[1].id].snapshot.native.actions[1].id==116,"Named-restore fixture did not distinguish its undo state")
 Mock.actions[1]={"spell",116}; requireRun(k,"ReapplyCurrentProfile")
 assert(select(2,GetActionInfo(1))==133)
end

function Tests.current_profile_original_restore_remembers_original_live_setup()
 local k=mage(); Mock.actions[1]={"item",1234}; local bindings=k.Copy(Mock.bindings)
 local ok,why=k:Apply(); assert(ok,why)
 ok,why=k:Restore(); assert(ok,why)
 assert(k.db.currentProfile and not k.db.currentProfile.enabled)
 assert(k.db.currentProfile.snapshot.native.actions[1].kind=="item" and k.db.currentProfile.snapshot.native.actions[1].id==1234)
 assert(not k.db.currentProfile.appliedPreset and not k.db.currentProfile.appliedPresetSignature)
 Mock.actions[1]={"spell",116}; Mock.bindings.F="TARGETSELF"
 requireRun(k,"ReapplyCurrentProfile")
 assert(GetActionInfo(1)=="item" and select(2,GetActionInfo(1))==1234)
 equal(Mock.bindings,bindings,"Original setup profile bindings")
end

function Tests.current_profile_default_restore_remembers_default_keys_and_retained_bars()
 local k=mage(); Mock.bindings.F12="OPENCHAT"; requireRun(k,"SyncCurrentProfile")
 requireRun(k,"RestoreDefaults")
 local bindings=k.Copy(Mock.bindings); local profile=k.db.currentProfile
 equal(profile.snapshot.bindings,bindings,"Default restore profile keys")
 assert(profile.snapshot.bindingSet==2 and not profile.enabled and not profile.appliedPreset)
 assert(profile.snapshot.native.actions[1].id==133 and profile.snapshot.native.actions[40].id==133)
 Mock.bindings.F12="OPENCHAT"; Mock.actions[1]={"spell",116}
 requireRun(k,"ReapplyCurrentProfile")
 equal(Mock.bindings,bindings,"Reapplied default bindings")
 assert(select(2,GetActionInfo(1))==133)
end

function Tests.current_profile_reapply_restores_synced_controls_and_settings_without_applying_drafts()
 local k=mage(); Mock.modified.SELFCAST="CTRL"; Mock.cvars.autoSelfCast="1"
 requireRun(k,"SyncCurrentProfile")
 local current,presets,settings=draft(k)
 Mock.actions[1]={"item",1234}; Mock.bindings.F="TARGETSELF"; Mock.bindings.F12="OPENCHAT"
 Mock.modified.SELFCAST="SHIFT"; Mock.cvars.autoSelfCast="0"
 requireRun(k,"ReapplyCurrentProfile")
 assert(select(2,GetActionInfo(1))==133,"Reapply installed the unsaved Frostbolt draft")
 assert(GetBindingAction("F")=="OPENCHAT" and GetBindingAction("F12")=="")
 assert(Mock.modified.SELFCAST=="CTRL" and Mock.cvars.autoSelfCast=="1","Reapply did not restore saved casting settings")
 assertDrafts(k,current,presets,settings)
end

local function oldHeal()
 local k=TestAddon; Mock.class="DRUID"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 Mock:Learn(774,"Rejuvenation"); k:Init(); k.API:InvalidateSpellbook()
 local body="#showtooltip Rejuvenation\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] Rejuvenation"
 local name=k.Macros:Name(body); local index=CreateMacro(name,774,body,true); k.db.ownedMacros[name]=body
 local entry={spellID=774,name="Rejuvenation",label="Rejuvenation",targetMode="mouseover",targeting="help",
  body=body,macroName=name,command="MACRO "..name,content={kind="macro",name=name,body=body}}
 k.db.currentLayout={keys={F9=k.Copy(entry)},slots={[1]=k.Copy(entry)}}
 Mock.actions={[1]={"macro",index},[2]={"macro",GetMacroIndexByName("UserMacro")}}
 Mock.bindings={ ["1"]="ACTIONBUTTON1",["2"]="ACTIONBUTTON2",F9="MACRO "..name,G="MACRO UserMacro",
  BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION" }
 Mock.bindingInventory=nil; Mock.bindingSet=2; Mock.bindingSets[2]=k.Copy(Mock.bindings)
 k.CurrentBindings:Invalidate(); Mock:ResetWrites(); return k,name,body
end
local function assertRepaired(k,oldName)
 local action=k.NativeBars:ReadSlot(1)
 assert(action.kind=="macro" and action.name~=oldName and action.body:find("[help,nodead][@player] Rejuvenation",1,true),"Reapply retained the obsolete heal body")
 assert(k.db.ownedMacros[action.name]==action.body and GetBindingAction("F9")=="MACRO "..action.name,"Rebuilt macro did not retain owned direct-key routing")
 assert(GetBindingAction("G")=="MACRO UserMacro" and k.NativeBars:ReadSlot(2).name=="UserMacro")
 assert(select(3,GetMacroInfo(GetMacroIndexByName("UserMacro")))=="/say preserved","Reapply rewrote a personal macro")
end

function Tests.current_profile_reapply_rebuilds_saved_owned_heals_using_current_macro_rules()
 local k,name=oldHeal(); requireRun(k,"SyncCurrentProfile")
 requireRun(k,"ReapplyCurrentProfile"); assertRepaired(k,name)
 assert(k.db.currentProfile.snapshot.native.actions[1].body:find("[help,nodead][@player]",1,true),"Successful reapply saved the obsolete helper again")
end

function Tests.current_profile_reapply_preserves_edited_generated_macro_and_uses_new_owned_identity()
 local k,name=oldHeal(); requireRun(k,"SyncCurrentProfile")
 EditMacro(GetMacroIndexByName(name),name,774,"/say my edited helper")
 requireRun(k,"ReapplyCurrentProfile"); assertRepaired(k,name)
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))=="/say my edited helper","Reapply overwrote a user's edit to an old generated macro")
end

function Tests.current_profile_sync_adopts_personal_edit_to_generated_macro_without_resurrecting_owned_text()
 local k,name=oldHeal(); local personal="/say this is my personal healing helper"
 EditMacro(GetMacroIndexByName(name),name,774,personal)
 local macros=k.Copy(Mock.macros)
 requireRun(k,"SyncCurrentProfile")
 assert(not k.db.currentProfile.ownedMacros[name],"Sync retained ownership of a personally edited macro")
 assert(not k.db.currentProfile.currentLayout.keys.F9 and not k.db.currentProfile.currentLayout.slots[1],"Sync retained stale spell metadata for a personal macro")
 requireRun(k,"ReapplyCurrentProfile")
 assert(GetBindingAction("F9")=="MACRO "..name,"Reapply regenerated the obsolete direct-key helper after Sync")
 assert(k.NativeBars:ReadSlot(1).name==name and k.NativeBars:ReadSlot(1).body==personal)
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))==personal)
 equal(Mock.macros,macros,"Reapply created a generated recovery macro for an adopted personal edit")
end

function Tests.current_profile_reapply_without_saved_profile_uses_legacy_installed_intent()
 local k=mage(); local ok,why=k:Apply(); assert(ok,why)
 local installed=k.NativeBars:ReadSlot(1); local bindings=k.Copy(Mock.bindings)
 k.db.currentProfile=nil
 Mock.actions[1]={"item",1234}; Mock.bindings["1"]="OPENCHAT"
 requireRun(k,"ReapplyCurrentProfile")
 assert(k.NativeBars:SameContent(k.NativeBars:ReadSlot(1),installed),"Legacy reapply captured the accidental live action")
 equal(Mock.bindings,bindings,"Legacy installed bindings")
 assert(k.db.currentProfile,"Legacy reapply did not establish a Current profile")
end

function Tests.current_profile_sync_and_reapply_reject_combat_or_busy_without_mutation()
 local k=mage(); requireRun(k,"SyncCurrentProfile")
 local profile=k.Copy(k.db.currentProfile)
 for _,state in ipairs({"combat","busy"}) do
  Mock.combat=state=="combat"; k.Engine.busy=state=="busy"
  for _,method in ipairs({"SyncCurrentProfile","ReapplyCurrentProfile"}) do
   Mock:ResetWrites(); local ok,why=k.Engine[method](k.Engine)
   assert(ok==false and type(why)=="string",method.." was accepted during "..state)
   assert(#Mock.writes==0,method.." wrote controls during "..state)
   equal(k.db.currentProfile,profile,"Rejected operation changed saved profile")
  end
 end
 Mock.combat=false; k.Engine.busy=false
end

function Tests.current_profile_reapply_failure_rolls_back_and_preserves_saved_profile_and_drafts()
 local k=mage(); requireRun(k,"SyncCurrentProfile")
 local current,presets,settings=draft(k); local profile=k.Copy(k.db.currentProfile)
 Mock.actions[1]={"spell",116}; Mock.bindings.F="TARGETSELF"
 local before=k.NativeBars:Snapshot(); local bindings=k.Copy(Mock.bindings)
 local set=SetBinding; local rejected=false
 SetBinding=function(key,command,...)
  if not rejected and key=="F" and command=="OPENCHAT" then rejected=true; return false end
  return set(key,command,...)
 end
 local ok,why=run(k,"ReapplyCurrentProfile")
 assert(not ok and rejected and tostring(why):find("rolled back",1,true),tostring(why))
 for slot,content in pairs(before.actions) do assert(k.NativeBars:SameContent(k.NativeBars:ReadSlot(slot),content),"Rollback lost native slot "..slot) end
 equal(Mock.bindings,bindings,"Failed reapply live keys")
 equal(k.db.currentProfile,profile,"Failed reapply stored profile")
 assertDrafts(k,current,presets,settings)
 assert(not GetCursorInfo() and k.Engine:ListBackups()[1].status=="failed")
end

function Tests.current_profile_post_apply_capture_failure_rolls_back_live_state_and_restores_draft()
 local k=mage(); requireRun(k,"SyncCurrentProfile")
 local profile=k.Copy(k.db.currentProfile)
 local current,presets,settings=draft(k)
 local actions=k.NativeBars:Snapshot(); local bindings=k.Copy(Mock.bindings)
 k.CurrentBindings.CaptureProfile=function() error("Injected Current profile capture failure") end
 local ok,why=run(k,"ApplyCurrentEdits")
 assert(not ok and tostring(why):find("rolled back",1,true) and tostring(why):find("Injected Current profile capture failure",1,true),tostring(why))
 for slot,content in pairs(actions.actions) do assert(k.NativeBars:SameContent(k.NativeBars:ReadSlot(slot),content),"Post-apply capture failure lost slot "..slot) end
 equal(Mock.bindings,bindings,"Post-apply capture failure bindings")
 equal(k.db.currentProfile,profile,"Post-apply capture failure saved profile")
 assertDrafts(k,current,presets,settings)
 assert(k.CurrentBindings:HasEdits() and not GetCursorInfo() and k.Engine:ListBackups()[1].status=="failed")
end

function Tests.current_profile_reapply_full_macro_bank_rejects_before_erasing_working_actions()
 local k,name,body=oldHeal(); requireRun(k,"SyncCurrentProfile")
 local profile=k.Copy(k.db.currentProfile)
 local _,count=GetNumMacros()
 for i=count+1,MAX_CHARACTER_MACROS do CreateMacro("Personal"..i,1,"/say "..i,true) end
 local bindings=k.Copy(Mock.bindings); local macros=k.Copy(Mock.macros)
 Mock:ResetWrites()
 local ok,why=run(k,"ReapplyCurrentProfile")
 assert(not ok and tostring(why):lower():find("macro",1,true),tostring(why))
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~="action" and write[1]~="pickupaction" and write[1]~="createmacro" and write[1]~="editmacro" and write[1]~="deletemacro","Capacity preflight mutated an action or macro")
 end
 equal(Mock.bindings,bindings,"Capacity failure changed live bindings")
 equal(Mock.macros,macros,"Capacity failure changed personal macros")
 assert(k.NativeBars:ReadSlot(1).body==body and GetBindingAction("F9")=="MACRO "..name,"Capacity failure erased the working old heal")
 equal(k.db.currentProfile,profile,"Capacity failure changed stored profile")
end

function Tests.current_profile_reapply_cleanup_removes_replaced_owned_heal_after_success()
 local k,name=oldHeal(); requireRun(k,"SyncCurrentProfile")
 requireRun(k,"ReapplyCurrentProfile"); assertRepaired(k,name)
 local replacement=k.NativeBars:ReadSlot(1)
 Mock:Advance(0.1,6)
 assert(GetMacroIndexByName(name)==0 and not k.db.ownedMacros[name],"Successful reapply retained an unreferenced obsolete helper")
 assertRepaired(k,name)
 assert(k.NativeBars:ReadSlot(1).name==replacement.name and GetBindingAction("F9")=="MACRO "..replacement.name)
end

function Tests.current_profile_reapply_cleanup_reuses_correct_owned_macro_without_recreating_it()
 local k,name=oldHeal(); requireRun(k,"SyncCurrentProfile")
 requireRun(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,6)
 local correct=k.NativeBars:ReadSlot(1); local macros=k.Copy(Mock.macros)
 Mock:ResetWrites(); requireRun(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,6)
 assert(k.NativeBars:ReadSlot(1).name==correct.name and GetBindingAction("F9")=="MACRO "..correct.name)
 equal(Mock.macros,macros,"Reapplying a correct helper changed the macro bank")
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~="createmacro" and write[1]~="editmacro" and write[1]~="deletemacro","A correct owned helper was recreated or deleted")
 end
 assertRepaired(k,name)
end

function Tests.current_profile_reapply_cleanup_preserves_personally_edited_original()
 local k,name=oldHeal(); requireRun(k,"SyncCurrentProfile")
 EditMacro(GetMacroIndexByName(name),name,774,"/say my personal edited original")
 requireRun(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,6)
 assertRepaired(k,name)
 assert(GetMacroIndexByName(name)>0 and select(3,GetMacroInfo(GetMacroIndexByName(name)))=="/say my personal edited original","Cleanup removed a personal edit after saved intent was restored")
end

local function inactiveCleanup(activeSet)
 local k,name,body=oldHeal(); local inactiveSet=activeSet==1 and 2 or 1
 Mock.bindingSet=activeSet; Mock.bindingSets[activeSet]=k.Copy(Mock.bindings)
 Mock.bindingSets[inactiveSet]={F10="MACRO "..name,BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION"}
 local inactive=k.Copy(Mock.bindingSets[inactiveSet])
 requireRun(k,"SyncCurrentProfile"); requireRun(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,6)
 assert(GetCurrentBindingSet()==activeSet and GetMacroIndexByName(name)>0,"Cleanup removed a helper referenced by the inactive binding scope")
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))==body)
 equal(Mock.bindingSets[inactiveSet],inactive,"Inactive macro binding scope")
 assertRepaired(k,name)
end

function Tests.current_profile_reapply_cleanup_preserves_inactive_account_macro_reference()
 inactiveCleanup(2)
end

function Tests.current_profile_reapply_cleanup_preserves_inactive_character_macro_reference()
 inactiveCleanup(1)
end

function Tests.current_profile_reapply_failure_never_queues_cleanup_of_saved_originals()
 local k,name,body=oldHeal(); requireRun(k,"SyncCurrentProfile")
 local profile=k.Copy(k.db.currentProfile); local queued=0
 local queue=k.AvailabilityEngine.QueueCleanup
 k.AvailabilityEngine.QueueCleanup=function(self,candidates) queued=queued+1; return queue(self,candidates) end
 local set=SetBinding; local rejected=false
 SetBinding=function(key,command,...)
  if not rejected and key=="F9" and command and command~="MACRO "..name then rejected=true; return false end
  return set(key,command,...)
 end
 local ok,why=run(k,"ReapplyCurrentProfile")
 assert(not ok and rejected and tostring(why):find("rolled back",1,true),tostring(why))
 Mock:Advance(0.1,6)
 assert(queued==0 and not next(k.AvailabilityEngine.pendingCleanup or {}),"Failed reapply queued obsolete-macro cleanup")
 assert(GetMacroIndexByName(name)>0 and select(3,GetMacroInfo(GetMacroIndexByName(name)))==body)
 assert(k.NativeBars:ReadSlot(1).name==name and GetBindingAction("F9")=="MACRO "..name)
 equal(k.db.currentProfile,profile,"Failed reapply changed the saved original profile")
end

function Tests.current_profile_reapply_cleanup_retains_macro_needed_by_original_backup()
 local k,name,body=oldHeal(); requireRun(k,"SyncCurrentProfile")
 k.db.backup=k.Copy(k.db.currentProfile.snapshot)
 requireRun(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,6)
 assertRepaired(k,name)
 assert(GetMacroIndexByName(name)>0 and select(3,GetMacroInfo(GetMacroIndexByName(name)))==body,"Cleanup deleted an original-backup macro that original Restore cannot recreate")
 assert(k.db.backup.native.actions[1].name==name and k.db.backup.native.actions[1].body==body)
end

function Tests.current_profile_reapply_cleanup_retains_named_backup_macro_without_rebuild_metadata()
 local k,name,body=oldHeal(); requireRun(k,"SyncCurrentProfile")
 local backup=k.db.bindingBackups[k.Engine:ListBackups()[1].id]
 backup.runtime.currentLayout={keys={},slots={}}
 backup.runtime.appliedPlan=nil; backup.runtime.enabled=false
 requireRun(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,6)
 assertRepaired(k,name)
 assert(GetMacroIndexByName(name)>0 and select(3,GetMacroInfo(GetMacroIndexByName(name)))==body,"Cleanup deleted a named-backup macro lacking reconstructable owned action metadata")
end

function Tests.current_profile_reapply_cleanup_removed_helper_is_recreated_by_semantic_named_restore()
 local k,name,body=oldHeal(); requireRun(k,"SyncCurrentProfile")
 local id=k.Engine:ListBackups()[1].id
 requireRun(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,6)
 assert(GetMacroIndexByName(name)==0,"Fixture did not clean the obsolete owned macro")
 local ok,why=k.Engine:RestoreBackup(id)
 if ok=="pending" then ok,why=Mock:Drain() end
 assert(ok,why)
 local restored=k.NativeBars:ReadSlot(1)
 assert(restored.kind=="macro" and restored.body==body,"Named restore did not reconstruct the cleaned helper's exact saved text")
 assert(GetBindingAction("F9")=="MACRO "..restored.name and k.db.ownedMacros[restored.name]==body)
 assert(select(3,GetMacroInfo(GetMacroIndexByName("UserMacro")))=="/say preserved")
end
