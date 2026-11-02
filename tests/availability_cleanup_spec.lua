local function make(body)
 local k=TestAddon; local name=k.Macros:Name(body)
 CreateMacro(name,1,body,true); k.db.ownedMacros[name]=body
 return name
end
function Tests.availability_cleanup_runs_one_macro_per_idle_out_of_combat_frame()
 local k=TestAddon; k:Init()
 local a,b=make("#showtooltip\n/cast Old One"),make("#showtooltip\n/cast Old Two")
 k.AvailabilityEngine:QueueCleanup({[a]=k.db.ownedMacros[a],[b]=k.db.ownedMacros[b]})
 Mock.combat=true; Mock:Advance(0.016); assert(GetMacroIndexByName(a)>0 and GetMacroIndexByName(b)>0)
 Mock.combat=false; k.Engine.busy=true; Mock:Advance(0.016); assert(GetMacroIndexByName(a)>0 and GetMacroIndexByName(b)>0)
 k.Engine.busy=false; Mock:Advance(0.016)
 local remaining=(GetMacroIndexByName(a)>0 and 1 or 0)+(GetMacroIndexByName(b)>0 and 1 or 0)
 assert(remaining==1,"Cleanup deleted more than one macro in a frame")
 Mock:Advance(0.016); assert(GetMacroIndexByName(a)==0 and GetMacroIndexByName(b)==0)
 assert(not k.db.ownedMacros[a] and not k.db.ownedMacros[b])
end
function Tests.availability_cleanup_preserves_personal_edits_hidden_slots_and_shortcut_references()
 local k=TestAddon; k:Init()
 local edited,hidden,bound=make("#showtooltip\n/cast Edited"),make("#showtooltip\n/cast Hidden"),make("#showtooltip\n/cast Bound")
 local candidates={[edited]=k.db.ownedMacros[edited],[hidden]=k.db.ownedMacros[hidden],[bound]=k.db.ownedMacros[bound]}
 EditMacro(edited,nil,nil,"/say personal edit")
 Mock.actions[121]={"macro",GetMacroIndexByName(hidden)}
 assert(SetBinding("CTRL-F24","MACRO "..bound))
 k.AvailabilityEngine:QueueCleanup(candidates)
 Mock:Advance(0.05,3)
 for _,name in ipairs({edited,hidden,bound}) do assert(GetMacroIndexByName(name)>0,"Cleanup deleted a referenced or edited macro") end
 local _,_,body=GetMacroInfo(GetMacroIndexByName(edited)); assert(body=="/say personal edit")
 assert(not k.Engine.busy,"Best-effort cleanup entered the transaction runner")
end
function Tests.availability_cleanup_failure_keeps_macro_without_rolling_back_applied_state()
 local k=TestAddon; k:Init(); local name=make("#showtooltip\n/cast Retained")
 local plan={marker="applied"}; k.db.appliedPlan=plan; k.db.enabled=true
 DeleteMacro=function() error("temporary deletion failure") end
 k.AvailabilityEngine:QueueCleanup({[name]=k.db.ownedMacros[name]}); Mock:Advance(0.016)
 assert(GetMacroIndexByName(name)>0 and k.db.ownedMacros[name])
 assert(k.db.appliedPlan==plan and k.db.enabled and not k.Engine.busy)
 assert(not next(k.AvailabilityEngine.pendingCleanup),"Cleanup retried indefinitely")
end
