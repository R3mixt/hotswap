-- Full preset replacement and named rollback regression coverage.
local function ready() TestAddon:Init(); return TestAddon end
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b,label)
  for key,value in pairs(a) do equal(b[key],value,(label or "map").."["..tostring(key).."]") end
  for key,value in pairs(b) do equal(a[key],value,(label or "map").." extra["..tostring(key).."]") end
end
local function has(text,needle) return type(text)=="string" and text:find(needle,1,true)~=nil end

function Tests.full_preset_replacement_persists_named_backup_before_any_macro_or_binding_write()
  local k=ready()
  Mock.bindings.BACKSPACE="ACTIONBUTTON12"; Mock.bindings.NUMPADDECIMAL="TOGGLEACHIEVEMENT"
  local original=k.Copy(Mock.bindings)
  local write=Mock.Write; local observed=false
  Mock.Write=function(self,kind,...)
    if kind=="binding" or kind=="createmacro" then
      local entries=k.Engine:ListBackups()
      assert(#entries>0,"Mutation preceded the named backup")
      local entry=k.db.bindingBackups[entries[1].id]
      same(entry.snapshot.bindings,original,"saved pre-write binding map")
      observed=true
    end
    return write(self,kind,...)
  end
  local ok,why=k:Apply(); assert(ok,why)
  assert(observed,"Apply did not exercise protected mutation")
  equal(Mock.bindings.BACKSPACE,nil,"Unused old game binding survived full replacement")
  equal(Mock.bindings.NUMPADDECIMAL,nil,"Unused old numpad binding survived full replacement")
  equal(Mock.bindings.ENTER,"OPENCHAT","Complete replacement removed normal chat")
  equal(Mock.bindings["SHIFT-ENTER"],"OPENCHATSLASH","Complete replacement removed command chat")
  equal(Mock.bindings.BUTTON1,"CAMERAORSELECTORMOVE","Complete replacement removed mouse selection / camera")
  equal(Mock.bindings.BUTTON2,"TURNORACTION","Complete replacement removed right-button turn / interact")
  equal(Mock.bindings.PRINTSCREEN,"SCREENSHOT","Complete replacement removed screenshots")
  local entry=k.Engine:ListBackups()[1]
  assert(entry.name:match("^Tester%-Druid%-"),"Backup lacks Character-Class-Date naming")
  equal(entry.status,"applied","Successful Apply backup status")
end

function Tests.repeated_apply_keeps_distinct_named_backups_and_the_original_baseline()
  local k=ready(); local original=k.Copy(Mock.bindings)
  assert(k:Apply()); local first=k.Engine:ListBackups()[1]
  local installed=k.Copy(Mock.bindings)
  assert(k:Apply()); local list=k.Engine:ListBackups()
  equal(#list,2,"Each activation should save a backup")
  assert(list[1].id~=first.id and list[1].name~=first.name,"Same-second backups are ambiguous")
  equal(list[2].id,first.id,"Backup list is not newest first")
  same(k.db.bindingBackups[list[1].id].snapshot.bindings,installed,"Repeated-apply named snapshot")
  same(k.db.backup.bindings,original,"Original baseline changed after repeated Apply")
end

function Tests.named_backup_restores_original_account_and_character_binding_sets_and_settings()
  local k=ready()
  Mock.bindingSets[1].NUMPADDECIMAL="TOGGLEACHIEVEMENT"
  Mock.bindings=k.Copy(Mock.bindingSets[1])
  local account=k.Copy(Mock.bindingSets[1]); local character=k.Copy(Mock.bindingSets[2])
  local originalModified=k.Copy(Mock.modified); local originalCVars=k.Copy(Mock.cvars)
  assert(k:Apply()); local originalID=k.Engine:ListBackups()[1].id
  k:GetSettings().wheel=false; assert(k:Apply())
  local ok,why=k.Engine:RestoreBackup(originalID); assert(ok,why)
  same(Mock.bindings,account,"Restored original active account map")
  same(Mock.bindingSets[1],account,"Restored account saved set")
  same(Mock.bindingSets[2],character,"Restored character saved set")
  same(Mock.modified,originalModified,"Restored modified clicks")
  same(Mock.cvars,originalCVars,"Restored CVars")
  equal(Mock.bindingSet,1,"Restored active binding-set choice")
  assert(not k.db.enabled and not k.db.appliedPlan,"Non-Hot Swap backup retained active secure layout")
  equal(GetMacroInfo(1),"UserMacro","Restoring deleted a personal macro")
  equal(k.Engine:ListBackups()[1].status,"restored","Restore did not retain an undo backup")
end

function Tests.named_backup_reactivates_the_previous_hot_swap_layout_and_its_settings()
  local k=ready(); assert(k:Apply())
  local firstBindings=k.Copy(Mock.bindings); local firstAction=Mock:NativeActionFor("Q")
  assert(firstAction and firstAction[1]=="macro","Helpful action was not placed on a native bar")
  local _,_,firstMacro=GetMacroInfo(firstAction[2])
  k:GetSettings().wheel=false; assert(k:Apply())
  local previousID=k.Engine:ListBackups()[1].id
  assert(not k.db.appliedPlan.settings.wheel,"Changed-layout fixture failed")
  local ok,why=k.Engine:RestoreBackup(previousID); assert(ok,why)
  assert(k.db.enabled and k.db.appliedPlan.settings.wheel,"Restore did not reactivate previous Hot Swap layout")
  assert(not k:GetSettings().wheel,"Restore discarded the preserved hardware draft")
  assert(k.dirty,"Restored hardware draft is falsely shown as applied")
  same(Mock.bindings,firstBindings,"Prior Hot Swap binding map")
  local restoredAction=Mock:NativeActionFor("Q")
  assert(restoredAction and restoredAction[1]=="macro","Previous native action was not restored")
  local _,_,restoredMacro=GetMacroInfo(restoredAction[2])
  equal(restoredMacro,firstMacro,"Previous helpful native action was not restored")
  assert(k.db.backup,"Named restore lost the original baseline")
end

function Tests.named_restore_failure_rolls_back_both_binding_sets_and_previous_secure_layout()
  local k=ready(); assert(k:Apply()); local firstID=k.Engine:ListBackups()[1].id
  k:GetSettings().wheel=false; assert(k:Apply())
  local before=k.Copy(Mock.bindings); local account=k.Copy(Mock.bindingSets[1]); local character=k.Copy(Mock.bindingSets[2])
  local beforePlan=k.Copy(k.db.appliedPlan)
  local real=SetBinding; local rejected=false
  SetBinding=function(key,command,...)
    if not rejected and key=="F" and command=="ASSISTTARGET" then rejected=true; return false end
    return real(key,command,...)
  end
  local ok,why=k.Engine:RestoreBackup(firstID)
  assert(not ok and has(why,"rolled back"),tostring(why))
  assert(rejected,"Restore failure injection did not execute")
  same(Mock.bindings,before,"Failed restore active bindings")
  same(Mock.bindingSets[1],account,"Failed restore account bindings")
  same(Mock.bindingSets[2],character,"Failed restore character bindings")
  assert(k.db.enabled,"Restore failure disabled the prior layout")
  equal(k.db.appliedPlan.settings.wheel,beforePlan.settings.wheel,"Restore failure changed the active plan")
  equal(GetMacroInfo(1),"UserMacro","Restore rollback deleted personal macro")
end

function Tests.named_restore_preflight_rejects_full_macro_banks_without_mutation()
  local k=ready(); assert(k:Apply()); assert(k:Apply())
  local appliedID=k.Engine:ListBackups()[1].id
  assert(k:Restore())
  for i=1,150 do Mock.macros[i]={name="Personal"..i,icon=1,body="/say personal "..i} end
  Mock:ResetWrites(); local count=#k.Engine:ListBackups()
  local ok,why=k.Engine:RestoreBackup(appliedID)
  assert(not ok and has(why,"macro slots"),tostring(why))
  equal(#Mock.writes,0,"Restore macro preflight changed game state")
  equal(#k.Engine:ListBackups(),count,"Rejected restore created an unusable undo transaction")
end

function Tests.named_restore_recreates_missing_generated_macros_without_replacing_personal_edits()
  local k=ready(); assert(k:Apply()); assert(k:Apply())
  local appliedID=k.Engine:ListBackups()[1].id
  local owned=next(k.db.ownedMacros); local index=GetMacroIndexByName(owned)
  EditMacro(index,nil,nil,"/say personal edited copy")
  assert(k:Restore())
  local ok,why=k.Engine:RestoreBackup(appliedID); assert(ok,why)
  assert(k.db.enabled,"Restored snapshot did not rebuild its secure layout")
  local edited=GetMacroIndexByName(owned)
  local _,_,body=GetMacroInfo(edited)
  equal(body,"/say personal edited copy","Restore overwrote a user's edited macro")
  equal(GetMacroInfo(1),"UserMacro","Restore overwrote original personal macro")
end

function Tests.binding_command_labels_are_human_readable_and_backup_restore_is_combat_guarded()
  local k=ready()
  equal(k.API:BindingLabel("ACTIONBUTTON1"),"Action bar 1, button 1","Native action binding label")
  equal(k.API:BindingLabel("MULTIACTIONBAR2BUTTON7"),"Action bar 3, button 7","Additional action binding label")
  equal(k.API:BindingLabel("ASSISTTARGET"),"Assist target","Native targeting binding label")
  assert(k:Apply()); local id=k.Engine:ListBackups()[1].id
  Mock.combat=true; Mock:ResetWrites()
  assert(not k.Engine:RestoreBackup(id),"Named backup restored during combat")
  equal(#Mock.writes,0,"Combat restore mutated protected state")
end

function Tests.named_backup_from_character_bindings_preserves_inactive_account_bindings()
  local k=ready(); LoadBindings(2)
  local account=k.Copy(Mock.bindingSets[1]); local character=k.Copy(Mock.bindingSets[2])
  assert(k:Apply()); local id=k.Engine:ListBackups()[1].id
  local entry=k.db.bindingBackups[id]
  same(entry.snapshot.accountBindings,account,"Inactive account snapshot")
  same(entry.snapshot.characterBindings,character,"Active character snapshot")
  local ok,why=k.Engine:RestoreBackup(id); assert(ok,why)
  same(Mock.bindingSets[1],account,"Inactive account restore")
  same(Mock.bindings,character,"Active character restore")
  equal(Mock.bindingSet,2,"Character binding set was not restored")
end

function Tests.original_restore_failure_preserves_installed_layout_and_keeps_recovery_backup()
  local k=ready(); assert(k:Apply())
  local before=k.Copy(Mock.bindings)
  local real=SetBinding; local rejected=false
  SetBinding=function(key,command,...)
    if not rejected and command=="ASSISTTARGET" then rejected=true; return false end
    return real(key,command,...)
  end
  local ok,why=k:Restore()
  assert(not ok and has(why,"rolled back"),tostring(why))
  same(Mock.bindings,before,"Original restore failure rollback")
  assert(k.db.enabled and k.db.backup,"Original restore failure lost installed state")
  equal(k.Engine:ListBackups()[1].status,"failed","Original restore failure lost named recovery entry")
end

function Tests.backup_capture_failure_aborts_apply_and_does_not_offer_partial_restore()
  local k=ready(); local before=k.Copy(Mock.bindings)
  local real=LoadBindings
  LoadBindings=function(set) if set==2 then return false end; return real(set) end
  Mock:ResetWrites()
  local ok,why=k:Apply()
  assert(not ok and has(why,"Could not load binding set 2"),tostring(why))
  same(Mock.bindings,before,"Backup-capture failure active bindings")
  for _,write in ipairs(Mock.writes) do
    assert(write[1]~="createmacro" and write[1]~="deletemacro" and write[1]~="action","Failed backup capture started installing a preset")
  end
  local entry=k.Engine:ListBackups()[1]
  assert(entry and entry.status=="failed","Failed capture lost its diagnostic entry")
  local restored,message=k.Engine:RestoreBackup(entry.id)
  assert(not restored and has(message,"incomplete"),"A partial backup was offered as a complete restore")
end

function Tests.backup_restore_preserves_item_draft_and_marks_it_unapplied_against_live_item()
  local k=ready()
  Mock.bagItems[0]={{id=1001},{id=1002}}
  Mock.itemInfo[1001]={name="First Healing Potion",effect="Heal"}
  Mock.itemInfo[1002]={name="Second Healing Potion",effect="Heal"}
  assert(k.Items:Select("potion",1001)); assert(k:Apply())
  assert(k.Items:Select("potion",1002)); assert(k.Presets:Activate("Dungeon"))
  local restoreID=k.Engine:ListBackups()[1].id
  local ok,why=k.Engine:RestoreBackup(restoreID); assert(ok,why)
  equal(k.db.activePreset,"Leveling","Restored editing preset")
  equal(k.db.presets.Leveling.items.potion,1002,"Restoring discarded the preserved item draft")
  local installed
  for _,action in ipairs(k.db.appliedPlan.actions) do if action.id=="item.potion" then installed=action.itemID end end
  equal(installed,1001,"Backup restore silently installed the staged potion")
  assert(k.dirty and k.Presets:HasUnappliedChanges(),"Preserved potion draft is falsely shown as applied")
  assert(has(why,"unapplied"),"Restore feedback does not distinguish saved draft edits")
  k.UI:Open()
  local status=k.UI.status:GetText()
  assert(has(status,"Not in use") or has(status,"unapplied"),"Restored item draft footer falsely reports Active: "..tostring(status))
end

function Tests.backup_restore_preserves_global_hotkey_draft_and_requires_apply_before_using_it()
  local k=ready()
  assert(k.Presets:SetHotkey("PvP","CTRL-SHIFT-F23")); assert(k:Apply())
  local command=Mock.bindings["CTRL-SHIFT-F23"]
  assert(command and command:match("^CLICK KBO_Mode_"),"Original mode-hotkey fixture was not installed")
  assert(k.Presets:SetHotkey("PvP","CTRL-SHIFT-F24")); assert(k.Presets:Activate("Dungeon"))
  local restoreID=k.Engine:ListBackups()[1].id
  local ok,why=k.Engine:RestoreBackup(restoreID); assert(ok,why)
  equal(k.db.presets.PvP.hotkey,"CTRL-SHIFT-F24","Restoring discarded the global hotkey draft")
  equal(Mock.bindings["CTRL-SHIFT-F23"],command,"Backup did not restore the actual old mode hotkey")
  equal(Mock.bindings["CTRL-SHIFT-F24"],nil,"Backup restore silently installed the draft mode hotkey")
  assert(k.dirty and k.Presets:HasUnappliedChanges(),"Preserved hotkey draft is falsely shown as applied")
  k.UI:Open()
  local status=k.UI.status:GetText()
  assert(has(status,"Not in use") or has(status,"unapplied"),"Restored hotkey draft footer falsely reports Active: "..tostring(status))
  local backups=#k.Engine:ListBackups()
  assert(k.Presets:Activate("Leveling"))
  assert(#k.Engine:ListBackups()>backups,"Reusing active preset skipped the unapplied hotkey draft")
  equal(Mock.bindings["CTRL-SHIFT-F24"],command,"Applying after restore did not install the preserved hotkey draft")
  equal(Mock.bindings["CTRL-SHIFT-F23"],nil,"Applying the hotkey draft retained the obsolete hotkey")
end

function Tests.backup_restore_preserves_binding_draft_separately_from_installed_action_map()
  local k=ready(); assert(k:Apply())
  local original=Mock.bindings.Q
  k:UpdateSetting("bindingOverrides",{["druid.rejuvenation"]="U"})
  assert(k.Presets:Activate("Dungeon"))
  local restoreID=k.Engine:ListBackups()[1].id
  local ok,why=k.Engine:RestoreBackup(restoreID); assert(ok,why)
  equal(k.db.settings.bindingOverrides["druid.rejuvenation"],"U","Restoring discarded a staged binding edit")
  equal(Mock.bindings.Q,original,"Restoring changed the saved installed key to its draft")
  equal(Mock.bindings.U,nil,"Restoring installed the unapplied binding draft")
  assert(k.dirty and k.Presets:HasUnappliedChanges(),"Preserved binding draft is falsely shown as active")
end
