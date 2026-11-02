local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function action(plan,id)
  for _,a in ipairs(plan.actions) do if a.id==id then return a end end
  error("Missing action "..id)
end
local function ready()
  Mock.build="1.15.9"; Mock.buildNumber="70576"; Mock.class="DRUID"
  Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
  Mock:Learn(5176,"Wrath"); Mock:Learn(5185,"Healing Touch"); Mock:Learn(774,"Rejuvenation")
  Mock.catalog[8921]={id=8921,name="Moonfire",icon=136096}
  Mock.catalog[2912]={id=2912,name="Starfire",icon=135753}
  Mock.catalog[16689]={id=16689,name="Nature's Grasp",icon=136063}
  TestAddon:Init(); Mock.async=true
  -- These scenarios test availability policy with room for visible future
  -- placeholders; character-only budget compaction has separate regressions.
  TestAddon:GetSettings().allowAccountMacros=true
  return TestAddon
end
local function finish()
  local ok,why=Mock:Drain(); assert(ok,why)
end
local function apply(k) equal(k:Apply(),"pending"); finish() end
local function removeSpell(id)
  for index=#Mock.spells,1,-1 do if Mock.spells[index].id==id then table.remove(Mock.spells,index) end end
end
local function changed(k,event)
  Mock:Fire(event or "SPELLS_CHANGED")
  if k.Engine.busy then finish() end
end
local function installedSpell(slot,id)
  local kind,actual=GetActionInfo(slot)
  equal(kind,"spell","Native learned action type"); equal(actual,id,"Native learned action ID")
end

function Tests.availability_engine_defaults_keep_future_reservations_visible()
  local k=ready()
  equal(k:GetSettings().hideUnavailableSpells,false); equal(k:GetSettings().adaptTalents,false)
  apply(k)
  local moonfire=action(k.db.appliedPlan,"druid.moonfire.caster")
  assert(not moonfire.known and moonfire.key and moonfire.nativeSlot)
  equal(GetActionInfo(moonfire.nativeSlot),"macro","Default future spell reservation disappeared")
end

function Tests.availability_engine_success_does_not_report_an_unapplied_draft()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  assert(not k.dirty)
  Mock:Learn(8921,"Moonfire"); changed(k)
  assert(not k.dirty and not k.needsRefresh,"Automatic reveal reported an unapplied draft")
end

function Tests.availability_engine_status_preserves_real_drafts_and_new_unbound_spells()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="CTRL-F24"
  Mock:Learn(8921,"Moonfire"); changed(k)
  assert(k.dirty and not k.needsRefresh,"Automatic refresh hid an edited draft")
  k:GetSettings().bindingOverrides["druid.rejuvenation"]=nil
  Mock:Learn(991188,"Uncatalogued ability"); changed(k)
  assert(k.dirty and k.needsRefresh,"An unbound new spell did not request review")
end

function Tests.availability_engine_hidden_spells_keep_logical_keys_and_slots_without_future_macros()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  local future=action(k.db.appliedPlan,"druid.moonfire.caster")
  assert(not future.known and future.nativeHidden,"Unlearned spell is not marked hidden")
  equal(future.key,"2"); assert(future.nativeSlot)
  equal(GetActionInfo(future.nativeSlot),nil,"Hidden spell still occupies its native slot")
  assert(not future.body and not future.macroName,"Hidden spell still consumes a future macro")
  equal(GetBindingAction(future.key),"ACTIONBUTTON2","Hidden spell lost its logical key reservation")
  installedSpell(action(k.db.appliedPlan,"druid.wrath.caster").nativeSlot,5176)
end

function Tests.availability_engine_learning_updates_installed_slots_without_applying_draft_edits()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  local before=action(k.db.appliedPlan,"druid.moonfire.caster"); local key,slot=before.key,before.nativeSlot
  local binds=k.Copy(Mock.bindings)
  k:GetSettings().hideUnavailableSpells=false
  k:GetSettings().bindingOverrides["druid.moonfire.caster"]="CTRL-F24"
  Mock:ResetWrites(); Mock:Learn(8921,"Moonfire"); changed(k)
  local learned=action(k.db.appliedPlan,"druid.moonfire.caster")
  assert(learned.known and not learned.nativeHidden)
  equal(learned.key,key); equal(learned.nativeSlot,slot); installedSpell(slot,8921)
  local stillFuture=action(k.db.appliedPlan,"druid.starfire.caster")
  assert(stillFuture.nativeHidden and not GetActionInfo(stillFuture.nativeSlot),"Learning applied the draft visibility preference")
  for binding,command in pairs(binds) do equal(Mock.bindings[binding],command,"Learned update moved "..binding) end
  for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Learned update reapplied key bindings") end
  equal(k:GetSettings().bindingOverrides["druid.moonfire.caster"],"CTRL-F24","Learned update discarded the staged rebind")
end

