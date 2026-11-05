-- Forever/modern clients expose a macro's resolved spell/item through
-- GetActionInfo. The actual macro index remains private to the mock's bar
-- storage, just as it does to callers in game.
local function equal(actual,expected,label)
 assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function initHunter()
 Mock.class="HUNTER"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 Mock:Learn(75,"Auto Shot")
 TestAddon:Init()
 return TestAddon
end
local function modernMacros(rawSpellID)
 local original=GetActionInfo
 GetActionInfo=function(slot)
  local kind,id,subtype=original(slot)
  if kind=="macro" then
   local _,_,body=GetMacroInfo(id)
   if body and body:find("/cast",1,true) then return "macro",rawSpellID or 75,"spell" end
   if body and body:find("/use",1,true) then return "macro",slot-1,"item" end
  end
  return kind,id,subtype
 end
 C_ActionBar.GetActionText=function(slot)
  local action=Mock.actions[slot]
  if action and action[1]=="macro" then return GetMacroInfo(action[2]) end
 end
end
local function actualMacro(slot)
 local action=Mock.actions[slot]
 assert(action and action[1]=="macro","Expected a macro in slot "..slot)
 return GetMacroInfo(action[2])
end

function Tests.modern_macro_actions_hunter_auto_shot_applies_without_false_verification_failure()
 local k=initHunter(); modernMacros()
 local ok,why=k:Apply(); assert(ok,why)
 local name,_,body=actualMacro(1)
 assert(body:find("/cast !Auto Shot",1,true),"Hunter slot 1 lost non-toggle Auto Shot")
 equal(GetActionInfo(1),"macro"); equal(select(2,GetActionInfo(1)),75)
 equal(k.NativeBars:ReadSlot(1).name,name)
 equal(GetBindingAction("1"),"ACTIONBUTTON1")
 assert(k.db.enabled and k.db.appliedPlan,"Apply did not commit the installed preset")
end

function Tests.modern_macro_actions_spell_and_item_macros_survive_snapshot_restore()
 local k=initHunter()
 local spell=CreateMacro("My shot",1,"#showtooltip Auto Shot\n/cast !Auto Shot",true)
 Mock.actions[1]={"macro",spell}
 local item=CreateMacro("My trinket",2,"#showtooltip 13\n/use 13",true)
 Mock.actions[61]={"macro",item}
 modernMacros()
 local saved=k.NativeBars:Snapshot()
 equal(saved.actions[1].name,"My shot"); equal(saved.actions[61].name,"My trinket")
 k.NativeBars:WriteSlot(1,false); k.NativeBars:WriteSlot(61,false)
 -- Creating another macro may reorder indices before restoration.
 CreateMacro("A later macro",3,"/say unrelated",true)
 k.NativeBars:Restore(saved)
 equal(actualMacro(1),"My shot"); equal(actualMacro(61),"My trinket")
 equal(select(3,actualMacro(61)),"#showtooltip 13\n/use 13")
end

function Tests.modern_macro_actions_later_binding_failure_rolls_back_original_macros()
 local k=initHunter()
 local item=CreateMacro("Original item",2,"#showtooltip 13\n/use 13",true)
 Mock.actions[1]={"macro",item}
 local spell=CreateMacro("Original shot",1,"#showtooltip Auto Shot\n/cast Auto Shot",true)
 Mock.actions[61]={"macro",spell}
 modernMacros()
 local original=SetBinding; local rejected=false
 SetBinding=function(key,command,...)
  if not rejected and key=="1" and command=="ACTIONBUTTON1" then rejected=true; return false end
  return original(key,command,...)
 end
 local ok,why=k:Apply()
 assert(rejected,"Apply never reached the injected binding failure: "..tostring(why))
 assert(not ok and why:find("rolled back",1,true),tostring(why))
 equal(actualMacro(1),"Original item"); equal(actualMacro(61),"Original shot")
 assert(not k.db.enabled and not GetCursorInfo(),"Rollback left applied state or an occupied cursor")
end

function Tests.modern_macro_actions_resolved_spell_id_cannot_select_unrelated_macro_index()
 local k=initHunter()
 local index=CreateMacro("Actual shot",1,"/cast Auto Shot",true)
 Mock.actions[1]={"macro",index}
 modernMacros(1) -- Index 1 belongs to UserMacro, not the action in this slot.
 local saved=k.NativeBars:Snapshot()
 equal(saved.actions[1].name,"Actual shot")
 equal(saved.actions[1].body,"/cast Auto Shot")
 Mock.bindings["1"]="ACTIONBUTTON1"
 local current=k.CurrentBindings:Build().byKey["1"]
 equal(current.macroName,"Actual shot")
 equal(current.macroFingerprint,k.Macros:Name("/cast Auto Shot"))
end

