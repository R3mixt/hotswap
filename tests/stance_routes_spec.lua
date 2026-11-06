-- Form/stance/aura bars use GetShapeshiftFormInfo indices, not action slots.
local druidForms={
 {id=783,name="Travel Form",icon=1001},{id=5487,name="Bear Form",icon=1002},
 {id=768,name="Cat Form",icon=1003},{id=1066,name="Aquatic Form",icon=1004},
 {id=24858,name="Moonkin Form",icon=1005},
}
local function setup(class,forms)
 local k=TestAddon; class=class or "DRUID"; forms=forms or druidForms
 Mock.class=class; Mock.spells={}; Mock.catalog={}; Mock.forms=k.Copy(forms)
 UnitClass=function() return class,class,1 end
 for _,form in ipairs(forms) do Mock:Learn(form.id,form.name) end
 Mock:Learn(5176,"Wrath")
 Mock.bindings={}; Mock.bindingInventory=nil; Mock.actions={[1]={"spell",5176}}
 for index in ipairs(forms) do Mock.bindings["CTRL-"..index]="SHAPESHIFTBUTTON"..index end
 GetShapeshiftFormInfo=function(index)
  local form=Mock.forms[index]
  if form then return form.icon,index==2,index~=4,form.id end
 end
 k:Init(); Mock:ResetWrites(); return k
end
local function button(name,index)
 _G[name]={GetID=function() return index end,action=99}
 return _G[name]
end
local function assertStance(action,index,provider)
 local form=Mock.forms[index]
 assert(action and action.stanceSlot==index and action.actionRoute.stanceSlot==index,"Current did not resolve the live stance index")
 assert(action.label==form.name and action.spellID==form.id and action.icon==form.icon,"Current used unrelated spell or action-slot metadata")
 assert(action.builtin=="stance" and action.category=="Forms" and action.known and not action.actionBarError)
 assert(not action.liveSlot and not action.nativeSlot and not action.actionRoute.slot,"Stance index became a normal action slot")
 if provider then assert(action.actionBarProvider==provider,"Incorrect stance button provider") end
end
local function apply(k)
 local ok,why=k.Engine:ApplyCurrentEdits(); assert(ok=="pending",why)
 ok,why=Mock:Drain(); assert(ok,why)
end

