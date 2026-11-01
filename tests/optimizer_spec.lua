function Tests.optimize_preserves_original_draft_and_hardware_but_rebuilds_bindings()
    local k=TestAddon; k:Init()
    k.db.settings.wheel=false; k.db.settings.mouseButtons={BUTTON4=true}
    k.db.settings.bindingOverrides['druid.rejuvenation']='SHIFT-F24'
    k.db.settings.fallbackBindings.stale='CTRL-F23'
    k.db.presets.Leveling.items.potion=456
    k.db.presets.Leveling.equipment[13]=789
    local original=k.db.settings
    local apply=k.Engine.Apply
    k.Engine.Apply=function(_,plan) k.db.enabled=true; k.db.appliedPlan=k.Copy(plan); return true,'done' end
    local ok,why,name=k.Presets:Optimize(); assert(ok,why)
    assert(name=='Optimized Druid' and k.db.activePreset==name)
    assert(k.db.presets.Leveling.settings==original and original.bindingOverrides['druid.rejuvenation']=='SHIFT-F24')
    assert(not next(k.db.settings.bindingOverrides) and not next(k.db.settings.fallbackBindings))
    assert(k.db.settings.wheel==false and k.db.settings.mouseButtons.BUTTON4 and not k.db.settings.mouseButtons.BUTTON5)
    assert(k.db.presets[name].items.potion==456 and k.db.presets[name].equipment[13]==789)
    assert(k.Presets:Optimize()); assert(k.db.activePreset=='Optimized Druid (2)')
    k.Engine.Apply=apply
end

