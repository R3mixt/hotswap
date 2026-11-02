local flags={"preserveMovement","preserveCamera","preserveChat","preserveInterface","preserveTargeting","preserveGameSettings"}
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function ready() TestAddon:Init(); return TestAddon end
local function apply(k) local ok,why=k:Apply(); assert(ok,why) end
local function controls()
  local map={E="MOVEFORWARD",Q="OPENCHAT",F="TOGGLECHARACTER0",R="TARGETNEARESTENEMY",G="TURNORACTION",MOUSEWHEELUP="CAMERAZOOMIN",MOUSEWHEELDOWN="CAMERAZOOMOUT"}
  for key,command in pairs(map) do assert(SetBinding(key,command)) end
  return map
end

function Tests.control_protection_is_opt_in_and_round_trips_per_preset()
  local k=ready()
  for _,flag in ipairs(flags) do equal(k:GetSettings()[flag],false,"Default "..flag) end
  for _,flag in ipairs(flags) do k:GetSettings()[flag]=true end
  local payload=k:Export("Leveling")
  for _,flag in ipairs(flags) do equal(k.db.presets.Dungeon.settings[flag],false,"Independent preset "..flag) end
  Mock:ResetWrites(); local ok,why=k:Import(payload); assert(ok,why)
  for _,flag in ipairs(flags) do equal(k:GetSettings()[flag],true,"Imported "..flag) end
  equal(#Mock.writes,0,"Importing protection preferences changed live controls")
end

function Tests.control_protection_reserves_remapped_controls_and_rehomes_automatic_spells()
  local k=ready(); local protected=controls()
  for _,flag in ipairs(flags) do k:GetSettings()[flag]=true end
  local plan=k:Preview(); equal(#plan.errors,0,table.concat(plan.errors,"; "))
  for key in pairs(protected) do assert(not plan.nativeLayout.keys[key],"Preset still assigns protected "..key) end
  local controlled={MOVEFORWARD=true,OPENCHAT=true,TOGGLECHARACTER0=true,TARGETNEARESTENEMY=true,TURNORACTION=true,CAMERAZOOMIN=true,CAMERAZOOMOUT=true}
  for _,action in ipairs(plan.system) do assert(not controlled[action.command],"Protected control default remains in plan: "..action.command) end
  local rehomed={}
  for _,action in ipairs(plan.actions) do
    if action.kind~="system" and action.key then
      assert(not protected[action.key],"Automatic spell overwrote a protected key: "..action.id)
      rehomed[action.id]=action.key
    end
  end
  assert(rehomed["druid.rejuvenation"] and rehomed["druid.rejuvenation"]~="Q","Protected chat key dropped Rejuvenation instead of rehoming it")
  apply(k)
  for key,command in pairs(protected) do equal(GetBindingAction(key),command,"Preserved "..key) end
  for key in pairs(protected) do assert(not k.db.appliedPlan.bindingOwnership[key],"Protected existing control became addon-owned: "..key) end
end

function Tests.control_protection_explicit_pin_to_preserved_key_fails_before_any_game_write()
  local k=ready(); assert(SetBinding("E","MOVEFORWARD"))
  k:GetSettings().preserveMovement=true
  k:GetSettings().bindingOverrides["druid.rejuvenation"]="E"
  local plan=k:Preview()
  assert(#plan.errors>0 and table.concat(plan.errors,"; "):find("E",1,true),"Explicit protected-key conflict was silently reassigned")
  Mock:ResetWrites(); local before=#k.Engine:ListBackups()
  local ok=k:Apply(); assert(not ok,"Explicit pin overwrote preserved movement")
  equal(#Mock.writes,0); equal(#k.Engine:ListBackups(),before)
  equal(GetBindingAction("E"),"MOVEFORWARD")
end

function Tests.control_protection_newly_preserved_owned_camera_keys_are_not_released()
  local k=ready(); apply(k)
  equal(GetBindingAction("ALT-MOUSEWHEELUP"),"CAMERAZOOMIN")
  equal(GetBindingAction("ALT-MOUSEWHEELDOWN"),"CAMERAZOOMOUT")
  assert(k.db.appliedPlan.bindingOwnership["ALT-MOUSEWHEELUP"],"Fixture did not own the prior camera key")
  k:GetSettings().preserveCamera=true; k:GetSettings().wheel=false
  apply(k)
  equal(GetBindingAction("ALT-MOUSEWHEELUP"),"CAMERAZOOMIN","Enabling protection released a currently protected camera key")
  equal(GetBindingAction("ALT-MOUSEWHEELDOWN"),"CAMERAZOOMOUT")
  assert(not k.db.appliedPlan.bindingOwnership["ALT-MOUSEWHEELUP"],"Protected camera key remained owned")
end

function Tests.control_protection_game_settings_keeps_existing_modified_clicks_and_cvars()
  local k=ready(); k:GetSettings().preserveGameSettings=true
  Mock.modified.SELFCAST="CTRL"; Mock.modified.FOCUSCAST="SHIFT"; Mock.cvars.autoSelfCast="1"
  Mock:ResetWrites(); apply(k)
  equal(Mock.modified.SELFCAST,"CTRL"); equal(Mock.modified.FOCUSCAST,"SHIFT"); equal(Mock.cvars.autoSelfCast,"1")
  for _,write in ipairs(Mock.writes) do assert(write[1]~="modified" and write[1]~="cvar","Protected game setting was written during Apply") end
end

function Tests.control_protection_unchecked_game_settings_retains_explicit_alt_setup_behavior()
  local k=ready(); equal(k:GetSettings().preserveGameSettings,false)
  Mock.modified.SELFCAST="CTRL"; Mock.modified.FOCUSCAST="SHIFT"; Mock.cvars.autoSelfCast="1"
  apply(k)
  equal(Mock.modified.SELFCAST,"ALT"); equal(Mock.modified.FOCUSCAST,"NONE"); equal(Mock.cvars.autoSelfCast,"0")
end

function Tests.control_protection_alt_alias_moves_every_linked_form_to_one_compatible_key()
  local k=ready(); assert(SetBinding("ALT-SHIFT-1","TOGGLEWORLDMAP")); k:GetSettings().preserveInterface=true
  local settings=k:GetSettings()
  settings.fallbackBindings["druid.rejuvenation.caster"]="CTRL-F21"
  settings.fallbackBindings["druid.rejuvenation.moonkin"]="CTRL-F22"
  local plan=k:Preview(); equal(#plan.errors,0,table.concat(plan.errors,"; "))
  local selected,count
  count=0
  for _,a in ipairs(plan.actions) do if a.barSlot==6 then
    count=count+1; selected=selected or a.key
    equal(a.key,selected,"Protected Alt alias split a linked form bank")
    equal(plan.fallbackBindings[a.id],selected,"A stale per-form fallback survived linked allocation")
    assert(a.key~="SHIFT-1" and a.selfKey~="ALT-SHIFT-1")
  end end
  equal(count,4,"Fixture did not cover caster, moonkin, cat and bear banks")
  assert(not plan.nativeLayout.keys["ALT-SHIFT-1"])
  apply(k); equal(GetBindingAction("ALT-SHIFT-1"),"TOGGLEWORLDMAP")
end

function Tests.control_protection_pinned_linked_form_conflict_rejects_without_mutation()
  local k=ready(); assert(SetBinding("ALT-SHIFT-1","TOGGLEWORLDMAP"))
  k:GetSettings().preserveInterface=true
  k:GetSettings().bindingOverrides["druid.rejuvenation.caster"]="SHIFT-1"
  Mock:ResetWrites(); local ok,why=k:Apply()
  assert(not ok and why:find("linked position",1,true),tostring(why))
  equal(#Mock.writes,0); equal(#k.Engine:ListBackups(),0)
end

function Tests.control_protection_unreadable_controls_after_registry_cache_refuses_all_writes()
  local k=ready(); k:GetSettings().preserveCamera=true
  local _,readable=k.API:GetBindingCommands(); assert(readable)
  local count,read=GetNumBindings,GetBinding
  local failures={
    function() GetNumBindings=function() error("binding count unreadable") end end,
    function() GetNumBindings=function() return 10001 end end,
    function() GetBinding=function() error("binding entry unreadable") end end,
    function() GetBinding=function() return nil end end,
  }
  for _,breakRead in ipairs(failures) do
    GetNumBindings,GetBinding=count,read; breakRead(); Mock:ResetWrites()
    local called,ok,why=pcall(k.Apply,k)
    assert(called and not ok and type(why)=="string","Unreadable protected controls escaped safe preflight")
    equal(#Mock.writes,0); equal(#k.Engine:ListBackups(),0)
  end
  GetNumBindings,GetBinding=count,read
end

function Tests.control_protection_dynamic_action_names_do_not_define_native_control_categories()
  local k=ready(); CreateMacro("CAMERA_CHAT Damage",1,"/cast Wrath",false)
  assert(SetBinding("F","MACRO CAMERA_CHAT Damage"))
  k:GetSettings().preserveCamera=true; k:GetSettings().preserveChat=true
  for _,command in ipairs({"MACRO CAMERA_CHAT Damage","CLICK CHAT_CAMERA:LeftButton","SPELL CAMERA_CHAT","ITEM CAMERA_CHAT"}) do
    equal(k.Protection:Group(command),nil,"Dynamic action was classified using its user-controlled name")
  end
  local plan=k:Preview(); equal(#plan.errors,0,table.concat(plan.errors,"; "))
  assert(not plan.protectedKeys.F,"A personally named macro was mistaken for a native control")
  assert(plan.nativeLayout.keys.F,"Native control protection unexpectedly reserved a gameplay macro key")
end

function Tests.control_protection_preset_hotkey_rejects_protected_controls_across_modes_and_after_import()
  local k=ready(); assert(SetBinding("F","ASSISTTARGET"))
  -- The selected draft allows optimization, but another saved mode protects F.
  k.db.presets.Dungeon.settings.preserveTargeting=true
  local selected,settings=k.db.activePreset,k.db.settings
  Mock:ResetWrites()
  local ok,why=k.Presets:SetHotkey("PvP","F")
  assert(not ok and why:find("protected control",1,true),tostring(why))
  equal(k.db.presets.PvP.hotkey,nil); equal(k.db.activePreset,selected); assert(k.db.settings==settings)
  equal(#Mock.writes,0)
  local payload="KBO2\nc\tDRUID\nn\tImported protected\ns\tImported protected\tpreserveTargeting\tboolean\ttrue\nh\tImported protected\tF\na\tImported protected"
  ok,why=k:Import(payload); assert(ok,why)
  local plan=k:Preview(); assert(#plan.errors>0 and table.concat(plan.errors,"; "):find("Preset hotkey F",1,true),"Imported protected hotkey silently fell back to another key")
  local modeID="mode."..k.db.presets[k.db.activePreset].id
  for _,a in ipairs(plan.actions) do if a.id==modeID then assert(not a.key,"Protected mode hotkey was allocated a fallback") end end
  equal(k.db.presets[k.db.activePreset].hotkey,"F"); assert(not plan.fallbackBindings[modeID])
  Mock:ResetWrites(); ok=k:Apply(); assert(not ok)
  equal(#Mock.writes,0); equal(#k.Engine:ListBackups(),0); equal(GetBindingAction("F"),"ASSISTTARGET")
end

function Tests.control_protection_uncatalogued_spell_pin_cannot_bypass_protected_key_preflight()
  local k=ready(); assert(SetBinding("F","ASSISTTARGET")); k:GetSettings().preserveTargeting=true
  Mock:Learn(991188,"Uncatalogued ability")
  local plan=k:Preview(); equal(#plan.errors,0,table.concat(plan.errors,"; "))
  local id
  for _,a in ipairs(plan.actions) do if a.spellID==991188 then id=a.id; break end end
  assert(id and id:match("^spell%."),"Fixture did not create a spellbook coverage action")
  k:GetSettings().bindingOverrides[id]="F"
  Mock:ResetWrites(); local ok,why=k:Apply()
  assert(not ok and why:find("Custom key F",1,true),tostring(why))
  equal(#Mock.writes,0); equal(#k.Engine:ListBackups(),0)
  equal(k:GetSettings().bindingOverrides[id],"F","Rejected explicit pin was silently moved")
  equal(GetBindingAction("F"),"ASSISTTARGET")
end
