local function eq(a,b,message) assert(a==b,(message or "value")..": "..tostring(a).." ~= "..tostring(b)) end
function Tests.v1_default_bindings_are_character_only_backed_up_and_undoable()
 local k=TestAddon; k:Init(); Mock.async=true
 Mock.bindingSet=2; Mock.bindings.F="ASSISTTARGET"; Mock.bindingSets[1]={F="TARGETSELF"}; Mock.bindingSets[2]=k.Copy(Mock.bindings)
 Mock.bindingSets[0]={W="MOVEFORWARD",SPACE="JUMP",BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION"}
 Mock.actions[1]={"spell",5176}; local before=k.Copy(Mock.bindings)
 k.db.recoveryRequired="stale recovery"; k.recoveryQuarantined=true
 eq(k.Engine:RestoreDefaults(),"pending"); local ok,why=Mock:Drain(); assert(ok,why)
 assert(not k.db.recoveryRequired and not k.recoveryQuarantined)
 eq(GetCurrentBindingSet(),2); eq(GetBindingAction("F"),""); eq(GetBindingAction("W"),"MOVEFORWARD")
 eq(Mock.bindingSets[1].F,"TARGETSELF"); eq(select(2,GetActionInfo(1)),5176)
 eq(k.db.enabled,false); assert(not k.db.currentLayout)
 local backups=k.Engine:ListBackups(); eq(#backups,1)
 eq(k.Engine:RestoreBackup(backups[1].id),"pending"); ok,why=Mock:Drain(); assert(ok,why)
 eq(GetBindingAction("F"),before.F); eq(Mock.bindingSets[1].F,"TARGETSELF")
end
function Tests.v1_default_bindings_reject_combat_and_roll_back_save_failure()
 local k=TestAddon; k:Init(); Mock.async=true
 Mock.combat=true; Mock:ResetWrites(); eq(k.Engine:RestoreDefaults(),false); eq(#Mock.writes,0)
 Mock.combat=false; local before=k.Copy(Mock.bindings); local save=SaveBindings; local failed=false
 SaveBindings=function(set) if not failed then failed=true; return false end; return save(set) end
 eq(k.Engine:RestoreDefaults(),"pending"); local ok,why=Mock:Drain(); eq(ok,false); assert(why:find("rolled back",1,true),why)
 for key,command in pairs(before) do eq(GetBindingAction(key),command,key) end
end
function Tests.v1_bar_addon_current_slots_follow_live_action_attributes()
 local k=TestAddon; k:Init()
 for _,name in ipairs({"BT4Button7","DominosActionButton7"}) do
  local frame=CreateFrame("Button",name,UIParent); frame:SetAttribute("type","action"); frame:SetAttribute("action",73)
  Mock.actions[73]={"spell",5176}
  for _,mouse in ipairs({"LeftButton","HOTKEY","Keybind"}) do
   local command="CLICK "..name..":"..mouse
   local action=k.CurrentBindings:Describe(command,"F",1,"Main")
   eq(action.liveSlot,73); eq(action.spellID,5176); eq(action.liveCommand,command)
  end
  frame:SetAttribute("type","macro"); eq(k.CurrentBindings:ActionSlot("CLICK "..name..":LeftButton",1,"Main"),nil)
 end
 eq(k.CurrentBindings:ActionSlot("CLICK UnknownButton7:LeftButton",1,"Main"),nil)
end
function Tests.v1_future_spell_reservations_cost_no_macros_even_with_empty_banks()
 local k=TestAddon; Mock.class="WARRIOR"; Mock.spells={}; Mock.forms={}; Mock:Learn(78,"Heroic Strike"); k:Init()
 local plan=k:Preview(); assert(plan.deferFutureMacros)
 for _,a in ipairs(plan.actions) do if not a.known and not a.kind and not a.builtin and a.nativeSlot then
  eq(a.body,nil,a.id); eq(a.nativeMacro,nil,a.id); eq(k.NativeBars:ContentFor(a),false,a.id)
 end end
end
function Tests.v1_legacy_account_overflow_setting_cannot_create_account_macros()
 local k=TestAddon; k:Init(); Mock.macros={}; k:GetSettings().allowAccountMacros=true
 for i=121,150 do Mock.macros[i]={name="Personal"..i,body="/say personal",icon=1} end
 local action={known=true,body="/stopcasting",label="Stop"}; local plan={actions={action},settings={allowAccountMacros=true}}
 local needed,available=k.Macros:Budget(plan); eq(needed,1); eq(available,0)
 local ok=pcall(k.Engine.CreateMacros,k.Engine,plan,{})
 eq(ok,false); eq(GetNumMacros(),0)
end

-- Stress all catalog families at once, including talents that cannot normally
-- coexist. Unlike behavioral fixtures this deliberately uses the real 30-slot
-- character bank and the Era capability registry.
for _,class in ipairs({"DRUID","MAGE","WARRIOR","ROGUE","HUNTER","PRIEST","PALADIN","SHAMAN","WARLOCK"}) do
 local fixtureClass=class
 Tests["v1_full_era_"..class:lower().."_default_fits_real_character_macro_bank"]=function()
  local k=TestAddon; Mock.build="1.15.9"; Mock.class=fixtureClass; Mock.spells={}; Mock.petSpells={}; Mock.macros={}
  if fixtureClass~="DRUID" then Mock.forms={} end
  k:Init(); eq(k:GetSettings().cancelForUtility,false)
  local seen={}; local id=900000
  for _,def in ipairs(k.Profiles:Get(fixtureClass,"era")) do
   if not seen[def.name] and not def.combo then
    id=id+1; Mock:Learn((def.spellIDs and def.spellIDs[1]) or id,def.name); seen[def.name]=true
   end
  end
  local plan=k:Preview()
  eq(plan.macrosAvailable,30); eq(#plan.errors,0,table.concat(plan.errors,"; "))
  assert(plan.macrosNeeded<=30); eq(plan.coverage.bound,plan.coverage.total)
  local ok,why=k:Apply(); assert(ok,why)
  local account,character=GetNumMacros(); eq(account,0); assert(character<=30)
  for _,a in ipairs(k.db.appliedPlan.actions) do
   if a.key and a.known and not a.kind and not a.builtin and a.nativeSlot then assert(GetActionInfo(a.nativeSlot),a.id.." was not installed") end
  end
 end
end

function Tests.v1_learned_heal_rank_refreshes_metadata_without_replacing_its_macro()
 local k=TestAddon; Mock.class="PRIEST"; Mock.spells={}; Mock.forms={}; Mock:Learn(2050,"Lesser Heal","Rank 1"); k:Init()
 assert(k:Apply()); local action
 for _,a in ipairs(k.db.appliedPlan.actions) do if a.spellID==2050 then action=a; break end end
 assert(action and action.body); local macro,key=action.macroName,action.key; local account,character=GetNumMacros()
 Mock:Learn(2052,"Lesser Heal","Rank 2"); k.API:InvalidateSpellbook()
 local ok,why=k.Engine:RepairLearnedActions(k.db.appliedPlan); assert(ok,why)
 eq(action.spellID,2052); eq(action.macroName,macro); eq(action.key,key)
 eq(GetNumMacros(),account); eq(select(2,GetNumMacros()),character)
end