function Tests.availability_engine_unlearning_removes_only_the_owned_spell_and_retains_reservations()
  local k=ready(); Mock:Learn(8921,"Moonfire"); k:GetSettings().hideUnavailableSpells=true; apply(k)
  local before=action(k.db.appliedPlan,"druid.moonfire.caster"); local key,slot=before.key,before.nativeSlot
  installedSpell(slot,8921)
  removeSpell(8921); changed(k)
  local future=action(k.db.appliedPlan,"druid.moonfire.caster")
  assert(not future.known and future.nativeHidden)
  equal(future.key,key); equal(future.nativeSlot,slot); equal(GetActionInfo(slot),nil)
  equal(GetBindingAction(key),"ACTIONBUTTON2")
end

function Tests.availability_engine_talent_adaptation_is_independent_from_hiding_all_future_spells()
  local k=ready(); k:GetSettings().adaptTalents=true; apply(k)
  local talent=action(k.db.appliedPlan,"druid.natures_grasp")
  local ordinary=action(k.db.appliedPlan,"druid.moonfire.caster")
  assert(talent.talent and talent.nativeHidden and not GetActionInfo(talent.nativeSlot),"Unselected talent was not hidden")
  assert(not ordinary.nativeHidden and GetActionInfo(ordinary.nativeSlot),"Talent adaptation hid an ordinary future spell")
  local key,slot=talent.key,talent.nativeSlot
  Mock:Learn(16689,"Nature's Grasp"); changed(k,"PLAYER_TALENT_UPDATE")
  local learned=action(k.db.appliedPlan,"druid.natures_grasp")
  assert(learned.known and not learned.nativeHidden); equal(learned.key,key); equal(learned.nativeSlot,slot)
  assert(GetActionInfo(slot),"Selecting a talent left its reserved slot empty")
  removeSpell(16689); changed(k,"PLAYER_TALENT_UPDATE")
  local removed=action(k.db.appliedPlan,"druid.natures_grasp")
  assert(not removed.known and removed.nativeHidden); equal(GetActionInfo(slot),nil)
end

function Tests.availability_engine_respects_manual_edits_to_empty_and_occupied_reserved_slots()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  local future=action(k.db.appliedPlan,"druid.moonfire.caster")
  local learned=action(k.db.appliedPlan,"druid.wrath.caster")
  Mock.actions[future.nativeSlot]={"item",900001}; Mock.actions[learned.nativeSlot]={"item",900002}
  Mock:Learn(8921,"Moonfire"); removeSpell(5176); changed(k)
  equal(select(2,GetActionInfo(future.nativeSlot)),900001,"Learning overwrote an item placed in an empty reservation")
  equal(select(2,GetActionInfo(learned.nativeSlot)),900002,"Unlearning cleared a player's replacement action")
  removeSpell(8921); changed(k)
  equal(select(2,GetActionInfo(future.nativeSlot)),900001,"Later refresh reclaimed a manually edited slot")
end

function Tests.availability_engine_learned_refresh_waits_for_combat_and_bounds_each_frame()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  local future=action(k.db.appliedPlan,"druid.moonfire.caster"); local slot=future.nativeSlot
  Mock.combat=true; Mock:ResetWrites(); Mock:Learn(8921,"Moonfire"); Mock:Fire("SPELLS_CHANGED")
  equal(#Mock.writes,0,"Learning in combat wrote native actions"); equal(GetActionInfo(slot),nil)
  Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
  assert(k.Engine.busy,"Learned action placement did not enter a bounded worker")
  local frames=0
  while k.Engine.busy do
    Mock:ResetWrites(); Mock:Advance(0.016); frames=frames+1
    local mutations=0
    for _,write in ipairs(Mock.writes) do
      if write[1]=="action" or write[1]=="pickupaction" or write[1]=="createmacro" or write[1]=="editmacro" then mutations=mutations+1 end
      assert(write[1]~="binding","Visibility refresh rewrote the binding map")
    end
    assert(mutations<=6,"Visibility refresh burst protected mutations in one frame")
    assert(frames<2000,"Visibility refresh never completed")
  end
  assert(k.Engine.lastJob.ok,k.Engine.lastJob.message); installedSpell(slot,8921)
end

function Tests.availability_engine_failed_placement_restores_only_touched_slots_and_clears_cursor()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  local future=action(k.db.appliedPlan,"druid.moonfire.caster")
  Mock:Learn(8921,"Moonfire"); Mock:Learn(2912,"Starfire"); k.API:InvalidateSpellbook()
  local place=PlaceAction; local calls=0; local first
  PlaceAction=function(slot)
    calls=calls+1
    if calls==2 then error("injected availability placement failure") end
    if calls==1 then first=slot end
    return place(slot)
  end
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("injected availability placement failure",1,true) and why:find("rolled back",1,true),tostring(why))
  assert(first,"No owned slot was changed before the failure")
  equal(GetActionInfo(first),nil,"Rollback retained the first newly learned placement")
  equal(GetActionInfo(future.nativeSlot),nil); equal(GetCursorInfo(),nil,"Failed pickup left the cursor occupied")
  assert(not future.known and future.nativeHidden,"Failed refresh committed new availability metadata")
  installedSpell(action(k.db.appliedPlan,"druid.wrath.caster").nativeSlot,5176)
