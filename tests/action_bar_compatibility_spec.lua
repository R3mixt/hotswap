local function setup()
 local k=TestAddon
 Mock.class="MAGE"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 UnitClass=function() return "Mage","MAGE",8 end
 Mock:Learn(133,"Fireball"); Mock:Learn(116,"Frostbolt")
 Mock.bindings={MOUSEWHEELUP="ACTIONBUTTON1",F="OPENCHAT"}; Mock.bindingInventory=nil
 Mock.actions={[1]={"spell",116},[73]={"spell",133},[74]={"spell",116}}
 k:Init(); Mock:ResetWrites()
 return k
end
local function bartender(k,fixed)
 local state={slot=73,kind="action",command="CLICK BT4Button7:Keybind"}
 BT4Button7={action=7,GetAction=function() return state.kind,state.slot end}
 local base=GetBindingAction
 GetBindingAction=function(key,overrides)
  if overrides and (fixed and key=="MOUSEWHEELUP" or not fixed and base(key)=="ACTIONBUTTON1") then return state.command end
  return base(key)
 end
 return state
end
local function apply(k)
 local result,why=k.Engine:ApplyCurrentEdits(); assert(result=="pending",why)
 local ok,message=Mock:Drain(); assert(ok,message)
end
function Tests.action_bar_live_override_resolves_lab_state_without_writing_button_or_keys()
 local k=setup(); bartender(k)
 local a=k.CurrentBindings:Build().byKey.MOUSEWHEELUP
 assert(a.command=="ACTIONBUTTON1" and a.liveCommand=="ACTIONBUTTON1")
 assert(a.effectiveCommand=="CLICK BT4Button7:Keybind" and a.liveSlot==73 and a.spellID==133)
 assert(a.actionBarProvider=="Bartender4" and BT4Button7.action==7 and #Mock.writes==0)
end
function Tests.action_bar_elvui_registered_extra_bar_uses_live_button_state()
 local k=setup(); Mock.bindings.F="ELVUIBAR7BUTTON2"
 ElvUI_Bar7Button2={GetAction=function() return "action",73 end}
 local a=k.CurrentBindings:Build().byKey.F
 assert(a.liveSlot==73 and a.actionBarProvider=="ElvUI" and a.spellID==133 and #Mock.writes==0)
end
function Tests.action_bar_dominos_native_hotkey_inherits_parent_slot()
 local k=setup(); Mock.bindings.MOUSEWHEELUP="CLICK ActionButton1Hotkey:HOTKEY"
 ActionButton1={action=1,GetAttribute=function(_,name) if name=="type" then return "action" elseif name=="action" then return 73 end end}
 ActionButton1Hotkey={GetParent=function() return ActionButton1 end,
  GetAttribute=function(_,name) if name=="type" then return "action" elseif name=="useparent-action" then return true end end}
 local a=k.CurrentBindings:Build().byKey.MOUSEWHEELUP
 assert(a.liveSlot==73 and a.actionBarProvider=="Dominos" and a.spellID==133)
 ActionButton1Hotkey.GetParent=function() return {} end
 a=k.CurrentBindings:Build().byKey.MOUSEWHEELUP
 assert(not a.liveSlot and a.actionBarError and #Mock.writes==0)
end
function Tests.action_bar_custom_lab_macro_never_uses_stale_action_field_or_edits_override()
 local k=setup(); local state=bartender(k); state.kind="macro"; BT4Button7.action=73
 local a=k.CurrentBindings:Build().byKey.MOUSEWHEELUP
 assert(not a.liveSlot and a.actionBarError and #k.CurrentBindings:TargetModes(a)==1)
 assert(not k.CurrentBindings:StageEntry({spellID=116},"MOUSEWHEELUP"))
 assert(not k.CurrentBindings:Rebind(a,"F9")); assert(not k.CurrentBindings:ClearKey(a))
 assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.action_bar_unknown_override_and_override_only_destination_reject_current_edits()
 local k=setup(); local state=bartender(k); state.command="CLICK OtherAddonButton:LeftButton"
 local a=k.CurrentBindings:Build().byKey.MOUSEWHEELUP
 assert(a.command=="ACTIONBUTTON1" and not a.liveSlot and a.actionBarError)
 assert(not k.CurrentBindings:StageEntry({spellID=116},"MOUSEWHEELUP"))
 local base=GetBindingAction
 GetBindingAction=function(key,overrides) if key=="F9" and overrides then return "CLICK BT4Button7:Keybind" end return base(key,overrides) end
 assert(not k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.F,"F9"))
 assert(not k.CurrentBindings:StageEntry({spellID=116},"F9"))
 assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.action_bar_native_custom_button_type_cannot_fall_back_to_page_number()
 local k=setup(); ActionButton1={action=1,GetAttribute=function(_,name) if name=="type" then return "spell" end end}
 local a=k.CurrentBindings:Build().byKey.MOUSEWHEELUP
 assert(not a.liveSlot and a.actionBarError)
 assert(not k.CurrentBindings:StageEntry({spellID=133},"MOUSEWHEELUP") and #Mock.writes==0)
end
function Tests.action_bar_explicit_invalid_or_unreadable_attribute_never_uses_cached_slot()
 local k=setup()
 for _,value in ipairs({0,-1,1.5,"73",false}) do
  ActionButton1={action=73,GetAttribute=function(_,name) if name=="type" then return "action" elseif name=="action" then return value end end}
  local a=k.CurrentBindings:Build().byKey.MOUSEWHEELUP
  assert(not a.liveSlot and a.actionBarError)
 end
 ActionButton1.GetAttribute=function() error("attribute unavailable") end
 assert(k.CurrentBindings:Build().byKey.MOUSEWHEELUP.actionBarError and #Mock.writes==0)
end
function Tests.action_bar_live_rebind_then_replace_retains_addon_route_and_saved_command()
 local k=setup(); bartender(k)
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.MOUSEWHEELUP,"F9"))
 assert(k.CurrentBindings:EditingView().byKey.F9.liveSlot==73)
 assert(k.CurrentBindings:StageEntry({spellID=116},"F9"))
 apply(k)
 assert(Mock.bindings.F9=="ACTIONBUTTON1" and not Mock.bindings.MOUSEWHEELUP)
 assert(Mock.actions[73][2]==116 and Mock.actions[1][2]==116)
 assert(k.CurrentBindings:Build().byKey.F9.liveSlot==73)
end
function Tests.action_bar_rebind_refuses_changed_source_route_before_backup()
 local k=setup(); local state=bartender(k)
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.MOUSEWHEELUP,"F9"))
 state.slot=74; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find("routing changed") and #Mock.writes==0 and #k.Engine:ListBackups()==0)
end
function Tests.action_bar_replacement_slot_route_changes_without_content_changes_are_rejected()
 local k=setup(); local state=bartender(k); Mock.actions[74]={"spell",133}
 assert(k.CurrentBindings:StageEntry({spellID=116},"MOUSEWHEELUP"))
 state.slot=74; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find("routing changed") and #Mock.writes==0 and #k.Engine:ListBackups()==0)
 assert(Mock.actions[73][2]==133 and Mock.actions[74][2]==133)
end
function Tests.action_bar_legacy_draft_cannot_apply_old_native_slot_under_addon_override()
 local k=setup()
 assert(k.CurrentBindings:StageEntry({spellID=133},"MOUSEWHEELUP"))
 local e=k.CurrentBindings.edits; e.expectedRoutes=nil; e.keyRoutes=nil
 bartender(k); Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find("predate") and #Mock.writes==0 and #k.Engine:ListBackups()==0)
 assert(k.CurrentBindings:HasEdits() and Mock.actions[1][2]==116 and Mock.actions[73][2]==133)
end
function Tests.action_bar_legacy_draft_with_provable_same_slot_still_applies()
 local k=setup(); bartender(k)
 assert(k.CurrentBindings:StageEntry({spellID=116},"MOUSEWHEELUP"))
 local e=k.CurrentBindings.edits; e.expectedRoutes=nil; e.keyRoutes=nil
 apply(k)
 assert(Mock.actions[73][2]==116 and Mock.bindings.MOUSEWHEELUP=="ACTIONBUTTON1")
end
function Tests.action_bar_legacy_rebind_under_override_requires_fresh_review()
 local k=setup(); bartender(k)
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.MOUSEWHEELUP,"F9"))
 local e=k.CurrentBindings.edits; e.expectedRoutes=nil; e.keyRoutes=nil; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and why:find("predate") and #Mock.writes==0 and #k.Engine:ListBackups()==0 and k.CurrentBindings:HasEdits())
