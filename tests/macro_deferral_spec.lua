local function eq(a,b,message) assert(a==b,(message or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function action(plan,id) for _,a in ipairs(plan.actions) do if a.id==id then return a end end; error("Missing action "..id) end
local function prepare(class)
 Mock.class=class; Mock.build="1.15.9"; Mock.spells={}; Mock.forms={}; Mock.catalog={}
 if class=="WARRIOR" then Mock:Learn(78,"Heroic Strike") else Mock:Learn(5176,"Wrath"); Mock:Learn(5185,"Healing Touch") end
 TestAddon:Init(); local plan=TestAddon:Preview(); plan.deferFutureMacros=true
 local layout,why=TestAddon.NativeBars:Prepare(plan); assert(layout,why)
 return TestAddon,plan
end
local function install(k,plan)
 local state,why=k.Engine:Apply(plan); eq(state,"pending",why)
 local ok,message=Mock:Drain(); assert(ok,message)
 return k.db.appliedPlan
end
local function fillMacros()
 local account,character=GetNumMacros()
 for index=account+1,120 do assert(CreateMacro("FullA"..index,1,"/say personal a "..index,false)) end
 for index=character+1,30 do assert(CreateMacro("FullC"..index,1,"/say personal c "..index,true)) end
end
function Tests.macro_deferral_keeps_native_reservations_and_does_not_change_visibility_preferences()
 local k,plan=prepare("WARRIOR")
 assert(plan.capacityDeferredCount>0 and not plan.settings.hideUnavailableSpells and not plan.settings.adaptTalents)
 local future=action(plan,"warrior.rend"); assert(future.nativeDeferred and future.nativeHidden and not future.body)
 eq(plan.nativeLayout.keys[future.key].command,future.nativeCommand)
 local installed=install(k,plan); future=action(installed,"warrior.rend")
 eq(GetActionInfo(future.nativeSlot),nil); eq(GetBindingAction(future.key),future.nativeCommand)
 assert(installed.deferFutureMacros and not k:GetSettings().hideUnavailableSpells)
 local count=0; for _,a in ipairs(installed.actions) do if a.nativeDeferred then count=count+1 end end
 eq(installed.capacityDeferredCount,count)
end
function Tests.macro_deferral_learns_direct_spell_with_zero_macro_space_and_defers_again_on_unlearn()
 local k,plan=prepare("WARRIOR"); plan=install(k,plan); fillMacros()
 local a=action(plan,"warrior.hamstring"); local key,slot=a.key,a.nativeSlot; local count=plan.capacityDeferredCount
 Mock:Learn(1715,"Hamstring"); k.API:InvalidateSpellbook(); Mock:ResetWrites()
 local ok,why=k.Engine:RepairLearnedActions(plan); assert(ok,why)
 if k.Engine.busy then ok,why=Mock:Drain(); assert(ok,why) end
 assert(a.known and not a.nativeDeferred and not a.nativeHidden and not a.body)
 eq(GetActionInfo(slot),"spell"); eq(select(2,GetActionInfo(slot)),1715); eq(a.key,key)
 eq(plan.capacityDeferredCount,count-1)
 for _,write in ipairs(Mock.writes) do assert(write[1]~="createmacro" and write[1]~="binding","Direct learned spell consumed macro space or rebound a key") end
 for index=#Mock.spells,1,-1 do if Mock.spells[index].id==1715 then table.remove(Mock.spells,index) end end
 k.API:InvalidateSpellbook(); ok,why=k.Engine:RepairLearnedActions(plan); assert(ok,why)
 if k.Engine.busy then ok,why=Mock:Drain(); assert(ok,why) end
 assert(not a.known and a.nativeDeferred and a.nativeHidden); eq(GetActionInfo(slot),nil)
 eq(a.key,key); eq(a.nativeSlot,slot); eq(plan.capacityDeferredCount,count)
 assert(not k:GetSettings().hideUnavailableSpells,"Capacity policy leaked into user visibility preference")
end
function Tests.macro_deferral_targeted_learning_refuses_full_capacity_without_writes_then_recovers()
 local k,plan=prepare("DRUID"); plan=install(k,plan); fillMacros()
 local a=action(plan,"druid.regrowth"); local slot=a.nativeSlot; assert(a.nativeDeferred)
 Mock:Learn(8936,"Regrowth"); k.API:InvalidateSpellbook(); Mock:ResetWrites()
 local ok,why=k.Engine:RepairLearnedActions(plan)
 eq(ok,false); assert(why:find("macro",1,true) and why:find("Free",1,true),tostring(why))
 eq(#Mock.writes,0,"Insufficient learned macro space mutated the game")
 assert(a.nativeDeferred and not a.known and k.db.enabled); eq(GetActionInfo(slot),nil)
 DeleteMacro(GetMacroIndexByName("FullC30")); Mock:ResetWrites()
 ok,why=k.Engine:RepairLearnedActions(plan); assert(ok,why)
 if k.Engine.busy then ok,why=Mock:Drain(); assert(ok,why) end
 assert(a.known and not a.nativeDeferred and a.body:find("@mouseover",1,true))
 eq(GetActionInfo(slot),"macro"); eq(a.nativeSlot,slot)
end
