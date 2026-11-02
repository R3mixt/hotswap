local function restoreLegacyMouseSets(originalSet)
    local k=TestAddon; k:Init()
    k:GetSettings().allowAccountMacros=true -- Legacy restoration uses the full Druid layout, not a capacity fixture.
    Mock.bindingSet=originalSet; Mock.bindings=k.Copy(Mock.bindingSets[originalSet])
    assert(k:Apply())
    local legacy=k.db.backup; legacy.mouseBindingsVersion=nil
    for _,field in ipairs({"bindings","accountBindings","characterBindings"}) do
        legacy[field].BUTTON1=nil; legacy[field].BUTTON2=nil
    end
    Mock.bindingSets[1].BUTTON1="TARGETSELF"
    Mock.bindingSets[1].BUTTON2="ATTACKTARGET"
    Mock.bindingSets[1].F21="CAMERAORSELECTORMOVE"
    Mock.bindingSets[1].F22=nil
    Mock.bindingSets[2].BUTTON1="OPENCHAT"
    Mock.bindingSets[2].BUTTON2="TOGGLECHARACTER0"
    Mock.bindingSets[2].F21=nil
    Mock.bindingSets[2].F22="TURNORACTION"
    Mock.bindings=k.Copy(Mock.bindingSets[2]); Mock.bindingInventory=nil
    local ok,why=k:Restore(); assert(ok,why)
    assert(Mock.bindingSets[1].BUTTON1=="TARGETSELF","Legacy restore copied character left-click into account settings")
    assert(Mock.bindingSets[1].BUTTON2=="ATTACKTARGET","Legacy restore copied character right-click into account settings")
    assert(Mock.bindingSets[2].BUTTON1=="OPENCHAT","Legacy restore copied account left-click into character settings")
    assert(Mock.bindingSets[2].BUTTON2=="TOGGLECHARACTER0","Legacy restore copied account right-click into character settings")
    assert(Mock.bindingSets[1].F21=="CAMERAORSELECTORMOVE" and not Mock.bindingSets[1].F22,"Account hidden aliases came from another set")
    assert(Mock.bindingSets[2].F22=="TURNORACTION" and not Mock.bindingSets[2].F21,"Character hidden aliases came from another set")
    assert(Mock.bindingSet==originalSet,"Legacy restore selected the wrong binding set")
    assert(Mock.bindings.BUTTON1==Mock.bindingSets[originalSet].BUTTON1)
    assert(Mock.bindings.BUTTON2==Mock.bindingSets[originalSet].BUTTON2)
end

function Tests.legacy_mouse_restore_preserves_each_sets_custom_controls_when_account_active()
    restoreLegacyMouseSets(1)
end

function Tests.legacy_mouse_restore_preserves_each_sets_custom_controls_when_character_active()
    restoreLegacyMouseSets(2)
end

local function repairWithNewPersonalMouseEdit(failSave)
    local k=TestAddon; k:Init(); k:GetSettings().allowAccountMacros=true; assert(k:Apply())
    k.db.appliedPlan.mouseBindingsVersion=nil
    Mock.bindings.BUTTON1=nil; Mock.bindings.BUTTON2=nil
    Mock.bindingSets[2].BUTTON1=nil; Mock.bindingSets[2].BUTTON2=nil
    Mock.bindingInventory=nil
    local read=GetBindingAction; local edited=false
    GetBindingAction=function(key)
        if not edited and key=="BUTTON1" and k.Engine.job and k.Engine.job.message=="Restoring missing mouse controls" then
            edited=true; Mock.bindings.BUTTON1="TARGETSELF"; Mock.bindingInventory=nil
        end
        return read(key)
    end
    local save=SaveBindings; local failed=false
    SaveBindings=function(set)
        if failSave and not failed and k.Engine.job and k.Engine.job.message=="Saving mouse controls" then failed=true; return false end
        return save(set)
    end
    Mock.async=true
    local started,why=k.Engine:RepairMouseControls(); assert(started=="pending",why)
    local ok,message=Mock:Drain()
    assert(edited,"The post-backup personal edit was not exercised")
    assert(GetBindingAction("BUTTON1")=="TARGETSELF","Recovery undid the new personal left-click binding")
    assert(Mock.bindingSets[2].BUTTON1=="TARGETSELF","Recovery did not preserve the personal binding on disk")
    local backup=k.db.bindingBackups[k.Engine.lastJob.entry.id]
    assert(backup.snapshot.bindings.BUTTON1==nil,"Recovery rewrote the original snapshot to pretend the later personal edit existed")
    if failSave then
        assert(failed and not ok and message:find("rolled back",1,true),tostring(message))
        assert(GetBindingAction("BUTTON2")=="","Rollback retained the addon's partial right-click repair")
    else
        assert(ok,message)
        assert(GetBindingAction("BUTTON2")=="TURNORACTION","Recovery did not repair the still-missing right click")
        assert(k.db.appliedPlan.mouseBindingsVersion==1,"Completed recovery did not mark the legacy layout")
    end
end

function Tests.legacy_mouse_repair_adopts_personal_binding_created_after_backup()
    repairWithNewPersonalMouseEdit(false)
end

function Tests.legacy_mouse_repair_rollback_preserves_personal_binding_created_after_backup()
    repairWithNewPersonalMouseEdit(true)
end
