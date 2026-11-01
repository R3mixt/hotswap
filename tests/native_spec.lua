local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b,label)
  for key,value in pairs(a) do equal(b[key],value,(label or "map").."["..tostring(key).."]") end
  for key,value in pairs(b) do equal(a[key],value,(label or "map").." extra["..tostring(key).."]") end
end
local function initNative()
  TestAddon:Init(); Mock.async=true
  return TestAddon
end
local function applyNative(k)
  local state,why=k:Apply(); equal(state,"pending",why)
  local ok,message,frames=Mock:Drain(); assert(ok,message)
  return frames
end
local function namedAction(plan,id)
  for _,action in ipairs(plan.actions) do if action.id==id then return action end end
  error("Missing action "..id)
end
function Tests.native_apply_uses_blizzard_pages_and_never_creates_a_custom_action_dock()
  local k=initNative(); local frames=applyNative(k)
  assert(frames>1,"Native setup was not spread across frames")
  assert(not _G.KBO_ActionDock,"Native setup created a custom action dock")
  equal(Mock.bindings["1"],"ACTIONBUTTON1","Primary key bypasses Blizzard's current-page button")
  for kind,id in pairs({caster="druid.wrath.caster",cat="druid.claw.cat",bear="druid.maul.bear",moonkin="druid.wrath.moonkin"}) do
    Mock.formIndex=0
    for name,form in pairs(k.API:GetForms()) do if name==kind then Mock.formIndex=form.index end end
    local action=Mock:NativeActionFor("1"); assert(action,"Native page is empty: "..kind)
    local expected=namedAction(k.db.appliedPlan,id)
    equal(action[1],expected.body and "macro" or "spell",kind.." native action type")
    equal(action[2],expected.body and expected.macroIndex or expected.spellID,kind.." native action ID")
  end
  for _,kind in ipairs({"travel","aquatic"}) do
    Mock.formIndex=k.API:GetForms()[kind].index
    local action=Mock:NativeActionFor("1")
    equal(action[2],namedAction(k.db.appliedPlan,"druid.wrath.caster").spellID,kind.." must retain Base bar")
  end
  Mock.formIndex=k.API:GetForms().cat.index; Mock.stealth=true
  equal(Mock:NativePage(),7,"Prowl incorrectly selected a custom action page")
  equal(k.API:GetActiveActionPage(k:GetSettings(),k.API:GetForms()),"cat","Prowl visual page differs from native Cat")
  assert(Mock.actionToggles[1],"Required native extra action bars were not enabled")
end
function Tests.native_form_page_helper_uses_cached_indices_and_movement_forms_share_base()
  local k=initNative(); local forms=k.API:GetForms()
  local info=k.API.SpellInfo; local reads=0
  k.API.SpellInfo=function(...) reads=reads+1; return info(...) end
  for _,kind in ipairs({"travel","aquatic","cat","bear","moonkin"}) do
    Mock.formIndex=forms[kind].index
    equal(k.API:GetActiveActionPage(k:GetSettings(),forms),k.API:ActionPageForForm(kind),kind.." current page")
  end
  equal(reads,0,"Following form pages repeatedly queried spell metadata")
  equal(k.API:ActionPageForForm("prowl"),"cat","Prowl acquired a custom empty page")
  equal(k.API:ActionPageForForm("flight"),"caster","Movement form acquired a custom empty page")
