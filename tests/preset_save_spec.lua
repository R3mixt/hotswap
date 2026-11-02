function Tests.preset_save_overwrite_preserves_identity_and_shortcut_without_duplicates()
 local k=TestAddon; k:Init(); local selected=k.db.activePreset; local original=k.db.presets[selected]
 original.hotkey='F10'; k.db.presetSaveBases[original.id]=k.Copy(original)
 k:GetSettings().primarySchool='fire'; k.Presets:Changed(); assert(k.Presets:HasSaveChanges())
 local id=original.id; local count=#k.Presets:List()
 assert(k.Presets:SaveDraftChoice(selected,true))
 assert(k.db.presets[selected].id==id and k.db.presets[selected].hotkey=='F10' and #k.Presets:List()==count)
 assert(not k.Presets:HasSaveChanges() and k:GetSettings().primarySchool=='fire')
end
function Tests.preset_save_new_restores_original_and_survives_reload()
 local k=TestAddon; k:Init(); local selected=k.db.activePreset; local old=k:GetSettings().primarySchool
 k:GetSettings().primarySchool='fire'; k.Presets:Changed(); k:Init()
 assert(k.Presets:HasSaveChanges())
 assert(k.Presets:SaveDraftChoice('My new layout',false))
 assert(k.db.presets[selected].settings.primarySchool==old and k:GetSettings().primarySchool=='fire')
 assert(k.db.activePreset=='My new layout' and not k.db.presets['My new layout'].hotkey)
 local ok=k.Presets:SaveDraftChoice(selected,false); assert(not ok)
end
function Tests.preset_save_recommendation_overwrite_and_cancel_do_not_apply()
 local k=TestAddon; k:Init(); k.UI:Open(); local selected=k.db.activePreset; local id=k.db.presets[selected].id
 k.UI:PreviewRecommendations(); local count=#k.Presets:List(); Mock:ResetWrites()
 k.UI:SaveRecommendation(); assert(k.UI.saveDialog:IsShown())
 k.UI.saveDialog.cancel:Click(); assert(#k.Presets:List()==count and #Mock.writes==0)
 k.UI:SaveRecommendation(); k.UI.saveDialog.overwrite:Click()
 assert(k.db.activePreset==selected and k.db.presets[selected].id==id and #k.Presets:List()==count)
 assert(k.UI.bindingSource=='draft' and #Mock.writes==0 and not k.db.enabled)
end
function Tests.preset_apply_edited_draft_prompts_before_saving_and_installing()
 local k=TestAddon; k:Init(); k.UI:Open(); k.UI:SetBindingSource('draft')
 k:GetSettings().primarySchool='fire'; k.Presets:Changed(); Mock:ResetWrites()
 k.UI:UseSelectedPreset(); assert(k.UI.saveDialog:IsShown() and #Mock.writes==0)
 k.UI.saveDialog.cancel:Click(); assert(k.Presets:HasSaveChanges() and #Mock.writes==0)
 Mock:AllowFullCatalogMacros()
 k.UI:UseSelectedPreset(); k.UI.saveDialog.overwrite:Click(); Mock:Drain()
 assert(k.db.enabled and not k.Presets:HasSaveChanges())
end
