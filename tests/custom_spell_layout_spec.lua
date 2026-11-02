-- Full-catalog transaction fixtures explicitly use synthetic character capacity; capacity tests retain 30.
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function find(plan,id)
 for _,a in ipairs(plan.actions) do if a.id==id then return a end end
 error("Missing action "..id)
end
local function ready()
 Mock.build="1.60.1"; Mock.class="PRIEST"; Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
 Mock:Learn(585,"Smite")
 Mock.catalog[15487]={id=15487,name="Silence",icon=136164}
 local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros()
 local ok,id,why=k.Library:Stage({descriptor={kind="spell",sourceID="priest.silence"}})
 assert(ok,why); k:GetSettings().bindingOverrides[id]="CTRL-F22"
 ok,why=k.Library:SetTargetMode(id,"mouseover"); assert(ok,why)
 return k,id
end
local function checked(k)
 local plan=k:Preview(); equal(#plan.errors,0,table.concat(plan.errors,"; ")); return plan
end
local function finish(k)
 if k.Engine.busy then local ok,why=Mock:Drain(); assert(ok,why) end
end
local function installedBody(a)
 local kind,index=GetActionInfo(a.nativeSlot); equal(kind,"macro")
 local name,_,body=GetMacroInfo(index); equal(name,a.macroName); equal(body,a.body)
 return body
end

function Tests.custom_spell_layout_duplicated_family_uses_utility_slot_without_stealing_main_position()
 local k,id=ready(); local plan=checked(k)
 local base,focus,custom=find(plan,"priest.silence"),find(plan,"priest.silence.focus"),find(plan,id)
 equal(base.key,"R"); equal(base.barSlot,11); equal(base.nativeSlot,11)
 equal(focus.key,"SHIFT-R"); equal(focus.barSlot,12); equal(focus.nativeSlot,12)
 equal(custom.key,"CTRL-F22"); equal(custom.barSlot,nil)
 assert(custom.nativeSlot and custom.nativeSlot~=11 and custom.nativeSlot~=12)
 assert(custom.nativeCommand:match("^MULTIACTIONBAR"),"Custom family inherited a main-bar command")
 local ok,why=k:Apply(); assert(ok,why)
 equal(GetBindingAction("R"),"ACTIONBUTTON11"); equal(GetBindingAction("SHIFT-R"),"ACTIONBUTTON12")
 equal(GetBindingAction("CTRL-F22"),custom.nativeCommand)
end

function Tests.custom_spell_layout_learning_splits_shared_silence_placeholder_by_target_without_moving_keys()
 local k,id=ready(); checked(k); Mock.async=true
 equal(k:Apply(),"pending"); finish(k)
 local ids={"priest.silence","priest.silence.focus",id}; local before={}; local placeholder
 for _,actionID in ipairs(ids) do
  local a=find(k.db.appliedPlan,actionID)
  before[actionID]={key=a.key,slot=a.nativeSlot,command=a.nativeCommand}
  assert(not a.known and a.talent and not a.body and not GetActionInfo(a.nativeSlot))
  placeholder=placeholder or a.macroName; equal(a.macroName,placeholder,"Fixture did not share its inert placeholder")
 end
 local bindings=k.Copy(Mock.bindings)
 Mock:Learn(15487,"Silence"); Mock:ResetWrites(); Mock:Fire("PLAYER_TALENT_UPDATE"); finish(k)
 local macroNames={}
 for _,actionID in ipairs(ids) do
  local a=find(k.db.appliedPlan,actionID); local old=before[actionID]
  assert(a.known); equal(a.key,old.key); equal(a.nativeSlot,old.slot); equal(a.nativeCommand,old.command)
  if a.body then
   assert(not macroNames[a.macroName],"Different target variants retained a shared executable macro")
   macroNames[a.macroName]=true; installedBody(a)
  else equal(GetActionInfo(a.nativeSlot),"spell"); equal(select(2,GetActionInfo(a.nativeSlot)),15487) end
 end
 local base,focus,custom=find(k.db.appliedPlan,ids[1]),find(k.db.appliedPlan,ids[2]),find(k.db.appliedPlan,id)
 assert(not base.body and base.spellID==15487,"Base key did not activate native Silence")
 assert(focus.body:find("/cast [@focus,harm,nodead] Silence",1,true),"Focus key lost its focus condition")
 assert(custom.body:find("/cast [@mouseover,harm,nodead][harm,nodead] Silence",1,true),"Custom key lost mouseover targeting")
 for key,command in pairs(bindings) do equal(Mock.bindings[key],command,"Learning changed "..key) end
 for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Learning the cloned spell rewrote gameplay bindings") end
 for i=#Mock.spells,1,-1 do if Mock.spells[i].id==15487 then table.remove(Mock.spells,i) end end
 Mock:Fire("PLAYER_TALENT_UPDATE"); finish(k)
 for _,actionID in ipairs(ids) do
  local a=find(k.db.appliedPlan,actionID)
  assert(not a.known and not a.body and not GetActionInfo(a.nativeSlot),"Unlearning left an executable Silence variant")
  equal(a.key,before[actionID].key); equal(a.nativeSlot,before[actionID].slot)
 end
end
