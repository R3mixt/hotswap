-- WoW may return an added terminal newline in GetMacroInfo. Only verified
-- generated identities may ignore those line endings; personal text stays exact.
local function run(k,method)
 local ok,why=k.Engine[method](k.Engine)
 if ok=="pending" then ok,why=Mock:Drain() end
 assert(ok,tostring(why))
end
local function oldHeal(ending)
 local k=TestAddon; Mock.class="DRUID"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 Mock:Learn(774,"Rejuvenation"); k:Init(); k.API:InvalidateSpellbook()
 local body="#showtooltip Rejuvenation\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] Rejuvenation"
 local name=k.Macros:Name(body); CreateMacro(name,774,body..(ending or ""),true)
 k.db.ownedMacros[name]=body
 local entry={spellID=774,name="Rejuvenation",label="Rejuvenation",targetMode="mouseover",targeting="help",
  body=body,macroName=name,command="MACRO "..name,content={kind="macro",name=name,body=body}}
 k.db.currentLayout={keys={F9=k.Copy(entry)},slots={[1]=k.Copy(entry)}}
 Mock.actions={[1]={"macro",GetMacroIndexByName(name)}}
 Mock.bindings={ ["1"]="ACTIONBUTTON1",F9="MACRO "..name,
  BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION" }
 Mock.bindingInventory=nil; Mock.bindingSet=2; Mock.bindingSets[2]=k.Copy(Mock.bindings)
 k.CurrentBindings:Invalidate(); Mock:ResetWrites()
 return k,name,body
end
local function assertRepaired(k,oldName)
 local live=k.NativeBars:ReadSlot(1)
 assert(live.kind=="macro" and live.name~=oldName,"Reapply kept the obsolete generated identity")
 assert(live.body:find("[help,nodead][@player] Rejuvenation",1,true),"Reapply did not add the automatic player fallback")
 assert(GetBindingAction("F9")=="MACRO "..live.name,"Direct-key routing did not follow the regenerated macro")
 assert(k.Macros:SameBody(live.name,k.db.ownedMacros[live.name],live.body),"The repaired macro lost verified ownership")
 return live
end
local function syncAndRepair(ending)
 local k,name,body=oldHeal(ending)
 assert(k.Macros:FindExact(name,body),"Terminal line ending prevented exact owned lookup")
 run(k,"SyncCurrentProfile")
 local saved=k.db.currentProfile
 assert(saved.ownedMacros[name]==body,"Sync discarded ownership because WoW added a terminal line ending")
 assert(saved.currentLayout.slots[1] and saved.currentLayout.keys.F9,"Sync discarded the generated spell metadata")
 run(k,"ReapplyCurrentProfile"); assertRepaired(k,name)
end

function Tests.owned_macro_terminal_lf_preserves_sync_metadata_and_reapplies_new_heal_rules()
 syncAndRepair("\n")
end

function Tests.owned_macro_terminal_crlf_preserves_sync_metadata_and_reapplies_new_heal_rules()
 syncAndRepair("\r\n")
end

function Tests.owned_macro_api_terminal_newline_allows_creation_verification_and_reuse()
 local k,name=oldHeal()
 local original=GetMacroInfo
 GetMacroInfo=function(...)
  local found,icon,body=original(...)
  if type(body)=="string" then body=body:gsub("[\r\n]+$","").."\n" end
  return found,icon,body
 end
 run(k,"SyncCurrentProfile"); run(k,"ReapplyCurrentProfile")
 local repaired=assertRepaired(k,name)
 assert(k.Macros:FindExact(repaired.name,k.db.ownedMacros[repaired.name]),"A newly created macro failed the normalized API read")
 Mock:Advance(0.1,8); Mock:ResetWrites()
 run(k,"ReapplyCurrentProfile"); Mock:Advance(0.1,8)
 assert(k.NativeBars:ReadSlot(1).name==repaired.name,"Reapply changed a correct generated identity")
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~="createmacro" and write[1]~="editmacro" and write[1]~="deletemacro","Reapply recreated a correct macro because the API appended a newline")
 end
end

