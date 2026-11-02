-- Full-catalog transaction fixtures explicitly use synthetic character capacity; capacity tests retain 30.
local function capabilityEngine()
    TestAddon:Init(); Mock:AllowFullCatalogMacros(); return TestAddon
end
local function unsupportedAction(plan,command)
    local action={id="test.command",kind="system",key="CTRL-F24",command=command,known=true,label="Test command",category="System",form="all"}
    plan.actions[#plan.actions+1]=action; plan.system[#plan.system+1]=action
end
local function noFocus(k)
    Mock:SetBindingCommandAvailable("TARGETFOCUS",false)
    Mock:SetBindingCommandAvailable("FOCUSTARGET",false)
    k.API:InvalidateBindingCommands()
end

function Tests.engine_capability_unreadable_registry_aborts_before_snapshot_or_game_writes()
    local k=capabilityEngine(); noFocus(k); local plan=k:Preview()
    local backups=#k.Engine:ListBackups()
    GetNumBindings=nil; k.API:InvalidateBindingCommands(); Mock:ResetWrites()
    local ok,why=k.Engine:Apply(plan)
    assert(not ok and why:find("binding list",1,true),tostring(why))
    assert(#Mock.writes==0 and #k.Engine:ListBackups()==backups and not k.Engine.busy)
end

function Tests.engine_capability_rejects_arbitrary_click_even_when_already_registered()
    local k=capabilityEngine(); local command="CLICK PersonalAddonButton:LeftButton"
    for _,registered in ipairs({false,true}) do
        if registered then assert(SetBinding("F23",command)) end
        k.API:InvalidateBindingCommands(); local plan=k:Preview(); unsupportedAction(plan,command)
        Mock:ResetWrites(); local ok,why=k.Engine:Apply(plan)
        assert(not ok and why:find(command,1,true),tostring(why))
        assert(#Mock.writes==0 and not k.Engine.busy,"An unauthenticated CLICK command started setup")
    end
end

function Tests.engine_capability_rejects_raw_macro_system_command_without_fingerprinted_reference()
    local k=capabilityEngine(); assert(SetBinding("F23","MACRO UserMacro"))
    local plan=k:Preview(); unsupportedAction(plan,"MACRO UserMacro")
    Mock:ResetWrites(); local ok,why=k.Engine:Apply(plan)
    assert(not ok and why:find("MACRO UserMacro",1,true),tostring(why))
    assert(#Mock.writes==0 and not k.Engine.busy)
end

function Tests.engine_capability_allows_authenticated_generated_preset_shortcut()
    local k=capabilityEngine(); assert(k.Presets:Create("Quick choice",true))
    assert(k.Presets:SetHotkey("Quick choice","SHIFT-F24"))
    local id=k.db.presets["Quick choice"].id
    assert(k.Presets:Select("Leveling"))
    local ok,why=k:Apply(); assert(ok,why)
    assert(GetBindingAction("SHIFT-F24")=="CLICK KBO_Mode_"..id..":LeftButton")
end

function Tests.engine_capability_saved_focus_activation_and_named_restore_fail_before_writes()
    local k=capabilityEngine(); assert(k:Apply()); assert(k:Apply())
    local savedPlan=k.Copy(k.db.appliedPlan); local backupID=k.db.lastBindingBackupID
    noFocus(k); Mock:ResetWrites()
    local ok,why=k.Engine:Activate(savedPlan)
    assert(not ok and why:lower():find("focus",1,true),tostring(why))
    assert(#Mock.writes==0 and not k.Engine.busy)
    ok,why=k.Engine:RestoreBackup(backupID)
    assert(not ok and why:lower():find("focus",1,true),tostring(why))
    assert(#Mock.writes==0 and not k.Engine.busy,"Incompatible saved focus layout started restoring")
end

function Tests.engine_capability_original_restore_preserves_personal_macro_and_addon_bindings()
    local k=capabilityEngine()
    assert(SetBinding("F22","MACRO UserMacro")); assert(SetBinding("F23","CLICK PersonalAddonButton:LeftButton"))
    assert(k:Apply())
    local ok,why=k:Restore(); assert(ok,why)
    assert(GetBindingAction("F22")=="MACRO UserMacro","Personal macro binding was gated as a planned command")
    assert(GetBindingAction("F23")=="CLICK PersonalAddonButton:LeftButton","Personal addon binding was gated as a planned command")
end

function Tests.engine_capability_named_restore_authenticates_shortcuts_from_saved_presets()
    local k=capabilityEngine(); assert(k.Presets:Create("Saved utility",true))
    assert(k.Presets:SetHotkey("Saved utility","SHIFT-F24"))
    local id=k.db.presets["Saved utility"].id
    assert(k.Presets:Select("Leveling")); assert(k:Apply()); assert(k:Apply())
    local backupID=k.db.lastBindingBackupID
    assert(k.Presets:Delete("Saved utility")); assert(k:Apply())
    assert(not k.Presets:FindID(id) and GetBindingAction("SHIFT-F24")=="")
    local ok,why=k.Engine:RestoreBackup(backupID); assert(ok,why)
    assert(k.Presets:FindID(id),"Named restore did not restore its saved preset")
    assert(GetBindingAction("SHIFT-F24")=="CLICK KBO_Mode_"..id..":LeftButton")
end