end

function Tests.availability_engine_rollback_preserves_slot_and_key_edits_made_after_a_write()
  local k=ready(); k:GetSettings().hideUnavailableSpells=true; apply(k)
  Mock:Learn(8921,"Moonfire"); Mock:Learn(2912,"Starfire"); k.API:InvalidateSpellbook()
  local place=PlaceAction; local calls=0; local first
  PlaceAction=function(slot)
    calls=calls+1
    if calls==2 then
      Mock.actions[first]={"item",900004}; assert(SetBinding("CTRL-F24","OPENCHAT"))
      error("injected concurrent personal edit")
    end
    if calls==1 then first=slot end
    return place(slot)
  end
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local ok,why=Mock:Drain(); assert(not ok and why:find("rolled back",1,true),tostring(why))
  equal(GetActionInfo(first),"item"); equal(select(2,GetActionInfo(first)),900004)
  equal(GetBindingAction("CTRL-F24"),"OPENCHAT","Rollback removed an unrelated new key binding")
  equal(GetCursorInfo(),nil)
end

local function overflowReady()
  Mock.build="1.15.9"; Mock.buildNumber="70576"; Mock.class="WARLOCK"
  Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
  _G.MultiBar5=nil; _G.MultiBar6=nil; _G.MultiBar7=nil
  Mock:Learn(686,"Shadow Bolt")
  local k=TestAddon
  for _,def in ipairs(k.Profiles:Get("WARLOCK","era")) do
    if not def.combo and def.spellIDs and def.spellIDs[1] then
      local id=def.spellIDs[1]; Mock.catalog[id]={id=id,name=def.name,icon=id}
    end
  end
  k:Init(); k:GetSettings().hideUnavailableSpells=true; Mock.async=true; apply(k)
  for _,a in ipairs(k.db.appliedPlan.actions) do
    if a.nativeOverflow and not a.kind and not a.builtin and not a.combo and not a.known and a.spellIDs and a.spellIDs[1] then
      return k,a
    end
  end
  error("Fixture did not reserve an unknown overflow spell")
end

function Tests.availability_engine_overflow_save_failure_restores_original_shortcuts_and_metadata()
  local k,future=overflowReady(); local key=future.key; local command=GetBindingAction(key)
  local before=k.Copy(Mock.bindings); local save=SaveBindings; local calls=0
  SaveBindings=function(which)
    calls=calls+1; if calls==1 then return false end
    return save(which)
  end
  Mock:Learn(future.spellIDs[1],future.name); k.API:InvalidateSpellbook()
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local ok,why=Mock:Drain(); assert(not ok and why:find("Could not save learned ability shortcuts",1,true),tostring(why))
  assert(calls>=2,"Rollback did not persist restored overflow bindings")
  equal(GetBindingAction(key),command); equal(k.db.appliedPlan.bindingOwnership[key].command,command)
  for binding,value in pairs(before) do equal(Mock.bindings[binding],value,"Overflow rollback changed "..binding) end
  for binding in pairs(Mock.bindings) do assert(before[binding],"Overflow rollback left an unexpected key") end
  assert(not future.known and future.nativeHidden,"Failed shortcut save committed learned state")
end

function Tests.availability_engine_overflow_rollback_preserves_personal_shortcut_edit()
  local k,future=overflowReady(); local key=future.key
  local save=SaveBindings; local calls=0
  SaveBindings=function(which)
    calls=calls+1
    if calls==1 then assert(SetBinding(key,"OPENCHAT")); return false end
    return save(which)
  end
  Mock:Learn(future.spellIDs[1],future.name); k.API:InvalidateSpellbook()
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local ok,why=Mock:Drain(); assert(not ok and why:find("rolled back",1,true),tostring(why))
  equal(GetBindingAction(key),"OPENCHAT","Rollback overwrote a personally changed overflow shortcut")
  equal(Mock.bindingSets[Mock.bindingSet][key],"OPENCHAT","Rollback did not save the personal shortcut")
end

function Tests.availability_engine_binding_set_change_before_overflow_write_never_touches_new_set()
  local k,future=overflowReady(); local key=future.key
  Mock:Learn(future.spellIDs[1],future.name); k.API:InvalidateSpellbook()
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local originalSet=Mock.bindingSet; local other=originalSet==1 and 2 or 1
  LoadBindings(other); equal(Mock.bindingSet,other); assert(SetBinding(key,"OPENCHAT")); SaveBindings(other)
  local before=k.Copy(Mock.bindings); Mock:ResetWrites()
  local ok,why=Mock:Drain(); assert(not ok and why:lower():find("binding set changed",1,true),tostring(why))
  equal(Mock.bindingSet,other)
  for binding,value in pairs(before) do equal(Mock.bindings[binding],value,"Maintenance modified the newly active set") end
  for binding in pairs(Mock.bindings) do assert(before[binding],"Maintenance added a binding in the newly active set") end
  for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Maintenance wrote controls after the active set changed") end
end