function Tests.owned_macro_line_ending_comparison_requires_registered_name_and_exact_commands()
 local k,name,body=oldHeal()
 assert(k.Macros:SameBody(name,body,body.."\n"))
 assert(k.Macros:SameBody(name,body.."\r\n",body.."\n\n"))
 assert(not k.Macros:SameBody(name,body,body.." \n"),"Trailing spaces were normalized")
 assert(not k.Macros:SameBody(name,body,body:gsub("/cast ","/cast  ").."\n"),"Internal whitespace was normalized")
 assert(not k.Macros:SameBody(name,body,body:gsub("\n","\r\n").."\n"),"Internal line endings were normalized")
 assert(not k.Macros:SameBody(name,body,body.."\n/say changed\n"),"An added command was normalized")
 assert(not k.Macros:SameBody("KBO_unregistered",body,body.."\n"),"The generated-name prefix supplied ownership")
 assert(not k.Macros:SameBody(name,"/say changed","/say changed\n"),"Matching changed text bypassed the registered body")
 assert(k.Macros:SameBody("KBO_saved",body,body.."\n",{KBO_saved=body}),"A supplied backup ownership registry was ignored")
 assert(not k.Macros:SameBody(name,body,body.."\n",{}),"Live ownership overrode a supplied empty registry")
end

function Tests.owned_macro_newline_does_not_adopt_unregistered_generated_name()
 local k,name,body=oldHeal("\n")
 k.db.ownedMacros[name]=nil; k.db.currentLayout={keys={},slots={}}
 assert(not k.Macros:FindExact(name,body),"An unregistered KBO name received normalized exact lookup")
 assert(not k.Macros:FindOwned(name,body),"An unregistered KBO name was adopted")
 run(k,"SyncCurrentProfile"); run(k,"ReapplyCurrentProfile")
 assert(not k.db.ownedMacros[name] and not k.db.currentProfile.ownedMacros[name])
 assert(k.NativeBars:ReadSlot(1).name==name and select(3,GetMacroInfo(GetMacroIndexByName(name)))==body.."\n")
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~="createmacro" and write[1]~="editmacro" and write[1]~="deletemacro","Reapply changed an unowned macro")
 end
end

function Tests.owned_macro_actual_command_edit_remains_personal_after_sync_and_reapply()
 local k,name=oldHeal()
 local personal="/say my personal helper\n"
 EditMacro(GetMacroIndexByName(name),name,774,personal); Mock:ResetWrites()
 run(k,"SyncCurrentProfile")
 assert(not k.db.currentProfile.ownedMacros[name])
 assert(not k.db.currentProfile.currentLayout.slots[1] and not k.db.currentProfile.currentLayout.keys.F9)
 run(k,"ReapplyCurrentProfile")
 assert(GetBindingAction("F9")=="MACRO "..name and k.NativeBars:ReadSlot(1).name==name)
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))==personal,"Reapply replaced a personal command edit")
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~="createmacro" and write[1]~="editmacro" and write[1]~="deletemacro","Reapply changed a personally edited macro")
 end
end

function Tests.owned_macro_line_ending_handling_does_not_relax_personal_macroref_fingerprint()
 local k=oldHeal(); local body="/say exact personal text"
 CreateMacro("Personal",1,body,true); Mock.bindings.G="MACRO Personal"; Mock.bindingInventory=nil
 local action=k.CurrentBindings:Build().byKey.G
 assert(action.macroFingerprint==k.Macros:Name(body))
 EditMacro(GetMacroIndexByName("Personal"),"Personal",1,body.."\n")
 local updated=k.CurrentBindings:Build().byKey.G
 assert(updated.macroFingerprint==k.Macros:Name(body.."\n") and updated.macroFingerprint~=action.macroFingerprint)
 local ok,why=k.CurrentBindings:StageEntry({descriptor={kind="macroref",macroName="Personal",macroFingerprint=action.macroFingerprint}},"F10")
 assert(not ok and tostring(why):find("changed",1,true),"An outdated personal macroref fingerprint was accepted")
 assert(not k.NativeBars:SameContent({kind="macro",name="Personal",body=body},{kind="macro",name="Personal",body=body.."\n"}),"Personal snapshot text lost exact comparison")
end

