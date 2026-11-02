local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function same(actual,expected,label)
  for key,value in pairs(expected) do equal(actual[key],value,(label or "bindings").." "..key) end
  for key in pairs(actual) do assert(expected[key],(label or "bindings").." retained extra "..key) end
end
local function ready()
  local k=TestAddon; k:Init()
  Mock:AllowFullCatalogMacros() -- The all-known Druid fixture tests ownership, not storage limits.
  return k
end
local function apply(k) local ok,why=k:Apply(); assert(ok,why) end

function Tests.binding_ownership_apply_preserves_unassigned_keyboard_and_mouse_controls()
  local k=ready()
  for key,command in pairs({NUMPADDECIMAL="TOGGLEQUESTLOG",BUTTON6="MOVEANDSTEER",["ALT-BUTTON8"]="TURNORACTION"}) do assert(SetBinding(key,command)) end
  assert(SetBinding("ENTER","REPLY"))
  local plan=k:Preview()
  for _,key in ipairs({"NUMPADDECIMAL","BUTTON6","ALT-BUTTON8"}) do assert(not plan.nativeLayout.keys[key],"Fixture chose a managed key: "..key) end
  apply(k)
  equal(Mock.bindings.NUMPADDECIMAL,"TOGGLEQUESTLOG")
  equal(Mock.bindings.BUTTON6,"MOVEANDSTEER")
  equal(Mock.bindings["ALT-BUTTON8"],"TURNORACTION")
  equal(Mock.bindings.ENTER,"OPENCHAT","Explicit preset key did not replace its old command")
  local owned=k.db.appliedPlan.bindingOwnership
  assert(owned and owned.ENTER and owned.ENTER.previous=="REPLY" and owned.ENTER.command=="OPENCHAT","Displaced binding was not recorded")
  assert(not owned.NUMPADDECIMAL and not owned.BUTTON6 and not owned["ALT-BUTTON8"],"Unassigned inputs became owned")
end

function Tests.binding_ownership_releasing_a_managed_key_restores_its_displaced_binding_after_repeat_apply()
  local k=ready(); assert(SetBinding("CTRL-F24","TOGGLEQUESTLOG"))
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="CTRL-F24"; apply(k)
  local previous=k.db.appliedPlan.bindingOwnership["CTRL-F24"]
  assert(previous and previous.previous=="TOGGLEQUESTLOG")
  apply(k)
  equal(k.db.appliedPlan.bindingOwnership["CTRL-F24"].previous,"TOGGLEQUESTLOG","Repeat Apply replaced the displaced binding with its own action")
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="SHIFT-F24"; apply(k)
  equal(Mock.bindings["CTRL-F24"],"TOGGLEQUESTLOG","Released key did not recover its displaced binding")
  assert(not k.db.appliedPlan.bindingOwnership["CTRL-F24"],"Released key retained ownership")
  assert(k.db.appliedPlan.bindingOwnership["SHIFT-F24"],"New planned key was not owned")
end

function Tests.binding_ownership_releasing_a_managed_key_preserves_a_manual_change_to_it()
  local k=ready(); assert(SetBinding("CTRL-F24","TOGGLEQUESTLOG"))
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="CTRL-F24"; apply(k)
  assert(SetBinding("CTRL-F24","TOGGLEWORLDMAP"))
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="SHIFT-F24"; apply(k)
  equal(Mock.bindings["CTRL-F24"],"TOGGLEWORLDMAP","Releasing a key overwrote the player's newer assignment")
  assert(not k.db.appliedPlan.bindingOwnership["CTRL-F24"],"Manual key retained addon ownership")
end

function Tests.binding_ownership_releasing_a_previously_empty_key_removes_only_the_owned_command()
  local k=ready(); equal(GetBindingAction("CTRL-F24"),"")
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="CTRL-F24"; apply(k)
  equal(k.db.appliedPlan.bindingOwnership["CTRL-F24"].previous,false,"Originally empty key sentinel")
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="SHIFT-F24"; apply(k)
  equal(GetBindingAction("CTRL-F24"),"","Released originally empty key was left bound")
end

function Tests.binding_ownership_legacy_layout_releases_only_prior_managed_keys_using_original_backup()
  local k=ready(); assert(SetBinding("CTRL-F24","TOGGLEQUESTLOG"))
  assert(SetBinding("NUMPADDECIMAL","TOGGLEWORLDMAP"))
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="CTRL-F24"; apply(k)
  k.db.appliedPlan.bindingOwnership=nil
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="SHIFT-F24"; apply(k)
  equal(Mock.bindings["CTRL-F24"],"TOGGLEQUESTLOG","Legacy owned key did not restore its baseline command")
  equal(Mock.bindings.NUMPADDECIMAL,"TOGGLEWORLDMAP","Legacy adoption captured an unrelated key")
end

function Tests.binding_ownership_failure_and_original_restore_keep_their_exact_snapshot_semantics()
  local k=ready(); assert(SetBinding("NUMPADDECIMAL","TOGGLEQUESTLOG")); assert(SetBinding("BUTTON6","MOVEANDSTEER"))
  local original=k.Copy(Mock.bindings); local originalOther=k.Copy(Mock.bindingSets[2])
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="CTRL-F24"; apply(k)
  assert(SetBinding("NUMPADDECIMAL","TOGGLEWORLDMAP")); assert(SetBinding("BUTTON7","TURNORACTION"))
  local before=k.Copy(Mock.bindings); local account=k.Copy(Mock.bindingSets[1])
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="SHIFT-F24"
  local set=SetBinding; local rejected=false
  SetBinding=function(key,command,...)
    if not rejected and key=="SHIFT-F24" and command then rejected=true; return false end
    return set(key,command,...)
  end
  local ok,why=k:Apply(); assert(not ok and rejected and why:find("rolled back",1,true),tostring(why))
  same(Mock.bindings,before,"Failed Apply snapshot rollback")
  same(Mock.bindingSets[1],account,"Failed Apply account rollback")
  -- The active snapshot includes unsaved edits, so recovery saves that exact
  -- active map while preserving the previously inactive account set.
  same(Mock.bindingSets[2],before,"Failed Apply character rollback")
  assert(k:Restore())
  same(Mock.bindings,original,"Original setup restore")
  same(Mock.bindingSets[1],original,"Original account restore")
  same(Mock.bindingSets[2],originalOther,"Original character restore")
end