end
function Tests.native_apply_and_restore_are_bounded_and_preserve_original_bar_contents()
  local k=initNative()
  Mock.actions[1]={"spell",5176,"spell"}; Mock.actions[61]={"macro",1}; Mock.actions[145]={"item",1234}
  local original=k.Copy(Mock.actions); local binds=k.Copy(Mock.bindings)
  local state=k:Apply(); equal(state,"pending","Async apply result")
  local iterations=0
  while k.Engine.busy do
    Mock:ResetWrites(); Mock:Advance(0.016); iterations=iterations+1
    local bindingWrites,slotWrites=0,0
    for _,write in ipairs(Mock.writes) do
      if write[1]=="binding" then bindingWrites=bindingWrites+1 end
      if write[1]=="action" or write[1]=="pickupaction" then slotWrites=slotWrites+1 end
    end
    assert(bindingWrites<=6,"More than six binding writes ran in one frame")
    assert(slotWrites<=6,"More than six slot writes ran in one frame")
    assert(iterations<2000,"Apply never finished")
  end
  assert(k.Engine.lastJob.ok,k.Engine.lastJob.message)
  equal(k:Restore(),"pending","Async restore result")
  local ok,why=Mock:Drain(); assert(ok,why)
  same(Mock.bindings,binds,"Original native binding restore")
  for slot,data in pairs(original) do
    local actual=Mock.actions[slot]; assert(actual,"Original slot disappeared: "..slot)
    equal(actual[1],data[1],"Original slot type"); equal(actual[2],data[2],"Original slot ID")
  end
  for slot in pairs(Mock.actions) do assert(original[slot],"Restore retained generated action at "..slot) end
  equal(Mock.actionToggles[1],false,"Restore retained enabled extra bars")
end
function Tests.native_job_rolls_back_slot_and_binding_failure_across_separate_frames()
  local k=initNative(); local binds=k.Copy(Mock.bindings)
  Mock.actions[1]={"spell",5176,"spell"}; local original=k.Copy(Mock.actions)
  local real=SetBinding; local rejected=false
  SetBinding=function(key,command,...)
    if not rejected and key=="T" and command and command:find("MULTIACTION",1,true) then rejected=true; return false end
    return real(key,command,...)
  end
  equal(k:Apply(),"pending","Failed setup must still start as a bounded job")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("rolled back",1,true),tostring(why))
  assert(rejected,"Binding failure injection was not exercised")
  same(Mock.bindings,binds,"Failed native setup binding rollback")
  for slot,data in pairs(original) do equal(Mock.actions[slot][2],data[2],"Failed setup native slot rollback") end
  assert(not k.db.enabled,"Failed native setup was marked installed")
  equal(GetMacroInfo(1),"UserMacro","Rollback deleted a personal macro")
