local function presetInit(allowFixtureOverflow)
    TestAddon:Init()
    -- Only installation scenarios opt in for the all-talents Druid fixture.
    if allowFixtureOverflow then Mock:AllowFullCatalogMacros() end
    Mock:ResetWrites()
    return TestAddon
end

function Tests.full_preset_migration_preserves_legacy_settings_items_and_equipment()
    KeybindOptimizerDB={schema=1,settings={wheel=false,bindingOverrides={['druid.rejuvenation']='U'},mount=123},activePreset='Dungeon',presets={Dungeon={items={potion=456},equipment={[13]=789}},PvP={items={mount=321}}}}
    local k=presetInit()
    assert(k.db.schema==2 and k.db.activePreset=='Dungeon')
    assert(k.db.settings==k.db.presets.Dungeon.settings)
    assert(k.db.settings.wheel==false and k.db.settings.bindingOverrides['druid.rejuvenation']=='U')
    assert(k.db.presets.Dungeon.items.potion==456 and k.db.presets.Dungeon.equipment[13]==789)
    assert(k.db.presets.Dungeon.items.mount==123 and k.db.presets.PvP.settings.mount==321)
    assert(k.db.presets.Leveling.settings~=k.db.presets.Dungeon.settings)
    local id=k.db.presets.Dungeon.id; k:Init(); assert(k.db.presets.Dungeon.id==id,'Initialization changed stable preset ID')
    assert(#Mock.writes==0,'Migrating presets changed game controls')
end

function Tests.full_presets_keep_independent_drafts_and_allow_custom_names()
    local k=presetInit()
    k.db.settings.bindingOverrides['druid.rejuvenation']='U'
    assert(k.Presets:Create('Raid healing',true))
    assert(k.db.settings.bindingOverrides['druid.rejuvenation']=='U')
    k.db.settings.bindingOverrides['druid.rejuvenation']='SHIFT-U'
    assert(k.Items:Select('potion',456))
    assert(k.Presets:Select('Leveling'))
    assert(k.db.settings.bindingOverrides['druid.rejuvenation']=='U')
    assert(k.db.presets['Raid healing'].settings.bindingOverrides['druid.rejuvenation']=='SHIFT-U')
    assert(k.db.presets['Raid healing'].items.potion==456 and not k.db.presets.Leveling.items.potion)
    for i=1,24 do assert(k.Presets:Create('Custom '..i,false)) end
    assert(#k.Presets:List()==28,'Custom preset count is artificially restricted')
    assert(not k.Presets:Create('Custom 1',true))
    assert(not k.Presets:Create(string.rep('x',49),true))
    assert(#Mock.writes==0,'Editing presets changed live game controls')
end

function Tests.preset_rename_keeps_hotkey_button_identity_and_delete_guards()
    local k=presetInit()
    assert(k.Presets:SetHotkey('Leveling','SHIFT-F24'))
    local id=k.db.presets.Leveling.id
    assert(k.Presets:Rename('Leveling','Solo'))
    assert(k.db.presets.Solo.id==id and k.db.activePreset=='Solo')
    local action=k.Presets:Actions()[1]
    assert(action.presetName=='Solo' and action.presetID==id and action.command=='CLICK KBO_Mode_'..id..':LeftButton')
    k.db.enabled=true; k.db.appliedPreset='Solo'
    assert(not k.Presets:Delete('Solo'),'Deleted installed preset')
    assert(k.Presets:Delete('Dungeon'))
end

function Tests.preset_hotkeys_reject_collisions_in_other_modes_and_self_cast()
    local k=presetInit()
    k.db.presets.Dungeon.settings.bindingOverrides['druid.rejuvenation']='SHIFT-F24'
    local ok,why=k.Presets:SetHotkey('Leveling','SHIFT-F24')
    assert(not ok and why:find('Dungeon',1,true),'Hotkey collided with an action in another preset')
    assert(not k.db.presets.Leveling.hotkey)
    assert(not k.Presets:SetHotkey('Leveling','ALT-Q'))
    assert(not k.Presets:SetHotkey('Leveling','ENTER'))
    assert(k.Presets:SetHotkey('Leveling','CTRL-SHIFT-F24'))
    assert(not k.Presets:SetHotkey('PvP','CTRL-SHIFT-F24'))
    assert(k.Presets:ClearHotkey('Leveling'))
end

function Tests.preset_activation_failure_restores_selected_draft_and_combat_is_noop()
    local k=presetInit()
    assert(k.Presets:Create('Draft',false))
    k.db.settings.showBars=false
    local previous=k.db.settings
    local apply=k.Engine.Apply
    k.Engine.Apply=function() return false,'injected failure' end
    local ok,why=k.Presets:Activate('Dungeon')
    assert(not ok and why=='injected failure')
    assert(k.db.activePreset=='Draft' and k.db.settings==previous and k.db.settings.showBars==false)
    k.Engine.Apply=apply
    Mock.combat=true
    assert(not k.Presets:Activate('Dungeon'))
    assert(k.db.activePreset=='Draft' and #Mock.writes==0)
end

function Tests.preset_export_selected_and_import_merge_preserve_live_setup()
    local k=presetInit()
    assert(k.Presets:Create('Raid healing',true))
    k.db.settings.bindingOverrides['druid.rejuvenation']='CTRL-SHIFT-F24'
    k.db.presets['Raid healing'].items.potion=456
    k.db.presets['Raid healing'].equipment[13]=789
    local payload=k:Export('Raid healing')
    assert(payload:match('^KBO2\n') and not payload:find('n\tDungeon\n',1,true))
    k.db.appliedPreset='Leveling'; k.db.enabled=true
    local ok,why=k:Import(payload); assert(ok,why)
    assert(k.db.activePreset=='Raid healing' and k.db.appliedPreset=='Leveling')
    assert(k.Presets:Select('Raid healing (2)'))
    assert(k.db.settings.bindingOverrides['druid.rejuvenation']=='CTRL-SHIFT-F24')
    assert(k.db.presets['Raid healing (2)'].items.potion==456 and k.db.presets['Raid healing (2)'].equipment[13]==789)
    assert(k.db.presets['Raid healing'].id~=k.db.presets['Raid healing (2)'].id)
    assert(#Mock.writes==0,'Import changed live controls')
    local before=#k.Presets:List()
    assert(not k:Import(payload:gsub('c\tDRUID','c\tHUNTER')))
    assert(not k:Import(payload..'\nx\t/run CastSpellByName("Wrath")'))
    assert(#k.Presets:List()==before,'Invalid import partially changed presets')
end

function Tests.legacy_import_migrates_to_full_modes_without_overwriting_current_modes()
    local k=presetInit()
    local ok,why=k:Import('KBO1\ns\twheel\tboolean\tfalse\np\tPvP\tpotion\t456\na\tPvP')
    assert(ok,why)
    assert(k.db.activePreset=='Leveling' and k.db.settings.wheel==true)
    assert(k.Presets:Select('PvP (2)')); assert(k.db.settings.wheel==false)
    assert(k.db.presets['PvP (2)'].items.potion==456)
    assert(k.db.presets.PvP.settings.wheel==true)
    assert(not k:Import('KBO1\nb\tmode.p1\tQ'))
end

function Tests.preset_state_restore_retains_modes_created_after_snapshot()
    local k=presetInit()
    local state=k.Presets:SnapshotState()
    assert(k.Presets:Create('New later',false))
    local id=k.db.presets['New later'].id
    k.Presets:RestoreState(state)
    assert(k.db.presets['New later'].id==id,'Restoring a backup deleted a newer preset')
    assert(k.db.activePreset=='Leveling' and k.db.settings==k.db.presets.Leveling.settings)
end

function Tests.repeated_mode_hotkey_skips_unchanged_layout_but_detects_saved_draft_changes()
    local k=presetInit(true)
    local apply=k.Engine.Apply; local calls=0
    k.Engine.Apply=function(self,plan) calls=calls+1; return apply(self,plan) end
    assert(k.Presets:Activate('Leveling'))
    assert(k.Presets:Activate('Leveling'))
    assert(calls==1,'Repeated unchanged mode activation created another backup')
    k.db.settings.showBars=false
    k.dirty=nil -- Transient dirty flags do not survive a reload.
    assert(k.Presets:Activate('Leveling'))
    assert(calls==2,'Saved draft edits were ignored after a reload')
end

function Tests.initialization_derives_unapplied_drafts_from_saved_preset_signature()
    local k=presetInit(true)
    assert(k:Apply())
    k.dirty=nil; k:Init()
    assert(k.dirty==false and not k.Presets:HasUnappliedChanges(),'Unchanged saved preset was marked unapplied')
    assert(k.Items:Select('potion',1002))
    k.dirty=nil; k:Init()
    assert(k.dirty==true and k.Presets:HasUnappliedChanges(),'Reload hid an unapplied item draft')
    k.db.presets.Leveling.items.potion=nil
    assert(k.Presets:Select('Dungeon'))
    k.dirty=nil; k:Init()
    assert(k.dirty==true,'Reload hid that a different preset is selected for editing')
    assert(k.db.appliedPreset=='Leveling','Reinitializing changed the installed preset')
end
