local function count(map) local n=0; for _ in pairs(map) do n=n+1 end; return n end
function Tests.recommendations_preview_is_ephemeral_and_preserves_selected_custom_draft()
 local k=TestAddon; k:Init()
 k:GetSettings().bindingOverrides['druid.rejuvenation']='SHIFT-F24'
 assert(k.Presets:SetHotkey('Leveling','CTRL-F24'))
 local db,settings=k.db,k:GetSettings()
 local selected,serial,size=k.db.activePreset,k.db.nextPresetID,count(k.db.presets)
 local signature=k.Presets:Signature(selected)
 local cached=k:PreviewCached(); local revision=k.previewRevision; local dirty=k.dirty
 Mock:ResetWrites()
 local plan,snapshot=k.Presets:PreviewRecommendations(); assert(plan,snapshot)
 assert(plan.recommendation and not plan.presetID and not plan.presetName)
 assert(k.db==db and k:GetSettings()==settings and k.db.activePreset==selected)
 assert(k.db.nextPresetID==serial and count(k.db.presets)==size)
 assert(k.Presets:Signature(selected)==signature and k.dirty==dirty)
 assert(k.plan==cached and k.previewRevision==revision and k.previewValid)
 assert(#Mock.writes==0 and not k.Engine.busy and not k.db.lastBindingBackupID)
 assert(not snapshot.id and not snapshot.hotkey and not next(snapshot.settings.bindingOverrides))
 local found=false
 for _,a in ipairs(plan.actions) do if a.id=='mode.'..db.presets[selected].id then found=a.key=='CTRL-F24' end end
 assert(found,'Recommendation lost the existing selected preset hotkey')
end

function Tests.recommendation_preview_failure_restores_draft_and_cache_references()
 local k=TestAddon; k:Init(); local cached=k:PreviewCached()
 local db,settings,revision,dirty=k.db,k:GetSettings(),k.previewRevision,k.dirty
 local build=k.Planner.Build
 k.Planner.Build=function() k.plan={}; k.previewValid=false; k.previewRevision=999; k.playerClass='OTHER'; k.dirty=false; error('preview failure') end
 Mock:ResetWrites()
 local ok,why=k.Presets:PreviewRecommendations()
 k.Planner.Build=build
 assert(not ok and why:find('preview failure',1,true))
 assert(k.db==db and k:GetSettings()==settings and k.plan==cached and k.previewValid)
 assert(k.previewRevision==revision and k.dirty==dirty and k.playerClass=='DRUID')
 assert(#Mock.writes==0)
end

function Tests.recommendation_save_uses_reviewed_snapshot_without_applying_or_overwriting()
 local k=TestAddon; k:Init(); k:GetSettings().wheel=false
 local plan,snapshot=k.Presets:PreviewRecommendations(); assert(plan,snapshot)
 k:GetSettings().wheel=true
 local original=k:GetSettings()
 Mock:ResetWrites()
 local ok,why,name=k.Presets:CreateRecommended('My recommendation',snapshot); assert(ok,why)
 assert(k.db.presets.Leveling.settings==original and original.wheel)
 assert(k:GetSettings().wheel==false and k:GetSettings()~=snapshot.settings)
 assert(name=='My recommendation' and #Mock.writes==0 and not k.db.enabled)
 assert(not k.db.lastBindingBackupID and not k.db.appliedPlan)
 assert(k.Presets:CreateRecommended('My recommendation',snapshot))
 assert(k.db.activePreset=='My recommendation (2)')
 Mock.class='WARLOCK'; assert(not k.Presets:CreateRecommended('Wrong class',snapshot))
 assert(not k.db.presets['Wrong class'])
end
