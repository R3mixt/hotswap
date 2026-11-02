local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local startingSpells={
 DRUID={{5176,"Wrath"},{5185,"Healing Touch"}},
 HUNTER={{2973,"Raptor Strike"}},
 MAGE={{133,"Fireball"}},
 PALADIN={{635,"Holy Light"},{21084,"Seal of Righteousness"}},
 PRIEST={{585,"Smite"},{2050,"Lesser Heal"}},
 ROGUE={{1752,"Sinister Strike"},{2098,"Eviscerate"}},
 SHAMAN={{403,"Lightning Bolt"},{331,"Healing Wave"}},
 WARLOCK={{686,"Shadow Bolt"},{687,"Demon Skin"}},
 WARRIOR={{78,"Heroic Strike"},{2457,"Battle Stance"}},
}
local function fillPersonalMacros(free)
 Mock.macros={}
 local occupied=150-free; local expected={}
 for index=1,occupied do
  local name=string.format("Personal %03d",index); local body="/say Saved personal macro "..index
  Mock.macros[index]={name=name,body=body,icon=1}; expected[name]=body
 end
 return expected
end
local function loadClass(class)
 Mock.build="1.15.9"; Mock.buildNumber="70576"; Mock.class=class
 Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
 for _,def in ipairs(TestAddon.Profiles:Get(class,"era")) do
  if def.spellIDs and def.spellIDs[1] and not def.combo then
   local id=def.spellIDs[1]; Mock.catalog[id]={id=id,name=def.name,icon=id}
  end
 end
 for _,spell in ipairs(startingSpells[class]) do Mock:Learn(spell[1],spell[2]) end
end
local function ready(class,free)
 loadClass(class)
 local personal=fillPersonalMacros(free)
 TestAddon:Init(); return TestAddon,personal
end
local function personalUnchanged(k,personal)
 for name,expected in pairs(personal) do
  local found,_,body=GetMacroInfo(GetMacroIndexByName(name))
  equal(found,name,"A personal macro was removed"); equal(body,expected,"A personal macro was modified")
  assert(not k.db.ownedMacros[name],"A personal macro became addon-owned")
 end
end

