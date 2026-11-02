-- Full-catalog transaction fixtures explicitly use synthetic character capacity; capacity tests retain 30.
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function body(name)
  local found,_,text=GetMacroInfo(GetMacroIndexByName(name))
  assert(found==name,"Missing macro "..tostring(name)); return text
end
local function sameMap(actual,expected)
  for key,value in pairs(expected) do equal(actual[key],value,"Binding "..key) end
  for key in pairs(actual) do assert(expected[key],"Unexpected binding "..key) end
end
local function ready()
  local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros(); Mock.async=true
  CreateMacro("ZZZ test personal",1,"/say character original",true)
  return k
end
local function finish()
  local ok,why=Mock:Drain(); assert(ok,why)
end
local function apply(k)
  equal(k:Apply(),"pending"); finish()
end
local function beforePlacement(k)
  equal(k:Apply(),"pending")
  for frame=1,2000 do
    local job=k.Engine.job
    if job and job.steps[job.index].message=="Preparing native action bars" then return job end
    assert(k.Engine.busy,"Setup ended before the placement test could run")
    Mock:Advance(0.016)
  end
  error("Setup never reached native placement")
end
local function generated(plan)
  for _,action in ipairs(plan.actions) do if action.body and action.macroName then return action end end
  error("Plan contains no generated macros")
end
local function verifyPlaced(k,plan)
  local actions={}; for _,action in ipairs(plan.actions) do actions[action.id]=action end
  for _,placement in ipairs(plan.nativeLayout.placements) do
    local expected=actions[placement.actionID]
    if expected.body then
      local actual=Mock.actions[placement.slot]
      assert(actual and actual[1]=="macro","Missing generated macro at slot "..placement.slot)
      local name,_,text=GetMacroInfo(actual[2])
      equal(text,expected.body,"Macro content at slot "..placement.slot)
      assert(k.db.ownedMacros[name]==text,"Slot no longer uses an owned macro")
    end
  end
end

function Tests.macro_bank_mock_reorders_create_rename_delete_without_retargeting_bars()
  local z=CreateMacro("Zulu",1,"/say z",true)
  Mock.actions[1]={"macro",z}; PickupMacro(z)
  local a=CreateMacro("Alpha",1,"/say a",true)
  equal(a,121); equal(GetMacroIndexByName("Zulu"),122)
  equal(Mock.actions[1][2],122,"Create retargeted a native action")
  equal(Mock.cursor[2],122,"Create retargeted the held macro")
  local moved=EditMacro(GetMacroIndexByName("Zulu"),"000 First",nil,nil)
  equal(moved,121,"Rename did not return the new index")
  equal(Mock.actions[1][2],121,"Rename retargeted a native action")
  DeleteMacro(GetMacroIndexByName("Alpha"))
  equal(body("000 First"),"/say z")
  equal(Mock.actions[1][2],121,"Delete changed the remaining action")
  equal(body("UserMacro"),"/say preserved","Character-bank changes touched an account macro")
  ClearCursor()
end

function Tests.macro_identity_optimize_repeats_with_sorted_banks_and_original_restore()
  local k=ready(); local original=k.Copy(Mock.bindings)
  for iteration=1,2 do
    local created,why,name=k.Presets:CreateRecommended(); assert(created,why)
    equal(k.Presets:Activate(name),"pending"); finish()
    verifyPlaced(k,k.db.appliedPlan)
    assert(k.db.appliedPreset:find("Recommended Druid",1,true),"Optimize did not activate its preset")
  end
  equal(k:Restore(),"pending"); finish()
  sameMap(Mock.bindings,original)
  equal(body("UserMacro"),"/say preserved")
  local account,character=GetNumMacros(); equal(account,1); equal(character,1)
end

function Tests.macro_identity_apply_handles_personal_reorder_between_prepare_and_place()
  local k=ready(); local job=beforePlacement(k)
  local prepared=generated(job.plan); local oldIndex=GetMacroIndexByName(prepared.macroName)
  CreateMacro("000 personal account",1,"/say account",false)
  EditMacro(GetMacroIndexByName("ZZZ test personal"),"000 personal character",nil,nil)
  EditMacro(GetMacroIndexByName("UserMacro"),"000 renamed personal",nil,nil)
  assert(GetMacroIndexByName(prepared.macroName)~=oldIndex,"Fixture did not move the prepared macro")
  finish(); verifyPlaced(k,k.db.appliedPlan)
  equal(body("000 personal account"),"/say account")
  equal(body("000 personal character"),"/say character original")
  equal(body("000 renamed personal"),"/say preserved")
