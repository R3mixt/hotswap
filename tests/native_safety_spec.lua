-- These fixtures exercise full catalogs/visible reservations with account overflow explicitly enabled.
local function init() TestAddon:Init(); TestAddon:GetSettings().allowAccountMacros=true; return TestAddon end
function Tests.native_backup_refuses_unsupported_action_types_before_any_mutation()
 local k=init(); Mock.actions[5]={"unsupported-client-action",55}; Mock:ResetWrites()
 local ok,why=k:Apply()
 assert(not ok and why:find("Cannot safely back up",1,true),tostring(why))
 assert(#Mock.writes==0,"Unsupported backup action caused live mutations")
 assert(Mock.actions[5][1]=="unsupported-client-action")
 assert(not k.db.enabled)
end
function Tests.native_setup_refuses_occupied_cursor_without_dropping_the_users_action()
 local k=init(); Mock.cursor={"item",123}; Mock:ResetWrites()
 local ok,why=k:Apply()
 assert(not ok and why:find("cursor",1,true),tostring(why))
 assert(#Mock.writes==0,"Cursor preflight wrote game state")
 assert(Mock.cursor and Mock.cursor[2]==123,"User cursor item was cleared")
end
function Tests.native_slot_failure_releases_only_its_own_cursor_for_rollback()
 local k=init(); local original=PlaceAction
 PlaceAction=function() error("Injected placement failure") end
 local ok,why=pcall(k.NativeBars.WriteSlot,k.NativeBars,1,{kind="spell",id=5176})
 assert(not ok and why:find("Injected placement failure",1,true))
 assert(not GetCursorInfo(),"Failed placement left a cursor that prevents rollback")
 PlaceAction=original
 k.NativeBars:WriteSlot(1,{kind="spell",id=5176})
 assert(select(2,GetActionInfo(1))==5176)
end
function Tests.native_flyout_restore_uses_spellbook_slot_not_flyout_id_as_spell()
 local k=init(); C_SpellBook=nil; Mock.actions[3]={"flyout",88}
 GetNumSpellTabs=function() return 1 end
 GetSpellTabInfo=function() return "General",1,0,1 end
 GetSpellBookItemInfo=function(index) if index==1 then return "FLYOUT",88 end end
 PickupSpellBookItem=function(index,bank)
  assert(index==1 and bank=="spell","Flyout pickup received its ID instead of spellbook position")
  Mock.cursor={"flyout",88}
 end
 local saved=k.NativeBars:Snapshot()
 k.NativeBars:WriteSlot(3,false)
 k.NativeBars:Restore(saved)
 assert(GetActionInfo(3)=="flyout" and select(2,GetActionInfo(3))==88)
end
function Tests.native_macro_references_preserve_user_content_and_consume_no_new_macro_slots()
 local k=init(); local body=select(3,GetMacroInfo(GetMacroIndexByName("UserMacro")))
 local a={id="test.ref",kind="macroref",label="UserMacro",macroName="UserMacro",macroFingerprint=k.Macros:Name(body),key="NUMPAD9",form="all"}
 local plan={class="DRUID",settings=k:GetSettings(),actions={a}}
 assert(k.NativeBars:Prepare(plan))
 assert(not a.body and a.macroIndex==1,"User macro was copied into an owned macro")
 assert(k.Macros:Budget(plan)==0,"Reference consumes generated macro capacity")
 assert(k.NativeBars:Apply(plan))
 local kind,index=GetActionInfo(a.nativeSlot)
 assert(kind=="macro" and index==1)
 EditMacro(GetMacroIndexByName("UserMacro"),nil,nil,"/say changed")
 local ok,why=k.NativeBars:Prepare(plan)
 assert(not ok and why:find("missing or changed",1,true),"Changed macro reference installed without review")
 assert(select(3,GetMacroInfo(GetMacroIndexByName("UserMacro")))=="/say changed","Reference validation overwrote personal content")
end
