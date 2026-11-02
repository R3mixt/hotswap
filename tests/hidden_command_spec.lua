local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function same(actual,expected,label)
  for key,value in pairs(expected) do equal(actual[key],value,(label or "bindings").." "..key) end
  for key in pairs(actual) do assert(expected[key],(label or "bindings").." retained unexpected "..key) end
end
local function ready()
  Mock.build="1.15.9"; Mock.buildNumber="70576"
  TestAddon:Init(); Mock.async=true
  Mock:AllowFullCatalogMacros() -- Keep the full Druid layout available for mouse-control recovery.
  return TestAddon
end
local function nativeMouse()
  equal(GetBindingAction("BUTTON1"),"CAMERAORSELECTORMOVE","Left mouse selection/camera")
  equal(GetBindingAction("BUTTON2"),"TURNORACTION","Right mouse turn/interact")
end
local function finish()
  local ok,why=Mock:Drain(); assert(ok,why)
end
local function apply(k)
  equal(k:Apply(),"pending"); finish()
end

function Tests.hidden_mouse_commands_are_supported_without_public_enumeration()
  Mock.build="1.15.9"
  local seen={}
  for index=1,GetNumBindings() do local command=GetBinding(index); seen[command]=true end
  assert(not seen.CAMERAORSELECTORMOVE and not seen.TURNORACTION,"Hidden commands leaked into the menu registry fixture")
  assert(not seen.TARGETFOCUS,"Unavailable Era focus became a hidden supported command")
  assert(SetBinding("BUTTON1","CAMERAORSELECTORMOVE")); assert(SetBinding("BUTTON2","TURNORACTION"))
  nativeMouse()
  equal(GetBindingKey("CAMERAORSELECTORMOVE"),"BUTTON1")
  equal(GetBindingKey("TURNORACTION"),"BUTTON2")
  assert(not SetBinding("F6","TARGETFOCUS"),"Hidden support relaxed unsupported-command validation")
end

function Tests.hidden_mouse_commands_remain_installed_with_the_addon_window_closed()
  local k=ready()
  -- Match the reported damaged state: no native camera commands remain on the
  -- physical mouse buttons before the repaired preset is applied.
  assert(SetBinding("BUTTON1")); assert(SetBinding("BUTTON2"))
  apply(k)
  local catalog,readable=k.API:GetBindingCommands(true)
  assert(readable and k.API:IsBindingCommandSupported("CAMERAORSELECTORMOVE",catalog) and k.API:IsBindingCommandSupported("TURNORACTION",catalog),"Known hidden camera controls were treated as unavailable")
  nativeMouse()
  k.UI:Open(); k.UI:ShowPage("Bindings"); k.UI.frame:Hide()
  assert(not k.UI.tester or not k.UI.tester:IsVisible(),"Closed window still captures keyboard input")
  assert(not k.UI.testMouseShield or not k.UI.testMouseShield:IsVisible(),"Closed window still captures mouse input")
  nativeMouse()
  equal(Mock.bindingSets[2].BUTTON1,"CAMERAORSELECTORMOVE","Saved left mouse command")
  equal(Mock.bindingSets[2].BUTTON2,"TURNORACTION","Saved right mouse command")
end