end
function Tests.native_job_pauses_in_combat_without_writes_and_resumes_without_losing_controls()
  local k=initNative(); equal(k:Apply(),"pending")
  for i=1,10 do Mock:Advance(0.016) end
  Mock.combat=true; Mock:ResetWrites(); Mock:Advance(0.1)
  assert(k.Engine.busy and k.Engine.job.paused,"Combat did not pause the active setup")
  equal(#Mock.writes,0,"Paused setup wrote protected state during combat")
  Mock.combat=false
  local ok,why=Mock:Drain(); assert(ok,why)
  equal(Mock.bindings.W,"MOVEFORWARD","Completed setup lost movement")
  equal(Mock.bindings.ESCAPE,"TOGGLEGAMEMENU","Completed setup lost Escape")
  equal(Mock.bindings.BUTTON2,"TURNORACTION","Completed setup lost mouse turning")
end
function Tests.native_pending_spell_gets_real_macro_on_original_bar_before_learning()
  local k=initNative(); Mock.class="HUNTER"; Mock.spells={}; Mock.forms={}
  Mock:Learn(75,"Auto Shot")
  Mock.catalog[19434]={id=19434,name="Aimed Shot",icon=135130}
  applyNative(k)
  local aimed=namedAction(k.db.appliedPlan,"hunter.aimed_shot")
  assert(not aimed.known and aimed.nativeMacro and aimed.macroIndex,"Unlearned native spell was left empty")
  local action=Mock:NativeActionFor("2")
  equal(action[1],"macro","Reserved spell is not a native macro action")
  local _,_,body=GetMacroInfo(action[2])
  assert(body:find("Aimed Shot",1,true),"Reserved macro does not target its future spell")
end
function Tests.native_vehicle_and_manual_page_controls_remain_owned_by_blizzard()
  local k=initNative(); applyNative(k)
  Mock.actions[121]={"spell",999001,"spell"}; Mock.vehiclePage=11
  equal(Mock:NativeActionFor("1")[2],999001,"Primary key did not use native vehicle action")
  Mock.vehiclePage=nil; Mock.actionPage=2; Mock.actions[13]={"spell",999002,"spell"}
  Mock.formIndex=k.API:GetForms().cat.index
  equal(Mock:NativeActionFor("1")[2],999002,"Native manually selected page was overridden by custom form handling")
end

function Tests.native_large_unsaved_binding_snapshot_and_replacement_never_burst_writes()
  local k=initNative()
  for _,prefix in ipairs({"","SHIFT-","CTRL-","CTRL-SHIFT-","ALT-","ALT-SHIFT-","ALT-CTRL-","ALT-CTRL-SHIFT-"}) do
    for index=1,24 do Mock.bindings[prefix.."F"..index]="ACTIONBUTTON12" end
    for index=0,9 do Mock.bindings[prefix.."NUMPAD"..index]="ACTIONBUTTON12" end
  end
  -- Deliberately leave the saved account set unchanged: snapshot must recover
  -- hundreds of unsaved edits after reading the inactive character set.
  local original=k.Copy(Mock.bindings)
  equal(k:Apply(),"pending")
  local frames=0
  while k.Engine.busy do
    Mock:ResetWrites(); Mock:Advance(0.016); frames=frames+1
    local writes=0
    for _,event in ipairs(Mock.writes) do if event[1]=="binding" then writes=writes+1 end end
    assert(writes<=6,"Unsaved snapshot restoration burst more than six binding writes")
    assert(frames<2000,"Large binding setup did not finish")
  end
  assert(k.Engine.lastJob.ok,k.Engine.lastJob.message)
  local first=k.Engine:ListBackups()[1]
  same(k.db.bindingBackups[first.id].snapshot.bindings,original,"Named unsaved-binding snapshot")
  equal(k:Restore(),"pending")
  local ok,why=Mock:Drain(); assert(ok,why)
  same(Mock.bindings,original,"Restored unsaved binding map")
end

function Tests.native_form_macro_maintenance_is_bounded_without_rebinding_or_new_custom_bars()
  local k=initNative(); applyNative(k)
  local before=k.Copy(Mock.bindings)
  local cat=namedAction(k.db.appliedPlan,"druid.form_cat")
  local previousBody=cat.body
  local forms=k.API:GetForms(); local catIndex,bearIndex=forms.cat.index,forms.bear.index
  Mock.forms[catIndex],Mock.forms[bearIndex]=Mock.forms[bearIndex],Mock.forms[catIndex]
  Mock:ResetWrites()
  equal(k.Engine:Activate(k.db.appliedPlan),"pending","Changed form indices were not queued for maintenance")
  local ok,why=Mock:Drain(); assert(ok,why)
  same(Mock.bindings,before,"Form learning moved existing keybinds")
  assert(cat.body~=previousBody and cat.body:find("noform:"..bearIndex,1,true),"Learned form macro retained the old ordinal")
  for _,event in ipairs(Mock.writes) do assert(event[1]~="binding" and event[1]~="action","Form maintenance rebuilt bindings or native slots") end
  assert(not _G.KBO_ActionDock,"Form maintenance created custom bars")
end

function Tests.native_incomplete_combo_activates_only_when_all_spells_are_learned_and_reverts_safely()
  local k=initNative(); applyNative(k)
  local action=namedAction(k.db.appliedPlan,"druid.natures_swiftness_heal")
  assert(not action.known and action.macroName,"Unknown combo fixture was not reserved")
  local index=GetMacroIndexByName(action.macroName)
  local _,_,body=GetMacroInfo(index)
  assert(not body:find("/cast",1,true),"Incomplete combo can cast a partial spell")
  local binds=k.Copy(Mock.bindings)
  Mock:Learn(17116,"Nature's Swiftness"); Mock:ResetWrites(); Mock:Fire("SPELLS_CHANGED")
  local ok,why=Mock:Drain(); assert(ok,why)
  _,_,body=GetMacroInfo(index)
  assert(action.known and body:find("/cast [@player] Nature's Swiftness",1,true) and body:find("/cast [@player] Healing Touch",1,true),"Newly learned combo did not activate both spells")
  same(Mock.bindings,binds,"Learning the combo changed existing bindings")
  for index,spell in ipairs(Mock.spells) do if spell.id==17116 then table.remove(Mock.spells,index); break end end
  Mock:Fire("SPELLS_CHANGED"); ok,why=Mock:Drain(); assert(ok,why)
  _,_,body=GetMacroInfo(GetMacroIndexByName(action.macroName))
  assert(not action.known and not body:find("/cast",1,true),"Unlearning a component left a partial combo active")
end

function Tests.native_maintenance_preserves_macro_edits_made_after_job_was_queued()
  local k=initNative(); applyNative(k)
  local action=namedAction(k.db.appliedPlan,"druid.natures_swiftness_heal")
  Mock:Learn(17116,"Nature's Swiftness"); k.API:InvalidateSpellbook()
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending","Learned combo maintenance was not queued")
  local index=GetMacroIndexByName(action.macroName)
  EditMacro(index,nil,nil,"/say my personal edit")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("changed before maintenance",1,true),tostring(why))
  local _,_,body=GetMacroInfo(GetMacroIndexByName(action.macroName))
  equal(body,"/say my personal edit","Deferred maintenance overwrote a personal macro edit")
