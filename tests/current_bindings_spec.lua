local function equal(actual,expected,label)
 assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function setup(bindings)
 local k=TestAddon
 assert(k.CurrentBindings,"CurrentBindings module is not loaded")
 Mock.build="1.15.9"; Mock.class="DRUID"; Mock.spells={}; Mock.catalog={}; Mock.actions={}
 Mock.bindings=k.Copy(bindings); Mock.bindingInventory=nil
 -- A live reader must never load the conflicting saved set to build its view.
 Mock.bindingSets={[1]={F="OPENCHAT",["1"]="ACTIONBUTTON9"},[2]={F="TARGETSELF"}}
 KeybindOptimizerDB=nil; k.db=nil; k.plan=nil
 k.Planner.Build=function() error("Live view consulted recommendations") end
 Mock:ResetWrites()
 return k
end
local function learn(id,name)
 Mock:Learn(id,name); Mock.catalog[id]={id=id,name=name,icon=id}
end
local function noWrites(k)
 equal(#Mock.writes,0,"Current binding display wrote game state")
 assert(not k.db and not KeybindOptimizerDB,"Live view initialized or modified preset state")
end

function Tests.current_bindings_uses_unsaved_keys_and_all_aliases_without_recommended_or_unbound_spells()
 local k=setup({["1"]="ACTIONBUTTON1",["SHIFT-1"]="ACTIONBUTTON1",["CTRL-1"]="ACTIONBUTTON1",
  F="ASSISTTARGET",W="MOVEFORWARD",BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION",
  ["CTRL-BUTTON4"]="TURNORACTION"})
 learn(5176,"Wrath"); learn(5185,"Healing Touch")
 Mock.catalog[768]={id=768,name="Cat Form",icon=768} -- Future catalog knowledge is not a binding.
 Mock.actions[1]={"spell",5176}; BINDING_NAME_ASSISTTARGET="Assist current target"
 local plan=k.CurrentBindings:Build()
 assert(plan.isCurrent and plan.readOnly)
 equal(plan.byKey["1"].spellID,5176); equal(plan.byKey["SHIFT-1"].spellID,5176)
 equal(plan.byKey["CTRL-1"].spellID,5176)
 equal(plan.byKey.F.label,"Assist current target"); equal(plan.byKey.W.label,"Move forward")
 equal(plan.byKey.BUTTON1.command,"CAMERAORSELECTORMOVE")
 equal(plan.byKey.BUTTON2.command,"TURNORACTION")
 equal(plan.byKey["CTRL-BUTTON4"].command,"TURNORACTION")
 equal(#plan.actions,8)
 for _,a in ipairs(plan.actions) do
  assert(a.current and a.readOnly and a.form=="all")
  assert(a.spellID~=5185 and a.spellID~=768,"An unbound learned/future spell leaked in from the catalog")
 end
 noWrites(k)
end

function Tests.current_bindings_empty_native_slot_stays_empty_and_binding_probe_wins_stale_enumeration()
 local k=setup({["1"]="ACTIONBUTTON1",["2"]="ACTIONBUTTON2",Q="OPENCHAT"})
 learn(5176,"Wrath"); Mock.actions[1]={"spell",5176}
 local get=GetBinding
 GetBinding=function(index)
  local command,category,a,b,c=get(index)
  if command=="OPENCHAT" then return command,category,"Q" end
  return command,category,a,b,c
 end
 local action=GetBindingAction
 GetBindingAction=function(key) if key=="Q" then return "" end return action(key) end
 local plan=k.CurrentBindings:Build(); local empty=plan.byKey["2"]
 assert(empty and empty.liveEmpty); equal(empty.label,"Empty action slot")
 assert(not empty.icon and not empty.displayIcon and not empty.spellID,"Empty slot displayed recommended metadata")
 assert(not plan.byKey.Q,"A removed unsaved binding survived the authoritative key probe")
 noWrites(k)
end

function Tests.current_bindings_main_page_follows_native_bonus_manual_and_override_state()
 local k=setup({["1"]="ACTIONBUTTON1"})
 for _,id in ipairs({101,102,103,104}) do learn(id,"Spell "..id) end
 Mock.actions[1]={"spell",101}; Mock.actions[73]={"spell",102}
 Mock.actions[13]={"spell",103}; Mock.actions[181]={"spell",104}
 GetBonusBarOffset=function() return 1 end
 local plan=k.CurrentBindings:Build(); equal(plan.actionPage,7); equal(plan.byKey["1"].spellID,102)
 Mock.actionPage=2
 plan=k.CurrentBindings:Build(); equal(plan.actionPage,2); equal(plan.byKey["1"].spellID,103)
 Mock.actionPage=1
 ActionButton1=CreateFrame("Button"); ActionButton1.action=73
 C_ActionBar.HasVehicleActionBar=function() return true end
 C_ActionBar.GetVehicleBarIndex=function() return 16 end
 plan=k.CurrentBindings:Build(); equal(plan.actionPage,16)
 equal(plan.byKey["1"].spellID,104,"Stale normal-button action overrode the active vehicle bar")
 C_ActionBar.HasVehicleActionBar=function() return false end
 GetBonusBarOffset=nil
 plan=k.CurrentBindings:Build(); equal(plan.byKey["1"].liveSlot,73,"Effective native button action was ignored")
 noWrites(k)
end

function Tests.current_bindings_all_extra_bar_commands_resolve_actual_native_pages()
 local bindings={}; for index=1,7 do bindings["F"..index]="MULTIACTIONBAR"..index.."BUTTON1" end
 local k=setup(bindings)
 for index,slot in ipairs({61,49,25,37,145,157,169}) do learn(200+index,"Extra "..index); Mock.actions[slot]={"spell",200+index} end
 local plan=k.CurrentBindings:Build()
 for index,slot in ipairs({61,49,25,37,145,157,169}) do
  equal(plan.byKey["F"..index].nativeSlot,slot); equal(plan.byKey["F"..index].label,"Extra "..index)
 end
 noWrites(k)
end

function Tests.current_bindings_pet_and_stance_commands_read_live_slots_without_assuming_pet_layout()
 local k=setup({["CTRL-1"]="BONUSACTIONBUTTON1",["CTRL-2"]="BONUSACTIONBUTTON2",
  ["CTRL-3"]="BONUSACTIONBUTTON3",["SHIFT-1"]="SHAPESHIFTBUTTON1"})
 learn(17253,"Bite"); learn(768,"Cat Form")
 PET_ACTION_ATTACK="Attack"; PET_ACTION_ATTACK_TEXTURE="Interface\\Icons\\Ability_GhoulFrenzy"
 GetPetActionInfo=function(index)
  if index==1 then return "PET_ACTION_ATTACK","PET_ACTION_ATTACK_TEXTURE",true,true,false,false,nil end
  if index==2 then return "Bite",17253,false,false,true,true,17253 end
 end
 GetShapeshiftFormInfo=function(index) if index==1 then return 768,true,true,768 end end
 local plan=k.CurrentBindings:Build()
 equal(plan.byKey["CTRL-1"].label,"Attack"); equal(plan.byKey["CTRL-1"].icon,PET_ACTION_ATTACK_TEXTURE)
 equal(plan.byKey["CTRL-2"].spellID,17253); equal(plan.byKey["CTRL-2"].petSlot,2)
 assert(plan.byKey["CTRL-2"].autoCastEnabled)
 assert(plan.byKey["CTRL-3"].liveEmpty); equal(plan.byKey["CTRL-3"].label,"Empty pet action slot")
 equal(plan.byKey["SHIFT-1"].spellID,768); equal(plan.byKey["SHIFT-1"].label,"Cat Form")
 noWrites(k)
end

function Tests.current_bindings_personal_macros_items_and_unfamiliar_commands_preserve_live_identity()
 local k=setup({["1"]="ACTIONBUTTON1",Q="MACRO Z personal",["2"]="ACTIONBUTTON2",G="CUSTOM_GAME_CONTROL"})
 local id=CreateMacro("Z personal",777,"/say This is personal",true)
 Mock.actions[1]={"macro",id}; Mock.actions[2]={"item",5512}
 Mock.itemInfo[5512]={name="Minor Healthstone"}
 GetBindingText=function(command) if command=="CUSTOM_GAME_CONTROL" then return "My game control" end return command end
 Mock:ResetWrites()
 local plan=k.CurrentBindings:Build(); local original=plan.byKey["1"].id
 equal(plan.byKey["1"].macroName,"Z personal"); equal(plan.byKey.Q.macroName,"Z personal")
 equal(plan.byKey["1"].macroFingerprint,k.Macros:Name("/say This is personal"))
 assert(not plan.byKey["1"].body,"Live view copied executable macro text into an editable action")
 equal(plan.byKey["2"].itemID,5512); equal(plan.byKey["2"].label,"Minor Healthstone")
 equal(plan.byKey.G.label,"My game control")
 noWrites(k)
 CreateMacro("A earlier",778,"/say Reorders the bank",true)
 EditMacro(GetMacroIndexByName("Z personal"),"Z personal",779,"/say Edited personal text")
 Mock:ResetWrites()
 plan=k.CurrentBindings:Build(); equal(plan.byKey["1"].id,original)
 equal(plan.byKey["1"].macroIndex,GetMacroIndexByName("Z personal"))
 equal(plan.byKey["1"].macroFingerprint,k.Macros:Name("/say Edited personal text"))
 equal(plan.byKey["1"].icon,779)
 noWrites(k)
end

function Tests.current_bindings_unreadable_registry_reports_error_without_recommendation_fallback()
 local k=setup({["1"]="ACTIONBUTTON1"})
 learn(5176,"Wrath"); Mock.actions[1]={"spell",5176}
 GetNumBindings=function() error("Client registry unavailable") end
 local plan=k.CurrentBindings:Build()
 assert(#plan.errors>0); equal(#plan.actions,0)
 assert(plan.isCurrent and plan.readOnly)
 noWrites(k)
end

function Tests.current_bindings_cache_refreshes_only_when_explicitly_invalidated_or_rebuilt()
 local k=setup({F="ASSISTTARGET"})
 local count=0; local get=GetNumBindings
 GetNumBindings=function() count=count+1; return get() end
 local first=k.CurrentBindings:Get(); equal(count,1)
 Mock.bindings.F="OPENCHAT"; Mock.bindingInventory=nil
 equal(k.CurrentBindings:Get(),first); equal(count,1)
 k.CurrentBindings:Invalidate()
 local fresh=k.CurrentBindings:Get(); equal(count,2); equal(fresh.byKey.F.command,"OPENCHAT")
 for _,event in ipairs({"UPDATE_BINDINGS","ACTIONBAR_SLOT_CHANGED","UPDATE_MACROS","PET_BAR_UPDATE","UPDATE_SHAPESHIFT_FORM","GET_ITEM_INFO_RECEIVED"}) do
  assert(k.CurrentBindings.Events[event],"Missing current-view invalidation event "..event)
 end
 noWrites(k)
end

function Tests.current_bindings_owned_macro_labels_use_verified_installed_state_and_preserve_personal_edits()
 local k=setup({T="MULTIACTIONBAR4BUTTON5",["SHIFT-T"]="MACRO KBO_lower",Q="MACRO Personal copy"})
 local body="#showtooltip 13\n/use 13"; local lower="#showtooltip 14\n/use 14"
 local upperIndex=CreateMacro("KBO_upper",1,body,true)
 CreateMacro("KBO_lower",2,lower,true); CreateMacro("Personal copy",3,body,true)
 -- Creation can reorder the macro bank; native slots use the latest index.
 Mock.actions[41]={"macro",GetMacroIndexByName("KBO_upper")}
 k.db={enabled=true,ownedMacros={KBO_upper=body,KBO_lower=lower},appliedPlan={actions={
  {id="item.trinket1",macroName="KBO_upper",body=body,itemSlot=13,nativeSlot=41,label="Upper trinket",icon=101},
  {id="item.trinket2",macroName="KBO_lower",body=lower,itemSlot=14,label="Lower trinket",icon=102},
 }}}
 k.plan={actions={{id="item.trinket1",label="Unapplied draft label",icon=999}}}
 GetActionTexture=function(slot) if slot==41 then return 555 end end
 Mock:ResetWrites()
 local plan=k.CurrentBindings:Build()
 equal(plan.byKey.T.label,"Trinket 1"); equal(plan.byKey.T.icon,555,"Live native icon lost to saved metadata")
 equal(plan.byKey["SHIFT-T"].label,"Trinket 2"); equal(plan.byKey["SHIFT-T"].icon,102)
 equal(plan.byKey.Q.label,"Personal copy","Matching personal body acquired a generated label")
 equal(#Mock.writes,0)
 EditMacro(GetMacroIndexByName("KBO_upper"),"KBO_upper",777,"/say This is now my macro")
 Mock:ResetWrites()
 plan=k.CurrentBindings:Build(); equal(plan.byKey.T.label,"KBO_upper","Edited generated macro retained stale friendly label")
 equal(plan.byKey.T.macroFingerprint,k.Macros:Name("/say This is now my macro"))
 equal(#Mock.writes,0)
 k.db.enabled=false
 plan=k.CurrentBindings:Build(); equal(plan.byKey["SHIFT-T"].label,"KBO_lower","Disabled installed plan supplied a friendly label")
 equal(#Mock.writes,0)
end