function Tests.owned_macro_raw_snapshot_without_semantic_metadata_stays_verbatim()
 local k,name,body=oldHeal("\n"); k.db.currentLayout={keys={},slots={}}
 run(k,"SyncCurrentProfile")
 assert(k.db.currentProfile.ownedMacros[name]==body,"Sync lost a raw owned macro")
 run(k,"ReapplyCurrentProfile")
 assert(GetBindingAction("F9")=="MACRO "..name and k.NativeBars:ReadSlot(1).name==name,"A raw helper changed identity")
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))==body.."\n","A raw helper was interpreted as a spell and rewritten")
 assert(k.db.currentProfile.ownedMacros[name],"A raw helper lost ownership after reapply")
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~="createmacro" and write[1]~="editmacro" and write[1]~="deletemacro","A raw helper was unnecessarily recreated")
 end
end

function Tests.owned_macro_reapply_recovers_metadata_lost_by_older_sync_and_reapply()
 local k,name,body=oldHeal("\n")
 local editedName="KBO_personally_edited"; local personal="/say my changed helper\n"
 CreateMacro(editedName,774,personal,true); k.db.ownedMacros[editedName]=body
 local edited=k.Copy(k.db.currentLayout.slots[1])
 edited.macroName=editedName; edited.command="MACRO "..editedName; edited.content.name=editedName
 k.db.currentLayout.slots[2]=k.Copy(edited); k.db.currentLayout.keys.G=k.Copy(edited)
 Mock.actions[2]={"macro",GetMacroIndexByName(editedName)}; Mock.bindings.G="MACRO "..editedName
 Mock.bindingSets[2]=k.Copy(Mock.bindings); Mock.bindingInventory=nil
 local patched=k.Macros.SameBody
 k.Macros.SameBody=function(self,macroName,expected,actual) return type(expected)=="string" and expected==actual end
 run(k,"SyncCurrentProfile"); run(k,"ReapplyCurrentProfile")
 assert(not next(k.db.currentLayout.slots) and not next(k.db.currentLayout.keys),"Fixture did not reproduce historical metadata loss")
 assert(not k.db.currentProfile.ownedMacros[name] and not k.db.currentProfile.currentLayout.slots[1])
 k.Macros.SameBody=patched
 run(k,"ReapplyCurrentProfile"); assertRepaired(k,name)
 assert(k.db.currentLayout.slots[1] and k.db.currentLayout.keys.F9,"Recovery did not restore the proved Current semantics")
 assert(not k.db.currentLayout.slots[2] and not k.db.currentLayout.keys.G,"Recovery re-adopted stale metadata for a personal edit")
 assert(k.NativeBars:ReadSlot(2).name==editedName and GetBindingAction("G")=="MACRO "..editedName)
 assert(select(3,GetMacroInfo(GetMacroIndexByName(editedName)))==personal,"Recovery rewrote a personal helper")
end

function Tests.owned_macro_recovery_requires_saved_destination_and_current_registry_evidence()
 local k,name,body=oldHeal("\n")
 run(k,"SyncCurrentProfile")
 local saved=k.db.currentProfile
 saved.currentLayout={keys={},slots={}}; saved.ownedMacros={}
 saved.snapshot.native.actions[1]={kind="spell",id=774}; saved.snapshot.bindings.F9="OPENCHAT"
 local prepared=k.CurrentBindings:BuildProfileReapply(saved)
 assert(not prepared.currentLayout.slots[1] and not prepared.currentLayout.keys.F9,"Recovery reinstated an old destination after its saved action changed")
 saved.snapshot.native.actions[1]={kind="macro",name=name,body=body.."\n"}; saved.snapshot.bindings.F9="MACRO "..name
 k.db.ownedMacros[name]=nil
 prepared=k.CurrentBindings:BuildProfileReapply(saved)
 assert(not prepared.currentLayout.slots[1] and not prepared.currentLayout.keys.F9,"Backup metadata supplied missing current ownership")
end

function Tests.owned_macro_direct_only_recovery_checks_live_body_without_snapshot_evidence()
 local k,name=oldHeal("\n"); Mock.actions={}; k.db.currentLayout.slots={}
 run(k,"SyncCurrentProfile")
 local saved=k.db.currentProfile; saved.currentLayout={keys={},slots={}}; saved.ownedMacros={}
 local prepared=k.CurrentBindings:BuildProfileReapply(saved)
 assert(prepared.currentLayout.keys.F9,"Direct-only generated metadata with proved live ownership was not recovered")
 EditMacro(GetMacroIndexByName(name),name,774,"/say changed after saving\n")
 prepared=k.CurrentBindings:BuildProfileReapply(saved)
 assert(not prepared.currentLayout.keys.F9,"A direct name without saved body evidence resurrected an edited macro")