end
function Tests.action_bar_staged_direct_spell_rebind_keeps_editable_preview()
 local k=setup(); bartender(k)
 assert(k.CurrentBindings:StageEntry({spellID=133},"F9"))
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:EditingView().byKey.F9,"F8"))
 local action=k.CurrentBindings:EditingView().byKey.F8
 assert(action.spellID==133 and not action.actionBarError and not action.readOnly)
 assert(k.CurrentBindings:StageEntry({spellID=116},"F8"))
 apply(k)
 assert(Mock.bindings.F8=="SPELL Frostbolt" and not Mock.bindings.F9)
end
function Tests.action_bar_stale_override_after_rebind_rolls_back_instead_of_reporting_success()
 local k=setup(); local state=bartender(k,true)
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.MOUSEWHEELUP,"F9"))
 assert(k.Engine:ApplyCurrentEdits()=="pending")
 local ok,why=Mock:Drain()
 assert(not ok and why:find("routing"))
 assert(Mock.bindings.MOUSEWHEELUP=="ACTIONBUTTON1" and not Mock.bindings.F9)
 assert(GetBindingAction("MOUSEWHEELUP",true)==state.command and Mock.actions[73][2]==133)
 assert(k.CurrentBindings:HasEdits())
end
function Tests.action_bar_rebind_waits_for_normal_binding_update_before_verifying_override()
 local k=setup(); local state=bartender(k)
 local routes={MOUSEWHEELUP=state.command}; local refreshed=false
 GetBindingAction=function(key,overrides) return overrides and routes[key] or Mock.bindings[key] or "" end
 local save=SaveBindings
 SaveBindings=function(bindingSet)
  save(bindingSet)
  C_Timer.After(0,function()
   routes={}; for key,command in pairs(Mock.bindings) do if command=="ACTIONBUTTON1" then routes[key]=state.command end end
   refreshed=true; Mock:Fire("UPDATE_BINDINGS")
  end)
 end
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.MOUSEWHEELUP,"F9"))
 apply(k)
 assert(refreshed and GetBindingAction("F9",true)==state.command and GetBindingAction("MOUSEWHEELUP",true)=="")
 assert(Mock.bindings.F9=="ACTIONBUTTON1" and not Mock.bindings.MOUSEWHEELUP)
