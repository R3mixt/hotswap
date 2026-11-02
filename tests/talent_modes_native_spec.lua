-- Full-catalog transaction fixtures explicitly use synthetic character capacity; capacity tests retain 30.
local function eq(a,b,message) assert(a==b,(message or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function find(plan,id) for _,a in ipairs(plan.actions) do if a.id==id then return a end end; error("Missing "..id) end
local function inert(body)
 if body==nil then return end
 assert(body:find("#showtooltip",1,true),"Missing talent tooltip")
 for _,command in ipairs({"/cast","/use","/cancelform"}) do assert(not body:find(command,1,true),"Unlearned talent executes "..command) end
end
local function ready()
 Mock.build="1.15.9"; Mock.class="DRUID"; Mock.spells={}; Mock.forms={}
 Mock:Learn(5176,"Wrath"); Mock:Learn(5185,"Healing Touch"); Mock:Learn(774,"Rejuvenation")
 Mock.catalog[18562]={id=18562,name="Swiftmend",icon=134914}
 Mock.catalog[24858]={id=24858,name="Moonkin Form",icon=136036}
 TestAddon:Init(); Mock:AllowFullCatalogMacros(); return TestAddon
end
local function changed(event)
 Mock:Fire(event or "SPELLS_CHANGED")
 if TestAddon.Engine.busy then local ok,why=Mock:Drain(); assert(ok,why) end
end
function Tests.talent_modes_independent_unlearned_macros_are_strictly_inert()
 local k=ready(); k:GetSettings().bindingOverrides["druid.swiftmend"]="CTRL-F20"
 assert(k:Apply())
 local a=find(k.db.appliedPlan,"druid.swiftmend")
 eq(a.key,"CTRL-F20"); assert(a.talent and not a.known and a.nativeHidden)
 inert(a.body); eq(GetActionInfo(a.nativeSlot),nil)
 local form=find(k.db.appliedPlan,"druid.form_moonkin"); inert(form.body)
 assert(not k:GetSettings().hideUnavailableSpells and not k:GetSettings().adaptTalents)
end
function Tests.talent_modes_independent_custom_key_activates_and_deactivates_in_place()
 local k=ready(); k:GetSettings().bindingOverrides["druid.swiftmend"]="CTRL-F20"
 assert(k:Apply()); local a=find(k.db.appliedPlan,"druid.swiftmend")
 local key,slot,name,command=a.key,a.nativeSlot,a.macroName,GetBindingAction(a.key)
 Mock:ResetWrites(); Mock:Learn(18562,"Swiftmend"); changed()
 assert(a.known and a.body:find("/cast",1,true)); eq(a.availabilityState,"ready")
 eq(a.key,key); eq(a.nativeSlot,slot); eq(GetBindingAction(key),command)
 for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Independent talent moved/recreated a control") end
 for index=#Mock.spells,1,-1 do if Mock.spells[index].id==18562 then table.remove(Mock.spells,index) end end
 Mock:ResetWrites(); changed("PLAYER_TALENT_UPDATE")
 assert(not a.known); eq(a.availabilityState,"talent"); inert(a.body)
 eq(a.key,key); eq(a.nativeSlot,slot); eq(GetBindingAction(key),command)
 for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Removing a talent moved a control") end
end
function Tests.talent_modes_known_raw_talent_from_older_plan_upgrades_only_its_owned_slot()
 local k=ready(); Mock.class="WARRIOR"; Mock.spells={}; Mock.catalog={}; Mock:Learn(12294,"Mortal Strike")
 assert(k:Apply()); local a=find(k.db.appliedPlan,"warrior.mortal_strike")
 assert(a.known and not a.nativeMacro and not a.macroName,"Known simple talent should remain a native spell")
 local slot,key=a.nativeSlot,a.key
 -- Model a saved plan from before independent talents used owned macros.
 a.body=nil; a.nativeMacro=nil; a.macroName=nil; a.macroIndex=nil
 for _,entry in ipairs(k.db.appliedPlan.nativeLayout.placements) do if entry.actionID==a.id then Mock.actions[entry.slot]={"spell",12294} end end
 assert(not k.AvailabilityEngine:RequiresTalentPlacement(k.db.appliedPlan))
 Mock:ResetWrites(); local ok,why=k.Engine:RepairLearnedActions(k.db.appliedPlan); assert(ok,why)
 if k.Engine.busy then ok,why=Mock:Drain(); assert(ok,why) end
 eq(a.key,key); eq(a.nativeSlot,slot); assert(not a.macroName and not a.body)
 eq(GetActionInfo(slot),"spell"); assert(not k.AvailabilityEngine:RequiresTalentPlacement(k.db.appliedPlan))
end
function Tests.talent_modes_catalog_talent_powershift_placeholder_cannot_cancel_a_form()
 local k=ready()
 local a={id="custom.moonkin",librarySourceID="druid.form_moonkin",known=false,name="Moonkin Form",displayName="Moonkin Form",label="Moonkin Form",targeting="form",formType="moonkin",powerShift=true}
 k.Availability:Annotate(a,"DRUID","era"); assert(a.talent)
 local ok,why=k.NativeBars:MakeMacro(a,k:GetSettings(),false); assert(ok,why); inert(a.body)
end
function Tests.talent_modes_unlearned_base_and_focus_activate_independently_without_moving_keys()
 local k=ready(); Mock.build="1.60.1"; Mock.class="PRIEST"; Mock.spells={}; Mock.catalog={}
 Mock.catalog[15487]={id=15487,name="Silence",icon=136164}
 k.API:InvalidateBindingCommands()
 assert(k:Apply())
 local a=find(k.db.appliedPlan,"priest.silence")
 local b=find(k.db.appliedPlan,"priest.silence.focus")
 inert(a.body); inert(b.body); eq(a.macroName,b.macroName,"Equivalent inert reservations should share capacity")
 local original=k.Copy(Mock.bindings); local slots={a.nativeSlot,b.nativeSlot}; Mock:ResetWrites()
 Mock:Learn(15487,"Silence"); changed()
 assert(a.known and b.known)
 assert(not a.body and a.spellID==15487 and b.body:find("@focus",1,true))
 assert(a.macroName~=b.macroName,"Divergent targeting remained on a shared macro")
 eq(a.nativeSlot,slots[1]); eq(b.nativeSlot,slots[2])
 for key,command in pairs(original) do eq(Mock.bindings[key],command,"Learning variants moved a key") end
 for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Learning variants rebound native controls") end
end
function Tests.talent_modes_learning_family_does_not_activate_an_unlearned_exact_rank_alias()
 local k=ready(); Mock.class="MAGE"; Mock.spells={}; Mock.catalog={}
 Mock.catalog[11366]={id=11366,name="Pyroblast",rank="Rank 1",icon=135808}
 k:GetSettings().customActions["custom.pyroblast_rank_one"]={kind="spell",sourceID="mage.pyroblast",spellID=11366}
 k:GetSettings().bindingOverrides["custom.pyroblast_rank_one"]="CTRL-F22"
 assert(k:Apply())
 local family=find(k.db.appliedPlan,"mage.pyroblast")
 local rank=find(k.db.appliedPlan,"custom.pyroblast_rank_one")
 eq(family.macroName,rank.macroName); inert(family.body); inert(rank.body)
 local rankName=rank.macroName
 Mock:Learn(12505,"Pyroblast","Rank 2"); changed()
 assert(family.known and not family.body and family.spellID==12505); assert(not rank.known)
 inert(rank.body); eq(rank.macroName,rankName)
 eq(GetActionInfo(rank.nativeSlot),nil)
 eq(GetActionInfo(family.nativeSlot),"spell"); eq(GetActionInfo(rank.nativeSlot),nil)
end