function Tests.optimize_failure_keeps_new_draft_and_restores_original_selection()
    local k=TestAddon; k:Init(); local source=k.db.settings
    local apply=k.Engine.Apply; k.Engine.Apply=function() return false,'injected failure' end
    local ok,why,name=k.Presets:Optimize(); assert(not ok and why:find('injected failure',1,true))
    assert(k.db.activePreset=='Leveling' and k.db.settings==source and k.db.presets[name])
    k.Engine.Apply=apply
    Mock.combat=true; local count=#k.Presets:List()
    assert(not k.Presets:Optimize() and #k.Presets:List()==count)
end

function Tests.optimize_installs_native_layout_with_backup_and_keeps_global_mode_hotkeys()
    local k=TestAddon; k:Init(); k.db.settings.flavor='era'
    k.db.settings.bindingOverrides['druid.rejuvenation']='SHIFT-F24'
    assert(k.Presets:SetHotkey('PvP','SHIFT-F23'))
    local modeID=k.db.presets.PvP.id
    local ok,why,name=k.Presets:Optimize(); assert(ok,why)
    assert(k.db.enabled and k.db.appliedPreset==name and k.db.appliedPlan.nativeLayout)
    assert(k.db.presets.Leveling.settings.bindingOverrides['druid.rejuvenation']=='SHIFT-F24')
    assert(k.db.presets.PvP.hotkey=='SHIFT-F23' and not k.db.presets[name].hotkey)
    assert(Mock.bindings['SHIFT-F23']=='CLICK KBO_Mode_'..modeID..':LeftButton')
    local backup=k.db.bindingBackups[k.db.lastBindingBackupID]
    assert(backup and backup.complete and backup.snapshot.native,'Optimize did not preserve the old native setup')
    assert(not k.Presets:HasUnappliedChanges())
end

function Tests.pending_preset_activation_does_not_claim_success_or_allow_edits()
    local k=TestAddon; k:Init(); Mock.async=true; local original=k.db.settings
    local apply=k.Engine.Apply
    k.Engine.Apply=function(self,plan) self.busy=true; self.testPlan=plan; return 'pending','Installing' end
    local ok=k.Presets:Activate('Dungeon'); assert(ok=='pending')
    assert(k.Presets.activating and k.db.activePreset=='Dungeon' and not k.db.appliedPreset)
    assert(not k:UpdateSetting('wheel',false)); assert(not k.Presets:Select('PvP'))
    assert(not k.Presets:Create('Busy',false)); assert(not k.Presets:Rename('Dungeon','Busy'))
    assert(not k.Presets:Delete('PvP')); assert(not k.Presets:SetHotkey('PvP','SHIFT-F24'))
    assert(not k.Items:Select('potion',456)); assert(not k:Import('KBO1\na\tPvP'))
    k.Engine.busy=false; k:OnApplyComplete(false,'injected failure',k.Engine.testPlan,'apply')
    assert(k.db.activePreset=='Leveling' and k.db.settings==original and not k.Presets.activating)
    k.Engine.Apply=apply
end

function Tests.pending_success_records_signature_only_after_install_completes()
    local k=TestAddon; k:Init(); Mock.async=true
    local apply=k.Engine.Apply; local pending
    k.Engine.Apply=function(self,plan) self.busy=true; pending=plan; return 'pending','Installing' end
    assert(k.Presets:Activate('Dungeon')=='pending')
    assert(not k.db.appliedPresetSignature)
    k.Engine.busy=false; k.db.enabled=true; k.db.appliedPlan=k.Copy(pending)
    k:OnApplyComplete(true,'done',pending,'apply')
    assert(k.db.appliedPreset=='Dungeon' and k.db.appliedPresetSignature==k.Presets:Signature('Dungeon'))
    assert(not k.dirty and not k.Presets.activating)
    k.Engine.Apply=apply
end

function Tests.classic_catalog_reserves_missing_active_and_pet_families_and_excludes_passive_traps()
    local k=TestAddon; k:Init()
    local function indexed(class) local result={}; for _,a in ipairs(k.Profiles:Get(class,'era')) do result[a.id]=a end; return result end
    local hunter=indexed('HUNTER'); assert(hunter['hunter.distracting_shot'])
    local pets=0; for _,a in pairs(hunter) do if a.petSpell then pets=pets+1 end end; assert(pets==14)
    assert(indexed('PALADIN')['paladin.sanctity_aura'])
    assert(not indexed('ROGUE')['rogue.detect_traps'])
    local druid=indexed('DRUID'); assert(not druid['druid.ravage.prowl'])
    assert(druid['druid.ravage.cat'].key=='SHIFT-1' and druid['druid.pounce.cat'].key=='SHIFT-2')
    k.db.settings.flavor='era'
    local plan=k:Preview(); assert(plan.coverage.catalogTotal==54,'Druid catalog family count drifted')
    assert(plan.coverage.catalogKnown+plan.coverage.catalogReserved==54)
end

function Tests.warlock_renamed_spell_ranks_use_one_highest_learned_binding()
    local k=TestAddon; k:Init(); Mock.class='WARLOCK'; Mock.spells={}
    Mock:Learn(6201,'Create Healthstone (Minor)'); Mock:Learn(11730,'Create Healthstone (Major)')
    local plan=k:Preview(); local count=0
    for _,a in ipairs(plan.actions) do
        if a.name and a.name:find('Create Healthstone',1,true) then count=count+1; assert(a.spellID==11730) end
    end
    assert(count==1 and plan.coverage.bound==2,'Renamed rank family created duplicate fallback binds')
end

function Tests.native_pending_macro_metadata_does_not_promote_unknown_spell_knowledge()
    local k=TestAddon; k:Init(); Mock.forms={}
    local a={known=false,nativePending=true,displayName='Moonkin Form',targeting='form',formType='moonkin'}
    local body=k.Macros:Build(a,k.db.settings)
    assert(body=='#showtooltip Moonkin Form\n/cast [noform] !Moonkin Form' and not a.known)
    a.nativeMacro=true; a.body=body
    assert(k.Macros:Budget({actions={a}})==1,'Future native macros were omitted from capacity preflight')
    local combo={known=false,nativePending=true,displayName="Nature's Swiftness",combo={17116,5185}}
    local inactive=k.Macros:Build(combo,k.db.settings)
    assert(inactive and not inactive:find('/cast',1,true),'Incomplete future combo cast its learned component')
    local shift={known=false,nativePending=true,displayName='Cat Form',powerShift=true,targeting='form',formType='cat'}
    local pending=k.Macros:Build(shift,k.db.settings)
    assert(pending:find('[noform]',1,true) and not pending:find('/cancelform',1,true),'Unlearned powershift dropped a current form')
end

function Tests.all_nine_class_future_catalogs_install_on_four_native_extra_bars()
    local k=TestAddon; Mock.async=true
    _G.MultiBar5=nil; _G.MultiBar6=nil; _G.MultiBar7=nil
    local counts={DRUID=54,MAGE=53,WARRIOR=39,ROGUE=32,HUNTER=69,PRIEST=47,PALADIN=52,SHAMAN=48,WARLOCK=69}
    for _,flavor in ipairs({'era','forever'}) do
        for _,class in ipairs(k.Profiles.classes) do
            KeybindOptimizerDB={}; k.db=nil; k:Init(); k.db.settings.flavor=flavor
            Mock.class=class; Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
            for _,def in ipairs(k.Profiles:Get(class,flavor)) do
                local id=def.spellIDs and def.spellIDs[1]
                if id and not def.combo then Mock.catalog[id]={id=id,name=def.name,icon=id} end
            end
            k.API:InvalidateSpellbook(); k:InvalidatePreview()
            local plan=k:Preview()
            assert(#plan.errors==0,class..' '..flavor..': '..tostring(plan.errors[1]))
            assert(plan.coverage.catalogKnown==0 and plan.coverage.catalogReserved==plan.coverage.catalogTotal)
            if flavor=='era' then assert(plan.coverage.catalogTotal==counts[class],class..' family count') end
            for _,a in ipairs(plan.actions) do
                if not a.kind and not a.builtin then
                    assert(a.key and not a.known and a.nativeMacro and a.body,class..' future family not reserved: '..a.id)
                end
            end
            if class=='HUNTER' or class=='WARLOCK' then assert(plan.nativeLayout.overflow>0,'Legacy native overflow was not exercised') end
            assert(k:Apply()=='pending'); local ok,why=Mock:Drain(); assert(ok,class..': '..tostring(why))
            for _,a in ipairs(k.db.appliedPlan.actions) do
                if a.key and a.kind~='system' and (a.body or a.known) and (a.nativeSlot or a.nativeMacro) then
                    local actual=Mock:NativeActionFor(a.key)
                    if a.form=='all' then assert(actual,class..' action not reachable: '..a.id) end
                end
            end
            assert(k:Restore()=='pending'); ok,why=Mock:Drain(); assert(ok,why)
        end
    end
end