end
function Tests.action_bar_rebind_rejects_old_override_left_active_even_when_new_key_is_correct()
 local k=setup(); local state=bartender(k)
 local routed=GetBindingAction
 GetBindingAction=function(key,overrides)
  if overrides and key=="MOUSEWHEELUP" then return state.command end
  return routed(key,overrides)
 end
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.MOUSEWHEELUP,"F9"))
 assert(k.Engine:ApplyCurrentEdits()=="pending"); local ok,why=Mock:Drain()
 assert(not ok and why:find("MOUSEWHEELUP") and Mock.bindings.MOUSEWHEELUP=="ACTIONBUTTON1" and not Mock.bindings.F9)
end
function Tests.action_bar_rebind_game_control_onto_stale_override_cannot_report_success()
 local k=setup(); bartender(k,true)
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.F,"MOUSEWHEELUP"))
 assert(k.Engine:ApplyCurrentEdits()=="pending"); local ok,why=Mock:Drain()
 assert(not ok and why:find("routing") and Mock.bindings.F=="OPENCHAT" and Mock.bindings.MOUSEWHEELUP=="ACTIONBUTTON1")
end
function Tests.action_bar_slot_write_failure_recovers_actual_addon_slot_and_personal_macro()
 local k=setup(); bartender(k)
 local id=CreateMacro("Personal",777,"/say untouched",true); Mock.actions[73]={"macro",id}
 k.CurrentBindings:Invalidate(); Mock:ResetWrites()
 assert(k.CurrentBindings:StageEntry({spellID=116},"MOUSEWHEELUP"))
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey.F,"F9"))
 local set=SetBinding
 SetBinding=function(key,command,...) if key=="F9" and command then return false end return set(key,command,...) end
 assert(k.Engine:ApplyCurrentEdits()=="pending"); assert(not Mock:Drain())
 assert(Mock.actions[73][1]=="macro" and GetMacroInfo(Mock.actions[73][2])=="Personal")
 local _,_,body=GetMacroInfo(GetMacroIndexByName("Personal")); assert(body=="/say untouched")
 assert(Mock.actions[1][2]==116 and Mock.bindings.F=="OPENCHAT" and k.CurrentBindings:HasEdits())
end
