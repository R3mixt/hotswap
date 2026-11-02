local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function commands()
  local rows={}
  for index=1,GetNumBindings() do
    local row={GetBinding(index)}
    assert(not rows[row[1]],"A native command was enumerated once per key instead of once per command")
    rows[row[1]]=row
  end
  return rows
end
local function freshEra()
  Mock.build="1.15.9"; Mock.buildNumber="70576"; Mock.class="DRUID"
  Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
  Mock:Learn(5176,"Wrath"); Mock:Learn(5185,"Healing Touch")
  TestAddon:Init(); Mock.async=true
  return TestAddon
end

function Tests.command_inventory_includes_unbound_native_actions_and_all_keys_in_one_row()
  assert(SetBinding("W","MOVEFORWARD")); assert(SetBinding("UP","MOVEFORWARD"))
  local rows=commands()
  assert(rows.TARGETMOUSEOVER and not rows.TARGETMOUSEOVER[3],"Unbound native command is missing")
  equal(rows.TARGETMOUSEOVER[2],"BINDING_HEADER_TARGETING","Native category")
  equal(rows.MOVEFORWARD[3],"UP"); equal(rows.MOVEFORWARD[4],"W")
  assert(GetNumBindings()>200,"Inventory still enumerates only assigned keys")
end

function Tests.command_era_rejects_targetfocus_exactly_without_mutating_the_existing_f6_binding()
  Mock.build="1.15.9"; Mock.buildNumber="70576"
  assert(SetBinding("F6","TARGETSELF")); Mock:ResetWrites()
  equal(SetBinding("F6","TARGETFOCUS"),false,"Unsupported Era TARGETFOCUS")
  equal(Mock.bindings.F6,"TARGETSELF","Rejected command replaced F6")
  equal(#Mock.writes,0,"Rejected command wrote bindings")
  local rows=commands()
  assert(not rows.TARGETFOCUS and not rows.FOCUSTARGET,"Commented-out Era bindings became supported")
  Mock.bindings.F7="TARGETFOCUS"
  rows=commands()
  assert(not rows.TARGETFOCUS and not SetBinding("F8","TARGETFOCUS"),"Direct fixture data bypassed the unavailable native command")
end

function Tests.command_forever_support_is_separate_from_the_selected_era_profile()
  local k=TestAddon; k:Init(); k:GetSettings().flavor="era"
  local rows=commands()
  assert(rows.TARGETFOCUS and rows.FOCUSTARGET,"Forever binding inventory lost native focus")
  assert(SetBinding("F6","TARGETFOCUS"))
  equal(Mock.bindings.F6,"TARGETFOCUS")
end

function Tests.command_mock_rejects_unknown_commands_and_keeps_valid_dynamic_actions()
  for _,command in ipairs({"NOT_A_REAL_COMMAND","ACTIONBUTTON13","MULTIACTIONBAR8BUTTON1","MACRO ","CLICK Broken","EMOTE NOT_REAL"}) do
    assert(not SetBinding("F24",command),"Unknown command was accepted: "..command)
  end
  for _,command in ipairs({"ACTIONBUTTON12","MULTIACTIONBAR7BUTTON12","MACRO UserMacro","CLICK KBO_Mode_p1:LeftButton","EMOTE WAVE"}) do
    assert(SetBinding("F24",command),"Supported command was rejected: "..command)
  end
  assert(SetBinding("F24")); equal(Mock.bindings.F24,nil,"Clear binding")
end

function Tests.command_mock_explicit_registration_and_unavailability_are_authoritative()
  local command="TEST_ADDON_COMMAND"
  assert(not SetBinding("F24",command))
  Mock:RegisterBindingCommand(command,"BINDING_HEADER_TEST")
  local rows=commands(); assert(rows[command] and not rows[command][3],"Registered unbound addon command is absent")
  equal(rows[command][2],"BINDING_HEADER_TEST")
  assert(SetBinding("F24",command))
  Mock:SetBindingCommandAvailable(command,false)
  assert(not commands()[command] and not SetBinding("F23",command),"Unavailable command leaked back through assigned bindings")
  Mock:SetBindingCommandAvailable(command,true)
  assert(SetBinding("F23",command))
end

function Tests.command_fresh_era_druid_optimize_succeeds_without_installing_unsupported_f6()
  local k=freshEra()
  local result,why=k.Presets:Optimize(); equal(result,"pending",why)
  local ok,message=Mock:Drain(); assert(ok,message)
  assert(k.db.enabled and k.db.appliedPlan,"Fresh Era preset was not installed")
  equal(Mock.bindings.F6,nil,"Era Optimize installed unavailable Target focus")
  equal(Mock.bindings.W,"MOVEFORWARD"); equal(Mock.bindings.ENTER,"OPENCHAT")
  equal(Mock.bindings.F1,"TARGETSELF")
  for _,write in ipairs(Mock.writes) do
    assert(not (write[1]=="binding" and (write[3]=="TARGETFOCUS" or write[3]=="FOCUSTARGET")),"Era Optimize attempted an unsupported focus binding")
  end
  local backup=k.db.bindingBackups[k.db.lastBindingBackupID]
  assert(backup and backup.complete,"Fresh Era setup did not preserve its baseline")
end

function Tests.command_unsupported_custom_system_action_fails_preflight_before_any_game_write()
  local k=freshEra(); local plan=k:Preview()
  local action={id="test.unsupported.focus",kind="system",key="F6",command="TARGETFOCUS",known=true,label="Unavailable target focus",category="System"}
  plan.actions[#plan.actions+1]=action; plan.system[#plan.system+1]=action
  local account,character=GetNumMacros(); local backups=#k.Engine:ListBackups()
  Mock:ResetWrites()
  local ok,why=k.Engine:Apply(plan)
  assert(not ok and type(why)=="string" and why:find("TARGETFOCUS",1,true) and why:find("F6",1,true),tostring(why))
  equal(#Mock.writes,0,"Unsupported command preflight mutated game state")
  equal(#k.Engine:ListBackups(),backups,"Unsupported command created a transaction backup")
  local afterAccount,afterCharacter=GetNumMacros(); equal(afterAccount,account); equal(afterCharacter,character)
  assert(not k.Engine.busy,"Unsupported command started an asynchronous mutation job")
end