function Tests.hidden_mouse_reader_preserves_all_aliases_and_direct_custom_or_empty_buttons()
  local k=ready()
  for _,key in ipairs({"SHIFT-BUTTON1","CTRL-BUTTON1","ALT-BUTTON1"}) do assert(SetBinding(key,"CAMERAORSELECTORMOVE")) end
  assert(SetBinding("BUTTON1","TARGETSELF")); assert(SetBinding("BUTTON2"))
  local result={BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION",F24="TURNORACTION",W="MOVEFORWARD"}
  local ok,why=k.API:ReadHiddenMouseBindings(result); assert(ok,why)
  equal(result.BUTTON1,"TARGETSELF"); equal(result.BUTTON2,nil)
  equal(result.F24,nil,"Reader retained a stale hidden-command alias")
  equal(result.W,"MOVEFORWARD")
  for _,key in ipairs({"SHIFT-BUTTON1","CTRL-BUTTON1","ALT-BUTTON1"}) do equal(result[key],"CAMERAORSELECTORMOVE","Hidden alias "..key) end
end

function Tests.hidden_mouse_reader_failure_leaves_the_callers_binding_snapshot_unchanged()
  local k=ready(); local original={BUTTON1="TARGETSELF",BUTTON2="TURNORACTION",F24="CAMERAORSELECTORMOVE",W="MOVEFORWARD"}
  local result=k.Copy(original); local get=GetBindingKey
  GetBindingKey=function(command) if command=="TURNORACTION" then error("unreadable hidden binding API") end; return get(command) end
  local ok,why=k.API:ReadHiddenMouseBindings(result)
  assert(not ok and type(why)=="string",tostring(why)); same(result,original,"Failed hidden read snapshot")
end

function Tests.hidden_mouse_snapshots_restore_every_hidden_key_in_both_binding_sets()
  local k=ready()
  assert(SetBinding("CTRL-BUTTON1","TURNORACTION"))
  Mock.bindingSets[2]={BUTTON1="TURNORACTION",BUTTON2="CAMERAORSELECTORMOVE",["SHIFT-BUTTON2"]="TURNORACTION",I="OPENALLBAGS"}
  local active=k.Copy(Mock.bindings); local inactive=k.Copy(Mock.bindingSets[2])
  apply(k)
  local backup=k.db.bindingBackups[k.db.lastBindingBackupID].snapshot
  equal(backup.mouseBindingsVersion,1,"Snapshot did not mark hidden mouse bindings as captured")
  same(backup.bindings,active,"Active hidden snapshot")
  same(backup.accountBindings,active,"Account hidden snapshot")
  same(backup.characterBindings,inactive,"Character hidden snapshot")
  equal(k:Restore(),"pending"); finish()
  same(Mock.bindings,active,"Restored hidden active bindings")
  same(Mock.bindingSets[1],active,"Restored hidden account bindings")
  same(Mock.bindingSets[2],inactive,"Restored hidden character bindings")
end

function Tests.hidden_mouse_legacy_backup_retains_uncaptured_mouse_controls_and_aliases()
  local k=ready(); apply(k)
  equal(Mock.bindingSet,2,"Fixture should edit the current character binding set")
  local accountLeft=Mock.bindingSets[1].BUTTON1
  local accountRight=Mock.bindingSets[1].BUTTON2
  local legacy=k.db.backup; legacy.mouseBindingsVersion=nil
  for _,field in ipairs({"bindings","accountBindings","characterBindings"}) do
    for key,command in pairs(legacy[field] or {}) do
      if key=="BUTTON1" or key=="BUTTON2" or k.API.HiddenMouseCommands[command] then legacy[field][key]=nil end
    end
  end
  assert(SetBinding("BUTTON1","TARGETSELF")); assert(SetBinding("SHIFT-BUTTON1","CAMERAORSELECTORMOVE"))
  equal(k:Restore(),"pending"); finish()
  equal(Mock.bindingSet,1,"Original restore should select the original account binding set")
  equal(GetBindingAction("BUTTON1"),accountLeft,"Legacy restore copied character left-click into account controls")
  equal(GetBindingAction("BUTTON2"),accountRight,"Legacy restore changed the account's right-click binding")
  equal(GetBindingAction("SHIFT-BUTTON1"),"","Character-only camera alias leaked into account bindings")
  equal(Mock.bindingSets[2].BUTTON1,"TARGETSELF","Legacy backup lost an explicit unsaved character mouse binding")
  equal(Mock.bindingSets[2]["SHIFT-BUTTON1"],"CAMERAORSELECTORMOVE","Legacy backup lost the character's uncaptured camera alias")
end

function Tests.hidden_mouse_new_snapshot_restores_intentionally_empty_buttons_exactly()
  local k=ready(); assert(SetBinding("BUTTON1")); assert(SetBinding("BUTTON2"))
  apply(k); nativeMouse()
  equal(k.db.backup.mouseBindingsVersion,1)
  equal(k:Restore(),"pending"); finish()
  equal(GetBindingAction("BUTTON1"),"","Captured empty left button was guessed into a default")
  equal(GetBindingAction("BUTTON2"),"","Captured empty right button was guessed into a default")
end

function Tests.hidden_mouse_repair_saves_missing_buttons_without_replacing_explicit_controls()
  local k=ready(); apply(k)
  k.db.appliedPlan.mouseBindingsVersion=nil; k.db.appliedPlan.bindingOwnership=nil
  assert(SetBinding("BUTTON1","TARGETSELF")); assert(SetBinding("BUTTON2"))
  assert(SetBinding("BUTTON6","MOVEANDSTEER"))
  local currentSet=Mock.bindingSet; local previousBackups=#k.Engine:ListBackups()
  equal(k.Engine:RepairMouseControls(),"pending"); finish()
  equal(GetBindingAction("BUTTON1"),"TARGETSELF","Recovery overwrote a nonempty left mouse binding")
  equal(GetBindingAction("BUTTON2"),"TURNORACTION")
  equal(GetBindingAction("BUTTON6"),"MOVEANDSTEER")
  equal(Mock.bindingSets[currentSet].BUTTON1,"TARGETSELF")
  equal(Mock.bindingSets[currentSet].BUTTON2,"TURNORACTION")
  equal(#k.Engine:ListBackups(),previousBackups+1,"Repair omitted its undo snapshot")
  equal(k.Engine:ListBackups()[1].status,"repaired")
  assert(not k.db.appliedPlan.bindingOwnership,"Repair created incomplete ownership for a legacy plan")
  equal(k.db.appliedPlan.mouseBindingsVersion,1,"Repaired legacy plan was not marked migrated")
end

function Tests.hidden_mouse_legacy_login_repair_defers_in_combat_and_resumes_afterward()
  local k=ready(); apply(k)
  k.db.appliedPlan.mouseBindingsVersion=nil
  assert(SetBinding("BUTTON1")); assert(SetBinding("BUTTON2"))
  Mock.combat=true; Mock:ResetWrites(); Mock:Fire("PLAYER_LOGIN")
  assert(k.pendingMouseRepair,"Legacy login did not defer mouse repair")
  equal(#Mock.writes,0,"Combat login attempted protected mouse recovery")
  equal(GetBindingAction("BUTTON1"),""); equal(GetBindingAction("BUTTON2"),"")
  Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
  if k.Engine.busy then finish() end
  nativeMouse(); assert(not k.pendingMouseRepair)
  equal(k.db.appliedPlan.mouseBindingsVersion,1)
end

function Tests.hidden_mouse_current_plan_login_preserves_deliberate_new_unbinding()
  local k=ready(); apply(k)
  equal(k.db.appliedPlan.mouseBindingsVersion,1)
  assert(SetBinding("BUTTON1")); assert(SetBinding("BUTTON2"))
  Mock:ResetWrites(); Mock:Fire("PLAYER_LOGIN")
  if k.Engine.busy then finish() end
  equal(GetBindingAction("BUTTON1"),"","Current-plan login overwrote a deliberate left-button change")
  equal(GetBindingAction("BUTTON2"),"","Current-plan login overwrote a deliberate right-button change")
  assert(not k.pendingMouseRepair,"Current plan incorrectly queued legacy recovery")
end

function Tests.hidden_mouse_named_restore_preserves_explicit_nondefault_button_assignments()
  local k=ready(); apply(k)
  assert(SetBinding("BUTTON1","TURNORACTION")); assert(SetBinding("BUTTON2","CAMERAORSELECTORMOVE"))
  assert(SetBinding("SHIFT-BUTTON2","TURNORACTION"))
  local customized=k.Copy(Mock.bindings)
  apply(k); nativeMouse()
  local previous=k.Engine:ListBackups()[1].id
  equal(k.Engine:RestoreBackup(previous),"pending"); finish()
  same(Mock.bindings,customized,"Named backup customized mouse controls")
  equal(GetBindingAction("BUTTON1"),"TURNORACTION","Restore replaced the user's explicit left mouse assignment")
  equal(GetBindingAction("BUTTON2"),"CAMERAORSELECTORMOVE","Restore replaced the user's explicit right mouse assignment")
end

function Tests.hidden_mouse_apply_failure_rolls_back_camera_controls_and_both_sets()
  local k=ready(); assert(SetBinding("SHIFT-BUTTON1","CAMERAORSELECTORMOVE"))
  local active=k.Copy(Mock.bindings); local inactive=k.Copy(Mock.bindingSets[2])
  local set=SetBinding; local rejected=false
  SetBinding=function(key,command,...)
    if not rejected and key=="T" and command and command:find("MULTIACTION",1,true) then rejected=true; return false end
    return set(key,command,...)
  end
  equal(k:Apply(),"pending")
  local ok,why=Mock:Drain()
  assert(rejected and not ok and why:find("rolled back",1,true),tostring(why))
  same(Mock.bindings,active,"Rollback hidden active bindings")
  same(Mock.bindingSets[1],active,"Rollback hidden account bindings")
  same(Mock.bindingSets[2],inactive,"Rollback hidden character bindings")
  nativeMouse()
end

function Tests.hidden_mouse_controls_are_never_unbound_between_apply_frames_or_during_combat_pause()
  local k=ready(); equal(k:Apply(),"pending")
  local frames=0; local paused=false
  while k.Engine.busy do
    nativeMouse()
    if frames==12 and not paused then
      paused=true; Mock.combat=true; Mock:ResetWrites(); Mock:Advance(0.1)
      nativeMouse(); equal(#Mock.writes,0,"Paused apply changed camera controls")
      Mock.combat=false
    end
    Mock:Advance(0.016); frames=frames+1
    assert(frames<2000,"Setup did not complete")
  end
  assert(paused,"Combat pause fixture was not exercised")
  assert(k.Engine.lastJob.ok,k.Engine.lastJob.message); nativeMouse()
end