end

function Tests.native_snapshot_recovers_when_reloading_original_binding_set_fails_once()
  local k=initNative(); local original=k.Copy(Mock.bindings); local active=Mock.bindingSet
  local load=LoadBindings; local visited=false; local rejected=false
  LoadBindings=function(which)
    if which~=active then visited=true end
    if visited and which==active and not rejected then rejected=true; return false end
    return load(which)
  end
  equal(k:Apply(),"pending")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("rolled back",1,true),tostring(why))
  assert(rejected,"Original binding-set failure did not execute")
  equal(Mock.bindingSet,active,"Failed snapshot left the inactive binding set selected")
  same(Mock.bindings,original,"Failed snapshot lost original controls")
  local entry=k.Engine:ListBackups()[1]
  assert(entry and k.db.bindingBackups[entry.id].complete,"Fully captured recovery maps were discarded")
end

function Tests.native_respec_away_from_moonkin_removes_the_old_cancel_form_macro()
  local k=initNative(); k:GetSettings().flavor="era"; applyNative(k)
  local moonkin=namedAction(k.db.appliedPlan,"druid.form_moonkin")
  assert(moonkin.known and moonkin.body:find("/cancelform",1,true),"Fixture did not start with an Era Moonkin macro")
  for index,form in ipairs(Mock.forms) do if form.id==24858 then table.remove(Mock.forms,index); break end end
  for index,spell in ipairs(Mock.spells) do if spell.id==24858 then table.remove(Mock.spells,index); break end end
  Mock:Fire("PLAYER_TALENT_UPDATE")
  local ok,why=Mock:Drain(); assert(ok,why)
  assert(not moonkin.known and not moonkin.spellID and moonkin.nativePending,"Lost Moonkin talent still appears learned")
  assert(not moonkin.body:find("/cancelform",1,true) and moonkin.body:find("[noform]",1,true),"Removed Moonkin talent can drop the current form")
  local _,_,body=GetMacroInfo(GetMacroIndexByName(moonkin.macroName))
  equal(body,moonkin.body,"Removed form metadata and installed macro disagree")
end