end

function Tests.macro_identity_apply_rejects_personal_edit_after_prepare_and_preserves_it_on_rollback()
  local k=ready(); local original=k.Copy(Mock.bindings)
  Mock.actions[1]={"macro",GetMacroIndexByName("UserMacro")}
  local job=beforePlacement(k); local action=generated(job.plan)
  EditMacro(GetMacroIndexByName(action.macroName),nil,nil,"/say my edited macro")
  CreateMacro("000 new personal",1,"/say keep this too",false)
  local ok,why=Mock:Drain()
  assert(not ok and why:find("changed before placement",1,true) and why:find("rolled back",1,true),tostring(why))
  sameMap(Mock.bindings,original)
  equal(body(action.macroName),"/say my edited macro","Rollback deleted a personal edit")
  equal(body("000 new personal"),"/say keep this too")
  local _,_,text=GetMacroInfo(Mock.actions[1][2]); equal(text,"/say preserved","Original bar macro changed")
end

function Tests.macro_identity_apply_rejects_removed_macro_without_using_its_reassigned_index()
  local k=ready(); local original=k.Copy(Mock.bindings)
  local job=beforePlacement(k); local action=generated(job.plan)
  local name=action.macroName
  DeleteMacro(GetMacroIndexByName(name))
  CreateMacro("000 replacement personal",1,"/say keep replacement",false)
  local ok,why=Mock:Drain()
  assert(not ok and why:find("changed before placement",1,true) and why:find("rolled back",1,true),tostring(why))
  sameMap(Mock.bindings,original)
  equal(GetMacroIndexByName(name),0,"Removed generated macro was unexpectedly recreated")
  equal(body("000 replacement personal"),"/say keep replacement")
end

function Tests.macro_identity_named_restore_recreates_macros_after_reindex_without_overwriting_edits()
  local k=ready(); apply(k); apply(k)
  local id=k.Engine:ListBackups()[1].id
  local action=generated(k.db.appliedPlan); local name,expected=action.macroName,action.body
  EditMacro(GetMacroIndexByName(name),nil,nil,"/say changed by player")
  equal(k:Restore(),"pending"); finish()
  CreateMacro("000 saved personal",1,"/say preserve",true)
  equal(k.Engine:RestoreBackup(id),"pending"); finish()
  verifyPlaced(k,k.db.appliedPlan)
  equal(body(name),"/say changed by player")
  equal(body("000 saved personal"),"/say preserve")
  local index,restoredName=k.Macros:FindOwned(name,expected)
  assert(index and restoredName~=name,"Restore did not use a safe suffixed identity")
end

function Tests.macro_identity_maintenance_rechecks_after_edit_reorders_and_rolls_back_by_name()
  local k=ready(); apply(k)
  -- Isolate the worker's rollback from Core's separate stale-form recovery,
  -- which correctly starts an original-setup restore after this failure.
  k.OnApplyComplete=function() end
  local previous={}; for name in pairs(k.db.ownedMacros) do previous[name]=body(name) end
  local forms=k.API:GetForms()
  Mock.forms[forms.cat.index],Mock.forms[forms.bear.index]=Mock.forms[forms.bear.index],Mock.forms[forms.cat.index]
  local edit=EditMacro; local calls=0
  EditMacro=function(...)
    calls=calls+1
    if calls==2 then error("injected second maintenance failure") end
    local result=edit(...)
    if calls==1 then edit(GetMacroIndexByName("ZZZ test personal"),"000 inserted during edit",nil,nil) end
    return result
  end
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("injected second maintenance failure",1,true) and why:find("rolled back",1,true),tostring(why))
  for name,text in pairs(previous) do equal(body(name),text,"Restored maintenance macro "..name) end
  equal(body("000 inserted during edit"),"/say character original")
  verifyPlaced(k,k.db.appliedPlan)
end

function Tests.macro_identity_maintenance_preserves_a_touched_macro_edited_before_rollback()
  local k=ready(); apply(k)
  k.OnApplyComplete=function() end
  local forms=k.API:GetForms()
  Mock.forms[forms.cat.index],Mock.forms[forms.bear.index]=Mock.forms[forms.bear.index],Mock.forms[forms.cat.index]
  local edit=EditMacro; local touched
  EditMacro=function(index,...)
    touched=GetMacroInfo(index)
    local result=edit(index,...)
    edit(GetMacroIndexByName(touched),nil,nil,"/say edited during maintenance")
    CreateMacro("000 maintenance personal",1,"/say keep",false)
    return result
  end
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("personal edits were preserved",1,true),tostring(why))
  equal(body(touched),"/say edited during maintenance")
  equal(body("000 maintenance personal"),"/say keep")