function Tests.stance_routes_native_ctrl_one_through_five_show_live_forms_without_action_slot_reads()
 local k=setup(); local reads=0; local original=GetActionInfo
 GetActionInfo=function(...) reads=reads+1; return original(...) end
 local plan=k.CurrentBindings:Build()
 for index=1,5 do assertStance(plan.byKey["CTRL-"..index],index,"Blizzard") end
 assert(plan.byKey["CTRL-2"].active and not plan.byKey["CTRL-4"].castable)
 assert(reads==0 and #Mock.writes==0,"Reading forms inspected or mutated normal action slots")
end

function Tests.stance_routes_verified_native_bartender_and_elvui_clicks_resolve_form_indices()
 local k=setup()
 for _,entry in ipairs({{"StanceButton2","Blizzard"},{"BT4StanceButton2","Bartender4"},{"ElvUI_StanceBarButton2","ElvUI"}}) do
  local frame=button(entry[1],2)
  Mock.bindings={ ["CTRL-1"]="CLICK "..entry[1]..":LeftButton" }; Mock.bindingInventory=nil
  local action=k.CurrentBindings:Build().byKey["CTRL-1"]
  assertStance(action,2,entry[2])
  assert(frame.action==99 and #Mock.writes==0,"Reading a stance rewrote its button")
 end
end

function Tests.stance_routes_effective_click_override_wins_over_conflicting_native_action_command()
 local k=setup(); Mock.bindings={ ["CTRL-1"]="ACTIONBUTTON1" }; Mock.bindingInventory=nil
 button("BT4StanceButton3",3)
 local base=GetBindingAction
 GetBindingAction=function(key,overrides)
  if key=="CTRL-1" and overrides then return "CLICK BT4StanceButton3:LeftButton" end
  return base(key)
 end
 local action=k.CurrentBindings:Build().byKey["CTRL-1"]
 assertStance(action,3,"Bartender4")
 assert(action.command=="ACTIONBUTTON1" and action.effectiveCommand=="CLICK BT4StanceButton3:LeftButton")
 assert(Mock.actions[1][2]==5176 and #Mock.writes==0)
end

function Tests.stance_routes_effective_native_stance_override_wins_over_base_stance()
 local k=setup(); local base=GetBindingAction
 GetBindingAction=function(key,overrides)
  if key=="CTRL-1" and overrides then return "SHAPESHIFTBUTTON3" end
  return base(key)
 end
 local action=k.CurrentBindings:Build().byKey["CTRL-1"]
 assertStance(action,3,"Blizzard")
 assert(action.command=="SHAPESHIFTBUTTON1" and action.effectiveCommand=="SHAPESHIFTBUTTON3" and #Mock.writes==0)
end

function Tests.stance_routes_warrior_stances_use_live_spell_labels_without_druid_assumptions()
 local k=setup("WARRIOR",{{id=71,name="Defensive Stance",icon=2101},{id=2457,name="Battle Stance",icon=2102},{id=2458,name="Berserker Stance",icon=2103}})
 local plan=k.CurrentBindings:Build()
 for index=1,3 do assertStance(plan.byKey["CTRL-"..index],index,"Blizzard") end
 assert(#Mock.writes==0)
end

function Tests.stance_routes_paladin_auras_use_live_spell_labels_without_form_assumptions()
 local k=setup("PALADIN",{{id=7294,name="Retribution Aura",icon=3101},{id=465,name="Devotion Aura",icon=3102},{id=19746,name="Concentration Aura",icon=3103}})
 local plan=k.CurrentBindings:Build()
 for index=1,3 do assertStance(plan.byKey["CTRL-"..index],index,"Blizzard") end
 assert(#Mock.writes==0)
end

function Tests.stance_routes_wrong_click_token_mismatched_or_unreadable_id_never_claims_a_form()
 local k=setup(); local frame=button("StanceButton1",1)
 for _,token in ipairs({"RightButton","HOTKEY","Keybind"}) do
  Mock.bindings={ ["CTRL-1"]="CLICK StanceButton1:"..token }; Mock.bindingInventory=nil
  local action=k.CurrentBindings:Build().byKey["CTRL-1"]
  assert(action.actionBarError and not action.stanceSlot and not action.spellID and not action.liveSlot,"Unsupported stance click token was treated as a form")
 end
 Mock.bindings={ ["CTRL-1"]="CLICK StanceButton1:LeftButton" }; Mock.bindingInventory=nil
 for _,id in ipairs({2,0,-1,1.5,"1",false}) do
  frame.GetID=function() return id end
  local action=k.CurrentBindings:Build().byKey["CTRL-1"]
  assert(action.actionBarError and not action.stanceSlot and not action.liveSlot,"Unverified button ID was treated as a stance")
 end
 frame.GetID=function() error("Unavailable stance ID") end
 assert(k.CurrentBindings:Build().byKey["CTRL-1"].actionBarError)
 Mock.bindings={ ["CTRL-1"]="CLICK UnknownStanceButton1:LeftButton" }; Mock.bindingInventory=nil
 local unknown=k.CurrentBindings:Build().byKey["CTRL-1"]
 assert(not unknown.stanceSlot and not unknown.spellID and not unknown.liveSlot and #Mock.writes==0)
end

function Tests.stance_routes_current_ctrl_layer_refreshes_icons_when_live_forms_change()
 local k=setup(); k.UI:Open(); k.UI.pages.Bindings.layers["CTRL-"]:Click()
 local keys=k.UI.pages.Bindings.keyboard.keys
 for index=1,5 do assertStance(keys[tostring(index)].action,index,"Blizzard"); assert(keys[tostring(index)].icon:IsShown()) end
 Mock.forms[1],Mock.forms[3]=Mock.forms[3],Mock.forms[1]
 Mock:Fire("UPDATE_SHAPESHIFT_FORMS"); Mock:Advance(0.2)
 assertStance(keys["1"].action,1,"Blizzard"); assertStance(keys["3"].action,3,"Blizzard")
 assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end

function Tests.stance_routes_verified_click_rebind_preserves_preview_and_changes_only_key()
 local k=setup(); button("StanceButton2",2)
 Mock.bindings={ ["CTRL-1"]="CLICK StanceButton2:LeftButton" }; Mock.bindingInventory=nil
 local action=k.CurrentBindings:Build().byKey["CTRL-1"]
 assert(k.CurrentBindings:Rebind(action,"F9"))
 assertStance(k.CurrentBindings:EditingView().byKey.F9,2,"Blizzard")
 assert(#Mock.writes==0)
 apply(k)
 assert(GetBindingAction("CTRL-1")=="" and GetBindingAction("F9")=="CLICK StanceButton2:LeftButton")
 assertStance(k.CurrentBindings:Build().byKey.F9,2,"Blizzard")
 assert(Mock.actions[1][2]==5176)
 for _,write in ipairs(Mock.writes) do assert(write[1]~="action" and write[1]~="pickupaction","Moving a form shortcut changed native action slots") end
end

function Tests.stance_routes_rebind_tracks_effective_stance_override_on_new_key()
 local k=setup(); button("BT4StanceButton2",2)
 Mock.bindings={ ["CTRL-1"]="SHAPESHIFTBUTTON1" }; Mock.bindingInventory=nil
 local base=GetBindingAction
 GetBindingAction=function(key,overrides)
  local command=base(key)
  if overrides and command=="SHAPESHIFTBUTTON1" then return "CLICK BT4StanceButton2:LeftButton" end
  return command
 end
 local action=k.CurrentBindings:Build().byKey["CTRL-1"]; assertStance(action,2,"Bartender4")
 assert(k.CurrentBindings:Rebind(action,"F9"))
 assertStance(k.CurrentBindings:EditingView().byKey.F9,2,"Bartender4")
 apply(k)
 assert(GetBindingAction("F9")=="SHAPESHIFTBUTTON1" and GetBindingAction("CTRL-1",true)=="")
 assertStance(k.CurrentBindings:Build().byKey.F9,2,"Bartender4")
end

function Tests.stance_routes_changed_verified_form_button_rejects_stale_rebind_before_backup()
 local k=setup(); local frame=button("StanceButton2",2)
 Mock.bindings={ ["CTRL-1"]="CLICK StanceButton2:LeftButton" }; Mock.bindingInventory=nil
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey["CTRL-1"],"F9"))
 frame.GetID=function() return 3 end
 Mock:ResetWrites(); local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and tostring(why):find("routing",1,true),tostring(why))
 assert(#Mock.writes==0 and #k.Engine:ListBackups()==0 and k.CurrentBindings:HasEdits())
 assert(GetBindingAction("CTRL-1")=="CLICK StanceButton2:LeftButton" and GetBindingAction("F9")=="")
end

function Tests.stance_routes_selection_rejects_changed_form_index_even_when_display_spell_matches()
 local k=setup(); Mock.forms[2]=k.Copy(Mock.forms[1])
 button("StanceButton1",1); button("StanceButton2",2)
 local effective="CLICK StanceButton1:LeftButton"; local base=GetBindingAction
 GetBindingAction=function(key,overrides)
  if key=="CTRL-1" and overrides then return effective end
  return base(key)
 end
 k.UI:Open(); local action=k.CurrentBindings:Build().byKey["CTRL-1"]
 local selected=k.UI:BindingSelectionSnapshot(action)
 assert(selected.stanceSlot==1)
 effective="CLICK StanceButton2:LeftButton"
 local current=k.CurrentBindings:Build().byKey["CTRL-1"]
 assert(current.stanceSlot==2 and current.spellID==action.spellID and current.label==action.label)
 assert(not k.UI:ValidateBindingSelection(action,selected),"A stale stance selection survived because the displayed spell matched")
 assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end

local function legacyNativeRebind()
 local k=setup()
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Build().byKey["CTRL-1"],"F9"))
 local edits=k.CurrentBindings.edits
 for _,route in pairs(edits.expectedRoutes) do route.stanceSlot=nil end
 edits.keyRoutes=nil
 assert(edits.expectedRoutes["CTRL-1"].command=="SHAPESHIFTBUTTON1"
  and edits.expectedRoutes["CTRL-1"].effectiveCommand=="SHAPESHIFTBUTTON1"
  and not edits.expectedRoutes["CTRL-1"].slot)
 return k
end

function Tests.stance_routes_legacy_native_pending_rebind_without_stance_metadata_still_applies()
 local k=legacyNativeRebind(); apply(k)
 assert(GetBindingAction("CTRL-1")=="" and GetBindingAction("F9")=="SHAPESHIFTBUTTON1")
 assertStance(k.CurrentBindings:Build().byKey.F9,1,"Blizzard")
 assert(Mock.actions[1][2]==5176 and not k.CurrentBindings:HasEdits())
end

function Tests.stance_routes_legacy_native_pending_rebind_rejects_changed_expected_command()
 local k=legacyNativeRebind()
 Mock.bindings["CTRL-1"]="SHAPESHIFTBUTTON2"; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits()
 assert(not ok and tostring(why):find("routing",1,true),tostring(why))
 assert(#Mock.writes==0 and #k.Engine:ListBackups()==0 and k.CurrentBindings:HasEdits())
 assert(GetBindingAction("CTRL-1")=="SHAPESHIFTBUTTON2" and GetBindingAction("F9")=="")
end