function Tests.modern_macro_actions_ambiguous_names_refuse_backup_before_game_writes()
 local k=initHunter()
 CreateMacro("Duplicate",1,"/cast Auto Shot",false)
 local index=CreateMacro("Duplicate",2,"/use 13",true)
 Mock.actions[1]={"macro",index}; modernMacros()
 Mock:ResetWrites()
 local ok,why=k:Apply()
 assert(not ok,"Ambiguous macro identity was accepted")
 equal(#Mock.writes,0,"Ambiguous macro backup changed game state")
 equal(select(3,actualMacro(1)),"/use 13")
 assert(tostring(why):lower():find("macro",1,true),tostring(why))
end

function Tests.modern_macro_actions_missing_name_is_occupied_and_blocks_backup()
 local k=initHunter()
 local index=CreateMacro("Unreadable shot",1,"/cast Auto Shot",true)
 Mock.actions[1]={"macro",index}; modernMacros()
 C_ActionBar.GetActionText=function() return nil end
 local read=k.NativeBars:ReadSlot(1)
 assert(read and read.kind=="macro","Unreadable occupied macro was mistaken for an empty slot")
 Mock:ResetWrites()
 local ok,why=k:Apply(); assert(not ok,tostring(why))
 equal(#Mock.writes,0,"Unreadable macro backup changed game state")
 equal(actualMacro(1),"Unreadable shot")
 Mock.bindings["1"]="ACTIONBUTTON1"
 local current=k.CurrentBindings:Build().byKey["1"]
 assert(current.readError and not current.liveEmpty,"Current presented an unreadable macro as empty")
end

function Tests.modern_macro_actions_legacy_macro_indices_remain_supported()
 local k=initHunter(); C_ActionBar.GetActionText=nil; GetActionText=nil
 Mock.actions[1]={"macro",1}
 local saved=k.NativeBars:Snapshot(); equal(saved.actions[1].name,"UserMacro")
 k.NativeBars:WriteSlot(1,false); k.NativeBars:Restore(saved)
 equal(actualMacro(1),"UserMacro")
end

function Tests.modern_macro_actions_global_action_text_fallback_resolves_spell_and_item_macros()
 local k=initHunter()
 local spell=CreateMacro("Global shot",1,"/cast Auto Shot",true)
 Mock.actions[1]={"macro",spell}
 local item=CreateMacro("Global trinket",2,"/use 13",true)
 Mock.actions[2]={"macro",item}; modernMacros()
 GetActionText=C_ActionBar.GetActionText; C_ActionBar.GetActionText=nil
 local saved=k.NativeBars:Snapshot()
 equal(saved.actions[1].name,"Global shot"); equal(saved.actions[2].name,"Global trinket")
 k.NativeBars:WriteSlot(1,false); k.NativeBars:WriteSlot(2,false)
 k.NativeBars:Restore(saved)
 equal(actualMacro(1),"Global shot"); equal(actualMacro(2),"Global trinket")
end

function Tests.modern_macro_actions_current_and_friendly_labels_follow_installed_macro()
 local k=initHunter(); modernMacros()
 local ok,why=k:Apply(); assert(ok,why)
 local current=k.CurrentBindings:Build().byKey["1"]
 equal(current.kind,"macroref"); equal(current.label,"Auto Shot")
 assert(current.known and not current.liveEmpty)
 local button=CreateFrame("CheckButton","ActionButton1",UIParent,"SecureActionButtonTemplate")
 button.action=1; button.Name=button:CreateFontString(nil,"OVERLAY")
 function button:Update() self.Name:SetText(C_ActionBar.GetActionText(self.action)) end
 button:Update(); k.NativeBars:ApplyMacroTextPreference()
 equal(button.Name:GetText(),"Auto Shot")
 button:Update(); equal(button.Name:GetText(),"Auto Shot")
end

function Tests.modern_macro_actions_cleanup_preserves_macro_referenced_on_hidden_bar()
 local k=initHunter(); local body="#showtooltip Auto Shot\n/cast !Auto Shot"
 local name=k.Macros:Name(body); local index=CreateMacro(name,1,body,true)
 k.db.ownedMacros[name]=body; Mock.actions[121]={"macro",index}; modernMacros()
 k.AvailabilityEngine:QueueCleanup({[name]=body}); Mock:Advance(0.016)
 assert(GetMacroIndexByName(name)>0,"Cleanup deleted a macro still used by a hidden bar")
 equal(actualMacro(121),name)
end

function Tests.modern_macro_actions_wrong_placed_macro_still_fails_verification()
 local k=initHunter(); local body="/cast Auto Shot"
 local name="Intended shot"; CreateMacro(name,1,body,true); modernMacros()
 PlaceAction=function(slot) Mock.actions[slot]={"macro",1}; Mock.cursor=nil end
 local ok,why=pcall(k.NativeBars.WriteSlot,k.NativeBars,1,{kind="macro",name=name,body=body})
 assert(not ok and tostring(why):find("verification failed",1,true),"Wrong macro was accepted: "..tostring(why))
 assert(not GetCursorInfo(),"Failed verification left the cursor occupied")
end
