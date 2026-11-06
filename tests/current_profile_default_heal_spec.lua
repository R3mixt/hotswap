local function runProfile(k,method)
 local ok,why=k.Engine[method](k.Engine)
 if ok=="pending" then ok,why=Mock:Drain() end
 assert(ok,tostring(why))
end

local function legacyDefaultHeal(mode)
 local k=TestAddon; Mock.class="DRUID"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 Mock:Learn(2090,"Rejuvenation","Rank 3"); Mock:Learn(2091,"Rejuvenation","Rank 4")
 k:Init(); k:GetSettings().selfFallback=false
 local ok,why=k:Apply(); assert(ok,why)
 local spell="Rejuvenation(Rank 3)"
 local oldBody="#showtooltip "..spell.."\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] "..spell
 local newBody="#showtooltip "..spell.."\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] "..spell
 local oldName=k.Macros:Name(oldBody); local index=CreateMacro(oldName,2090,oldBody,true)
 k.db.ownedMacros[oldName]=oldBody
 local plan=k.db.appliedPlan; plan.settings.selfFallback=false
 local slots,first={},nil
 -- Reproduce a persisted pre-fix preset using a deliberately downranked heal.
 -- Native routing comes from a real preset Apply; macro generation is never stubbed.
 for _,action in ipairs(plan.actions) do
  if action.id:find("druid.rejuvenation",1,true)==1 then
   action.targetMode=mode; action.selectedSpellID=2090; action.explicitRank=true; action.selectedRank="Rank 3"
   action.spellID=2090; action.spellName="Rejuvenation"; action.known=true
   action.body=oldBody; action.macroName=oldName; action.macroIndex=index
   if action.nativeSlot then Mock.actions[action.nativeSlot]={"macro",index}; slots[#slots+1]=action.nativeSlot end
   first=first or action
  end
 end
 assert(first and #slots>0,"Fixture did not install a helpful action")
 plan.nativeLayout.keys.F9={macroAction=first.id}
 Mock.bindings.F9="MACRO "..oldName
 Mock.bindings.F10="MACRO UserMacro"
 Mock.bindingSets[2]=k.Copy(Mock.bindings); Mock.bindingSet=2
 Mock.bindingInventory=nil; k.CurrentBindings:Invalidate(); Mock:ResetWrites()
 return k,oldName,oldBody,newBody,slots,k.Copy(Mock.bindings)
end

local function sameKeysExceptHelper(k,before,newName)
 for key,command in pairs(before) do
  assert(GetBindingAction(key)==(key=="F9" and "MACRO "..newName or command),"Reapply moved or replaced key "..key)
 end
 for key in pairs(Mock.bindings) do assert(before[key]~=nil,"Reapply added an unrequested key "..key) end
 assert(GetBindingAction("F10")=="MACRO UserMacro")
 assert(select(3,GetMacroInfo(GetMacroIndexByName("UserMacro")))=="/say preserved","Personal macro text changed")
end

local function assertDefaultHealRebuilt(k,oldName,newBody,slots,bindings)
 local first=k.NativeBars:ReadSlot(slots[1])
 assert(first and first.kind=="macro" and first.name~=oldName and first.body==newBody,"Default heal retained the obsolete body or changed its rank")
 assert(not first.body:find("Rank 4",1,true),"Reapply promoted the saved downrank")
 for _,at in ipairs(slots) do
  local content=k.NativeBars:ReadSlot(at)
  assert(content and content.name==first.name and content.body==newBody,"Form-linked heal was not refreshed at slot "..at)
  assert(k.db.currentProfile.snapshot.native.actions[at].body==newBody,"Profile retained stale targeting at slot "..at)
 end
 assert(k.db.ownedMacros[first.name]==newBody,"Refreshed macro lost ownership")
 sameKeysExceptHelper(k,bindings,first.name)
end

function Tests.current_profile_default_heal_sync_reapply_adds_self_fallback_with_legacy_setting_disabled()
 local k,name,oldBody,newBody,slots,bindings=legacyDefaultHeal(nil)
 runProfile(k,"SyncCurrentProfile")
 assert(#Mock.writes==0,"Sync wrote live controls")
 assert(k.db.currentProfile.appliedPlan.settings.selfFallback==false)
 assert(k.db.currentProfile.snapshot.native.actions[slots[1]].body==oldBody,"Sync applied the repair prematurely")
 runProfile(k,"ReapplyCurrentProfile")
 assertDefaultHealRebuilt(k,name,newBody,slots,bindings)
end

function Tests.current_profile_explicit_default_heal_reapply_preserves_saved_rank_and_routes()
 local k,name,_,newBody,slots,bindings=legacyDefaultHeal("default")
 runProfile(k,"SyncCurrentProfile"); runProfile(k,"ReapplyCurrentProfile")
 assertDefaultHealRebuilt(k,name,newBody,slots,bindings)
end

function Tests.current_profile_default_heal_reapply_preserves_personal_edits_and_hash_name_collision()
 local k,name,_,newBody,slots,bindings=legacyDefaultHeal(nil)
 runProfile(k,"SyncCurrentProfile")
 local edited="/say my edited old helper"
 EditMacro(GetMacroIndexByName(name),name,2090,edited)
 local collisionName=k.Macros:Name(newBody); local collisionBody="/say my same-named personal macro"
 CreateMacro(collisionName,1,collisionBody,true)
 runProfile(k,"ReapplyCurrentProfile")
 assertDefaultHealRebuilt(k,name,newBody,slots,bindings)
 assert(k.NativeBars:ReadSlot(slots[1]).name~=collisionName,"Reapply reused a personal macro collision")
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))==edited,"Reapply overwrote the edited old helper")
 assert(select(3,GetMacroInfo(GetMacroIndexByName(collisionName)))==collisionBody,"Reapply overwrote a personal macro with the generated name")
end

function Tests.current_profile_default_heal_sync_adopts_personal_edit_without_recreating_old_intent()
 local k,name,_,_,slots,bindings=legacyDefaultHeal("default")
 local personal="/cast [@player] Rejuvenation(Rank 3)"
 EditMacro(GetMacroIndexByName(name),name,2090,personal)
 local accountBefore,characterBefore=GetNumMacros()
 runProfile(k,"SyncCurrentProfile")
 assert(not k.db.currentProfile.ownedMacros[name],"Sync retained generated ownership of the edited helper")
 runProfile(k,"ReapplyCurrentProfile")
 for _,at in ipairs(slots) do
  local content=k.NativeBars:ReadSlot(at)
  assert(content.name==name and content.body==personal,"Reapply replaced a synced personal macro")
 end
 sameKeysExceptHelper(k,bindings,name)
 local accountAfter,characterAfter=GetNumMacros()
 assert(accountBefore==accountAfter and characterBefore==characterAfter,"Reapply recreated stale preset macros after Sync adopted a personal edit")
end