function Tests.macro_capacity_empty_account_bank_is_not_used_without_explicit_overflow_permission()
 local k=ready("WARRIOR",150)
 equal(k:GetSettings().allowAccountMacros,false)
 local plan=k:Preview(); equal(plan.macrosAvailable,30,"Default policy counted account capacity")
 equal(#plan.errors,0,table.concat(plan.errors,"; "))
 assert(plan.deferFutureMacros,"Empty account space bypassed future-macro compaction")
 local ok,why=k:Apply(); assert(ok,why)
 local account,character=GetNumMacros(); equal(account,0); assert(character>0 and character<=30)
 for name,body in pairs(k.db.ownedMacros) do
  local index=k.Macros:FindExact(name,body); assert(index and index>120,"Default setup created an account macro")
 end
end

function Tests.macro_capacity_fresh_character_databases_share_account_macros_without_accumulating_generated_macros()
 local k=ready("WARRIOR",150)
 local sharedName="Shared personal account macro"; local sharedBody="/say Preserve on every character"
 CreateMacro(sharedName,1,sharedBody,false)
 local ok,why=k:Apply(); assert(ok,why)
 local account,character=GetNumMacros(); equal(account,1); assert(character>0)
 local shared={}
 for index,macro in pairs(Mock.macros) do if index<=120 then shared[index]=k.Copy(macro) end end
 -- Simulate another character loading its own empty bank, bars and saved DB,
 -- while the account bank remains exactly the same game-owned shared bank.
 Mock.macros=shared; Mock.actions={}; Mock.cursor=nil
 Mock.bindings={BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION"}; Mock.bindingInventory=nil
 Mock.bindingSets={[1]=k.Copy(Mock.bindings),[2]=k.Copy(Mock.bindings)}; Mock.bindingSet=2
 KeybindOptimizerDB={}; k.db=nil; k.plan=nil; k.previewValid=false
 loadClass("MAGE"); k.API:InvalidateSpellbook(); k.API:InvalidateBindingCommands(); k:Init()
 equal(k:GetSettings().allowAccountMacros,false)
 ok,why=k:Apply(); assert(ok,why)
 account,character=GetNumMacros(); equal(account,1,"Generated macros accumulated in the shared account bank")
 assert(character>0 and character<=30)
 local found,_,body=GetMacroInfo(GetMacroIndexByName(sharedName)); equal(found,sharedName); equal(body,sharedBody)
 assert(not k.db.ownedMacros[sharedName])
 for name,expected in pairs(k.db.ownedMacros) do
  local index=k.Macros:FindExact(name,expected); assert(index and index>120,"Alt setup generated an account macro")
 end
end

function Tests.macro_capacity_explicit_account_overflow_fills_character_bank_first_and_preserves_both_banks()
 local k=ready("WARRIOR",150); local personal={}
 for index=1,2 do
  local name="Account personal "..index; local body="/say Account "..index
  Mock.macros[index]={name=name,body=body,icon=1}; personal[name]=body
 end
 for index=121,149 do
  local name="Character personal "..index; local body="/say Character "..index
  Mock.macros[index]={name=name,body=body,icon=1}; personal[name]=body
 end
 k:GetSettings().allowAccountMacros=true
 local plan=k:Preview(); equal(plan.macrosAvailable,119); equal(#plan.errors,0,table.concat(plan.errors,"; "))
 local create=CreateMacro; local destination={}
 CreateMacro=function(name,icon,body,perCharacter)
  destination[#destination+1]=perCharacter and "character" or "account"
  return create(name,icon,body,perCharacter)
 end
 local ok,why=k:Apply(); assert(ok,why)
 assert(#destination>1,"Fixture did not exhaust the character bank")
 equal(destination[1],"character","Account overflow was used before the last character slot")
 for index=2,#destination do equal(destination[index],"account") end
 local account,character=GetNumMacros(); equal(character,30); assert(account>2)
 personalUnchanged(k,personal)
 local payload=k:Export(k.db.activePreset); assert(payload)
 Mock:ResetWrites(); ok,why=k:Import(payload); assert(ok,why)
 equal(k:GetSettings().allowAccountMacros,true); equal(#Mock.writes,0)
end

function Tests.macro_capacity_existing_exact_owned_account_macro_is_reused_without_new_account_creation()
 local k=ready("WARRIOR",150); equal(k:GetSettings().allowAccountMacros,false)
 local body="#showtooltip 13\n/use 13"; local name=k.Macros:Name(body)
 local original=CreateMacro(name,1,body,false); assert(original<=120)
 k.db.ownedMacros[name]=body
 local create=CreateMacro; local created=0
 CreateMacro=function(macroName,icon,text,perCharacter)
  assert(perCharacter,"Default policy created a new account macro while reusing a legacy owned macro")
  created=created+1; return create(macroName,icon,text,perCharacter)
 end
 local ok,why=k:Apply(); assert(ok,why); assert(created>0)
 local account=GetNumMacros(); equal(account,1)
 local index=k.Macros:FindExact(name,body); assert(index and index<=120)
 equal(k.db.ownedMacros[name],body)
 local trinket
 for _,a in ipairs(k.db.appliedPlan.actions) do if a.id=="item.trinket13" then trinket=a; break end end
 assert(trinket); equal(trinket.macroName,name,"Exact owned account identity was needlessly duplicated")
 equal(GetActionInfo(trinket.nativeSlot),"macro"); equal(select(2,GetActionInfo(trinket.nativeSlot)),index)
 for owned,expected in pairs(k.db.ownedMacros) do if owned~=name then
  assert(k.Macros:FindExact(owned,expected)>120,"Another account macro was generated")
 end end
end

function Tests.macro_capacity_matching_unowned_account_macro_is_not_adopted_edited_or_deleted()
 local k=ready("WARRIOR",150); equal(k:GetSettings().allowAccountMacros,false)
 local body="#showtooltip 13\n/use 13"; local name=k.Macros:Name(body)
 local original=CreateMacro(name,1,body,false); assert(original<=120)
 assert(not k.db.ownedMacros[name],"Fixture incorrectly owned another character's account macro")
 local create,edit,delete=CreateMacro,EditMacro,DeleteMacro
 CreateMacro=function(macroName,icon,text,perCharacter)
  assert(perCharacter,"New character generated an account macro")
  return create(macroName,icon,text,perCharacter)
 end
 local function protect(index)
  if type(index)=="string" then index=GetMacroIndexByName(index) end
  assert(index~=GetMacroIndexByName(name),"Another character's matching account macro was edited or deleted")
 end
 EditMacro=function(index,...) protect(index); return edit(index,...) end
 DeleteMacro=function(index) protect(index); return delete(index) end
 local ok,why=k:Apply(); assert(ok,why)
 personalUnchanged(k,{[name]=body})
 local trinket
 for _,a in ipairs(k.db.appliedPlan.actions) do if a.id=="item.trinket13" then trinket=a; break end end
 assert(trinket and trinket.macroName~=name,"An unowned matching account macro was adopted")
 equal(trinket.body,body); equal(k.db.ownedMacros[trinket.macroName],body)
 local copy=k.Macros:FindExact(trinket.macroName,body); assert(copy and copy>120)
 equal(GetNumMacros(),1)
 ok,why=k:Restore(); assert(ok,why)
 personalUnchanged(k,{[name]=body})
 equal(GetMacroIndexByName(trinket.macroName),0,"Original restore left the generated character copy")
 local account,character=GetNumMacros(); equal(account,1); equal(character,0)
end

local function futureReservations(plan)
 local count=0
 for _,a in ipairs(plan.actions) do if not a.kind and not a.builtin and not a.known then
  count=count+1
  assert(a.key,"Macro pressure removed the future key for "..a.id)
  assert(a.nativeSlot or a.nativeOverflow,"Macro pressure removed the future native position for "..a.id)
  assert(plan.nativeLayout.keys[a.key],"Future key was left with no reserved native command: "..a.id)
 end end
 assert(count>0,"Fixture did not include future spell reservations")
end

function Tests.macro_capacity_low_level_warrior_optimizes_with_120_personal_macros_and_30_free_slots()
 local k,personal=ready("WARRIOR",30)
 local account,character=GetNumMacros(); equal(account,120); equal(character,0)
 local plan=k:Preview(); equal(plan.macrosAvailable,30,"Client macro capacity was counted incorrectly")
 equal(#plan.errors,0,table.concat(plan.errors,"; "))
 assert(plan.macrosNeeded<=30,"Future placeholders still exceed the character bank")
 assert(plan.deferFutureMacros and plan.capacityDeferredCount>0,"Macro pressure did not record deferred future reservations")
 equal(k:GetSettings().hideUnavailableSpells,false); equal(k:GetSettings().adaptTalents,false)
 assert(not k:GetSettings().deferFutureMacros,"Capacity fallback leaked into the preset's preferences")
 futureReservations(plan)
 local ok,why=k.Presets:Optimize(); assert(ok,why)
 assert(k.db.enabled and k.db.appliedPlan)
 futureReservations(k.db.appliedPlan); personalUnchanged(k,personal)
 local usedAccount,usedCharacter=GetNumMacros(); equal(usedAccount,120); assert(usedCharacter<=30)
 equal(GetBindingAction("1"),"ACTIONBUTTON1")
 equal(GetActionInfo(1),"spell"); equal(select(2,GetActionInfo(1)),78,"Known Heroic Strike was not installed")
end

for _,class in ipairs({"DRUID","HUNTER","MAGE","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK"}) do
 local fixtureClass=class
 Tests["macro_capacity_"..class:lower().."_fits_30_free_slots_without_touching_personal_macros"]=function()
  local k,personal=ready(fixtureClass,30)
  local plan=k:Preview(); equal(#plan.errors,0,fixtureClass..": "..table.concat(plan.errors,"; "))
  assert(plan.macrosNeeded<=plan.macrosAvailable and plan.macrosAvailable==30)
  futureReservations(plan)
  local ok,why=k:Apply(); assert(ok,why)
  futureReservations(k.db.appliedPlan); personalUnchanged(k,personal)
  local account,character=GetNumMacros(); equal(account,120); assert(character<=30)
 end
end

function Tests.macro_capacity_required_learned_macros_still_fail_safely_when_space_is_insufficient()
 local k,personal=ready("DRUID",1); Mock:Learn(774,"Rejuvenation")
 local plan=k:Preview(); equal(plan.macrosAvailable,1)
 assert(#plan.errors>0 and plan.macrosNeeded>1,"Executable macros were silently discarded to fit capacity")
 local rejuvenation
 for _,a in ipairs(plan.actions) do if a.id=="druid.rejuvenation" then rejuvenation=a; break end end
 assert(rejuvenation and rejuvenation.known and not rejuvenation.nativeHidden)
 assert(rejuvenation.body and rejuvenation.body:find("/cast",1,true),"A learned heal became inert under macro pressure")
 Mock:ResetWrites(); local ok,why=k:Apply(); assert(not ok and why:lower():find("macro",1,true),tostring(why))
 equal(#Mock.writes,0); equal(#k.Engine:ListBackups(),0)
 personalUnchanged(k,personal)
end

function Tests.macro_capacity_deferred_future_spells_reveal_when_learned_without_rebinding_or_draft_changes()
 local k,personal=ready("WARRIOR",30); Mock.async=true
 equal(k:Apply(),"pending"); local ok,why=Mock:Drain(); assert(ok,why)
 local plan=k.db.appliedPlan; assert(plan.deferFutureMacros)
 local future
 for _,a in ipairs(plan.actions) do if a.id=="warrior.rend" then future=a; break end end
 assert(future and not future.known and future.nativeDeferred and future.nativeHidden)
 assert(not future.body and not future.macroName,"Deferred native spell still used a macro slot")
 local key,slot=future.key,future.nativeSlot; equal(GetActionInfo(slot),nil)
 local bindings=k.Copy(Mock.bindings); local originalCommand=GetBindingAction(key)
 k:GetSettings().bindingOverrides[future.id]="CTRL-F24"
 Mock.combat=true; Mock:ResetWrites(); Mock:Learn(772,"Rend"); Mock:Fire("SPELLS_CHANGED")
 equal(#Mock.writes,0,"Deferred spell learning wrote protected state in combat")
 Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
 assert(k.Engine.busy,"Macro-pressure plan did not queue deferred spell activation")
 ok,why=Mock:Drain(); assert(ok,why)
 assert(future.known and not future.nativeDeferred and not future.nativeHidden)
 equal(future.key,key); equal(future.nativeSlot,slot); equal(GetBindingAction(key),originalCommand)
 local placed=0
 for _,entry in ipairs(k.db.appliedPlan.nativeLayout.placements) do if entry.actionID==future.id then
  placed=placed+1; equal(GetActionInfo(entry.slot),"spell"); equal(select(2,GetActionInfo(entry.slot)),772)
 end end
 equal(placed,4,"Learned Warrior spell did not update all native stance copies")
 for binding,command in pairs(bindings) do equal(Mock.bindings[binding],command,"Deferred activation changed "..binding) end
 for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Deferred activation rewrote the binding map") end
 equal(k:GetSettings().bindingOverrides[future.id],"CTRL-F24","Deferred activation discarded the staged key")
 equal(k:GetSettings().hideUnavailableSpells,false); equal(k:GetSettings().adaptTalents,false)
 personalUnchanged(k,personal)
end