end

function Tests.macro_identity_maintenance_does_not_edit_replacement_after_touched_macro_is_removed()
  local k=ready(); apply(k)
  k.OnApplyComplete=function() end
  local forms=k.API:GetForms()
  Mock.forms[forms.cat.index],Mock.forms[forms.bear.index]=Mock.forms[forms.bear.index],Mock.forms[forms.cat.index]
  local edit=EditMacro; local removed
  EditMacro=function(index,...)
    removed=GetMacroInfo(index)
    local result=edit(index,...)
    DeleteMacro(GetMacroIndexByName(removed))
    CreateMacro("000 maintenance replacement",1,"/say untouched",false)
    return result
  end
  equal(k.Engine:RepairLearnedActions(k.db.appliedPlan),"pending")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("personal edits were preserved",1,true),tostring(why))
  equal(GetMacroIndexByName(removed),0)
  equal(body("000 maintenance replacement"),"/say untouched")
end

local function beforeOverflowBindings()
  Mock.class="WARLOCK"; Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
  _G.MultiBar5=nil; _G.MultiBar6=nil; _G.MultiBar7=nil
  local k=ready(); k.db.settings.flavor="era"
  for _,def in ipairs(k.Profiles:Get("WARLOCK","era")) do
    local id=def.spellIDs and def.spellIDs[1]
    if id and not def.combo then Mock.catalog[id]={id=id,name=def.name,icon=id} end
  end
  k.API:InvalidateSpellbook(); k:InvalidatePreview()
  local original=k.Copy(Mock.bindings)
  equal(k:Apply(),"pending")
  for frame=1,2000 do
    local job=k.Engine.job
    if job and job.steps[job.index].message=="Preparing native action bars" then
      assert(job.plan.nativeLayout.overflow>0,"Legacy four-bar fixture did not create overflow")
      local placedBodies={}
      for _,a in ipairs(job.plan.actions) do if a.nativeSlot and a.body then placedBodies[a.body]=true end end
      for _,action in ipairs(job.plan.actions) do
        if action.body and not action.nativeSlot and not placedBodies[action.body] then
          local entry=job.plan.nativeLayout.keys[action.key]
          if entry and entry.macroAction==action.id then return k,action,original end
        end
      end
      error("No generated overflow action found")
    end
    assert(k.Engine.busy,"Setup ended before overflow binding verification")
    Mock:Advance(0.016)
  end
  error("Setup never reached overflow binding verification")
end

function Tests.macro_identity_overflow_rechecks_current_identity_after_macro_reorder()
  local k,action=beforeOverflowBindings()
  CreateMacro("000 overflow personal",1,"/say account",false)
  EditMacro(GetMacroIndexByName("ZZZ test personal"),"000 renamed character",nil,nil)
  finish()
  equal(Mock.bindings[action.key],"MACRO "..action.macroName,"Overflow shortcut")
  equal(action.macroIndex,GetMacroIndexByName(action.macroName),"Overflow current macro index")
  equal(body(action.macroName),action.body,"Overflow identity after reordering")
  equal(body("000 overflow personal"),"/say account")
end

function Tests.macro_identity_overflow_rejects_edited_macro_before_binding_and_preserves_personal_text()
  local k,action,original=beforeOverflowBindings()
  EditMacro(GetMacroIndexByName(action.macroName),nil,nil,"/say edited overflow")
  local ok,why=Mock:Drain()
  assert(not ok and why:find("changed before binding",1,true) and why:find("rolled back",1,true),tostring(why))
  sameMap(Mock.bindings,original)
  equal(body(action.macroName),"/say edited overflow","Rollback removed an edited overflow macro")
  assert(not k.db.enabled,"Failed overflow setup was marked active")
end

function Tests.macro_identity_overflow_rejects_removed_macro_before_binding_without_retargeting()
  local k,action,original=beforeOverflowBindings()
  DeleteMacro(GetMacroIndexByName(action.macroName))
  CreateMacro("000 overflow replacement",1,"/say preserve replacement",false)
  local ok,why=Mock:Drain()
  assert(not ok and why:find("changed before binding",1,true) and why:find("rolled back",1,true),tostring(why))
  sameMap(Mock.bindings,original)
  equal(GetMacroIndexByName(action.macroName),0)
  equal(body("000 overflow replacement"),"/say preserve replacement")
  assert(not k.db.enabled,"Missing overflow macro setup was marked active")
end