end

local function oldPresetHeal()
 local k,name,body=oldHeal("\n")
 k.db.currentLayout={keys={},slots={}}; k.db.enabled=true
 k.db.appliedPlan={class="DRUID",flavor="era",actions={{id="druid.rejuvenation",name="Rejuvenation",label="Rejuvenation",
  spellName="Rejuvenation",spellIDs={774},spellID=774,targeting="help",targetMode="mouseover",known=true,
  body=body,macroName=name,nativeMacro=true,nativeSlot=1}},
  settings={flavor="auto",cancelForUtility=false,selfFallback=false},
  nativeLayout={placements={{actionID="druid.rejuvenation",slot=1}},keys={F9={macroAction="druid.rejuvenation"}},detachedKeys={}}}
 return k,name,body
end
local function erasePresetIdentityWithOldComparison(k)
 local patched=k.Macros.SameBody
 k.Macros.SameBody=function(self,macroName,expected,actual) return type(expected)=="string" and expected==actual end
 run(k,"SyncCurrentProfile"); run(k,"ReapplyCurrentProfile")
 k.Macros.SameBody=patched
 local action=k.db.currentProfile.appliedPlan.actions[1]
 assert(not action.macroName and action.body:find("[help,nodead][@player]",1,true),"Fixture did not reproduce detached preset identity loss")
end

function Tests.owned_macro_reapply_recovers_erased_detached_preset_identity_from_matching_history()
 local k,name=oldPresetHeal(); erasePresetIdentityWithOldComparison(k)
 local settings=k.Copy(k.db.currentProfile.appliedPlan.settings)
 assert(k.db.currentProfile.appliedPlan.nativeLayout.placements[1].detached)
 run(k,"ReapplyCurrentProfile"); assertRepaired(k,name)
 local plan=k.db.currentProfile.appliedPlan; local action=plan.actions[1]
 assert(action.id=="druid.rejuvenation" and action.targetMode=="mouseover","Recovery replaced the saved semantic action")
 assert(plan.nativeLayout.placements[1].slot==1 and plan.nativeLayout.placements[1].actionID==action.id
  and not plan.nativeLayout.placements[1].detached,"Recovery changed the saved placement")
 assert(plan.nativeLayout.keys.F9.macroAction==action.id and not plan.nativeLayout.detachedKeys.F9,"Recovery changed the saved direct-key source")
 for key,value in pairs(settings) do assert(plan.settings[key]==value,"Recovery changed the saved setting "..key) end
 assert(GetBindingAction("1")=="ACTIONBUTTON1","Recovery changed the native key assignment")
end

function Tests.owned_macro_erased_preset_recovery_preserves_personal_macro_in_saved_destination()
 local k,name=oldPresetHeal(); local personal="/say keep this personal helper\n"
 EditMacro(GetMacroIndexByName(name),name,774,personal)
 erasePresetIdentityWithOldComparison(k); Mock:ResetWrites()
 run(k,"ReapplyCurrentProfile")
 assert(k.NativeBars:ReadSlot(1).name==name and GetBindingAction("F9")=="MACRO "..name)
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))==personal,"Historical preset metadata replaced personal text")
 assert(k.db.currentProfile.appliedPlan.nativeLayout.placements[1].detached and k.db.currentProfile.appliedPlan.nativeLayout.detachedKeys.F9)
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~="createmacro" and write[1]~="editmacro" and write[1]~="deletemacro","Historical preset metadata created a helper for personal text")
 end
end

function Tests.owned_macro_erased_direct_only_preset_identity_requires_matching_key_history()
 local k,name=oldPresetHeal(); Mock.actions={}; k.db.appliedPlan.nativeLayout.placements={}
 erasePresetIdentityWithOldComparison(k)
 run(k,"ReapplyCurrentProfile")
 local command=GetBindingAction("F9"); local newName=command:match("^MACRO (.+)$")
 assert(newName and newName~=name,"Direct-only historical preset identity was not recovered")
 assert(select(3,GetMacroInfo(GetMacroIndexByName(newName))):find("[help,nodead][@player]",1,true))
 assert(not next(Mock.actions),"Direct-only recovery restored a historical bar position")
end
