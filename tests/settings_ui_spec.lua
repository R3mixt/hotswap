local function settingsUI()
    local k=TestAddon; k:Init(); k.UI:Open(); k.UI.nav.Settings:Click()
    return k,k.UI.pages.Settings
end

function Tests.settings_ui_talent_choices_order_remove_reset_and_escape_are_staged_only()
    local k=settingsUI(); k.UI:ShowPage("Bindings")
    local primary
    for _,action in ipairs(k.UI.plan.actions) do if action.id=="druid.form_moonkin" then primary=action end end
    assert(primary and k.UI:CanEditTalentChoices(primary),"Moonkin utility has no talent-choice editor")
    k:GetSettings().actionOverrides[primary.id]={spellID=24858}
    assert(not k.UI:CanEditTalentChoices(primary),"A fixed-rank binding exposed incompatible talent choices")
    k:GetSettings().actionOverrides[primary.id]={replacement={kind="spell",spellID=24858}}
    assert(not k.UI:CanEditTalentChoices(primary),"A replaced action exposed incompatible talent choices")
    k:GetSettings().actionOverrides[primary.id]=nil
    k.UI.selectedAction=primary; k.UI:BindingDetail(primary); Mock:ResetWrites()
    k.UI.pages.Bindings.detail.talents:Click()
    local f=k.UI.talentDialog
    assert(f and f:IsShown() and f.rows[1].choiceID==primary.id,"Talent choices did not open on the selected key")
    assert(f.mode=="separate" and f.ownInfo:IsShown() and not f.add:IsEnabled() and not f.list:IsShown(),"An unconfigured ability did not start in Own key mode")
    f.modeButtons.shared:Click()
    assert(f.mode=="shared" and f.list:IsShown() and f.add:IsEnabled() and not f.ownInfo:IsShown(),"Shared key mode did not reveal its choices")
    assert(not f.rows[1].remove:IsEnabled(),"The last talent choice could be removed")
    f.add:Click()
    local option
    for _,row in ipairs(k.UI.menu.panel.rows) do if row.text:GetText()=="Nature's Swiftness" then option=row end end
    assert(option,"Nature's Swiftness missing from eligible talent choices")
    option:Click()
    local choices=k.TalentBindings:GetChoices(primary.id)
    assert(#choices==2 and choices[1]==primary.id and choices[2]=="druid.natures_swiftness","Adding a talent did not preserve its ordered choices")
    f.rows[2].up:Click()
    choices=k.TalentBindings:GetChoices(primary.id)
    assert(choices[1]=="druid.natures_swiftness" and choices[2]==primary.id,"Talent choice order did not change")
    f.rows[2].remove:Click()
    choices=k.TalentBindings:GetChoices(primary.id)
    assert(#choices==1 and choices[1]=="druid.natures_swiftness","Primary choice could not be removed")
    f.reset:Click()
    choices=k.TalentBindings:GetChoices(primary.id)
    assert(#choices==1 and choices[1]==primary.id,"Reset did not restore the original primary choice")
    assert(not k:GetSettings().talentAlternatives[primary.id],"Reset retained a configured group that would block future rank or replacement edits")
    assert(f.mode=="separate" and f.ownInfo:IsShown(),"Reset did not return to Own key mode")
    assert(#Mock.writes==0 and k.dirty,"Talent choices applied game changes before Apply & save")
    Mock:KeyDown("ESCAPE"); Mock:Advance(0.1)
    assert(not f:IsShown() and k.UI.frame:IsShown(),"Talent-choice Escape closed the whole addon")
end

function Tests.settings_ui_own_talent_key_retains_independent_overrides_and_opens_primary_rebind()
    local k=settingsUI()
    local primary,other="druid.form_moonkin","druid.natures_swiftness"
    k:UpdateSetting("bindingOverrides",{[primary]="CTRL-9",[other]="CTRL-F12"})
    assert(k.TalentBindings:SetChoices(primary,{primary,other}))
    k.UI:ShowPage("Bindings")
    local chosen
    for _,entry in ipairs(k.UI.plan.actions) do if entry.id==primary then chosen=entry end end
    Mock:ResetWrites(); k.UI:OpenTalentChoices(chosen)
    local f=k.UI.talentDialog
    assert(f.mode=="shared","An existing shared group reopened as Own key")
    f.modeButtons.separate:Click()
    assert(k.TalentBindings:GetMode(primary)=="separate" and not k:GetSettings().talentAlternatives[primary],"Own key did not remove shared choices")
    assert(k:GetSettings().bindingOverrides[primary]=="CTRL-9" and k:GetSettings().bindingOverrides[other]=="CTRL-F12","Switching mode discarded independent custom keys")
    assert(f.note:GetText():find("inactive until learned",1,true),"Own key mode omitted its unavailable-talent behavior")
    f.ownInfo.rebind:Click()
    assert(not f:IsShown() and k.UI.capture:IsShown() and k.UI.captureAction.id==primary,"Change key did not capture only the primary ability")
    Mock:KeyDown("NUMPAD9"); Mock:Advance(0.05)
    assert(k:GetSettings().bindingOverrides[primary]=="NUMPAD9","Own key rebind was not saved in the draft")
    assert(k:GetSettings().bindingOverrides[other]=="CTRL-F12","Own key rebind moved another talent ability")
    assert(k.TalentBindings:GetMode(primary)=="separate" and #Mock.writes==0,"Own key editing configured a group or wrote live game state")
end
function Tests.settings_ui_appearance_is_local_immediate_and_fits_the_keyboard_with_spellbook()
    local k,page=settingsUI(); Mock:ResetWrites()
    page.sectionButtons.Window:Click()
    local exported=k:Export(); local dirty=k.dirty
    assert(k.UI.activePage=="Settings" and k.UI.nav.Settings:GetText()=="Settings","Settings has no usable main tab")
    for _,tab in pairs(k.UI.nav) do
        local x=tab.point[2]
        assert(x+tab:GetWidth()<=k.UI.frame:GetWidth()-20,"Seventh tab exceeds window width")
    end
    page.opacity:SetValue(0.6); page.scale:SetValue(1.3)
    assert(k.db.preferences.windowOpacity==0.6 and k.UI.frame:GetAlpha()==0.6,"Opacity slider did not update the window")
    assert(page.opacity.valueLabel:GetText()=="60%" and page.scale.valueLabel:GetText()=="130%","Appearance sliders omit readable percentages")
    assert(k.db.preferences.windowScale==1.3 and k.UI.actualWindowScale==1.3,"Preferred scale was not applied")
    UIParent:SetSize(1000,700); k.UI:ShowPage("Bindings")
    assert(k.UI.library:IsShown(),"Fit fixture did not include the spellbook")
    assert(k.UI.actualWindowScale*1180<=970.01 and k.UI.actualWindowScale*620<=670.01,"Window scaling exceeded viewport")
    assert(k.db.preferences.windowScale==1.3,"Fitting a small viewport overwrote the preferred scale")
    k.UI.frame:Hide(); k.UI:Open()
    assert(k.UI.frame:GetAlpha()==0.6,"Opening reset opacity")
    k.UI:ShowPage("Settings"); page.resetAppearance:Click()
    assert(k.db.preferences.windowOpacity==1 and k.db.preferences.windowScale==1,"Reset appearance did not restore defaults")
    assert(k:Export()==exported and k.dirty==dirty,"Window preferences contaminated binding presets")
    assert(#Mock.writes==0,"Appearance changed protected game state")
end

function Tests.settings_ui_diagnostics_default_off_copy_and_clear_have_explicit_controls()
    local k,page=settingsUI(); Mock:ResetWrites()
    page.sectionButtons.Diagnostics:Click()
    local exported=k:Export()
    assert(not page.diagnostics:GetChecked() and not k.Diagnostics:IsEnabled(),"Diagnostic logging was enabled by default")
    k.Diagnostics:Record("error","fixture","Should not be recorded")
    assert(k.Diagnostics:Count()==0,"Disabled logging accumulated data")
    page.diagnostics:Click()
    assert(k.Diagnostics:IsEnabled(),"Logging checkbox did not enable diagnostics")
    local text="The client rejected F6 (Target focus; TARGETFOCUS).\n"..string.rep("Technical detail. ",130)
    k.Diagnostics:Record("error","fixture",text,{key="F6",action="Target focus"})
    k.Diagnostics:Record("error","second",text,{key="G",action="Another action"})
    k.SettingsUI:Render(page); page.viewLog:Click()
    local dialog=k.UI.diagnosticLogDialog
    assert(dialog:IsShown() and dialog.text:GetText():find(text,1,true),"Copy view omitted full multiline diagnostic text")
    assert(#dialog.text:GetText()>3000 and dialog.text:GetText()==k.Diagnostics:Export(),"Long log was truncated in its copy field")
    assert(dialog.note:GetText():find("/reload",1,true),"Log view omitted the disk-persistence instruction")
    local scroll=dialog.text.scrollFrame; scroll:SetHeight(100)
    local cursor=dialog.text:GetScript("OnCursorChanged")
    cursor(dialog.text,0,-900,1,14)
    assert(scroll:GetVerticalScroll()==814,"Navigating to a later log line left the caret offscreen")
    cursor(dialog.text,0,0,1,14)
    assert(scroll:GetVerticalScroll()==0,"Navigating back to the first line did not scroll up")
    dialog.copy:Click(); assert(dialog.text:HasFocus(),"Select text did not focus the native copy field")
    Mock:KeyDown("ESCAPE"); Mock:Advance(0.05)
    assert(not dialog:IsShown() and k.UI.frame:IsShown(),"Log Escape closed the addon")
    local count=k.Diagnostics:Count(); page.diagnostics:Click()
    assert(not k.Diagnostics:IsEnabled() and k.Diagnostics:Count()==count,"Disabling logging destroyed existing records")
    page.clearLog:Click()
    assert(k.Diagnostics:Count()==0 and not page.clearLog:IsEnabled(),"Clear log left entries or enabled state behind")
    assert(k:Export()==exported,"Diagnostic preferences or logs leaked into shared presets")
    assert(#Mock.writes==0,"Diagnostic controls changed live game bindings or action bars")
end

function Tests.settings_ui_caught_exceptions_log_once_only_when_enabled_and_keep_the_original_notice()
    local k,page=settingsUI(); local traces=0
    page.sectionButtons.Diagnostics:Click()
    debugstack=function() traces=traces+1; return "UI.lua:272: operation\nDomain.lua:12: rejected" end
    local owner={Fail=function() error("Original UI failure",0) end,Validate=function() return false,"Invalid setting" end}
    k.UI:Call(owner,"Fail","PRIVATE ARGUMENT",{private=true})
    assert(k.Diagnostics:Count()==0 and traces==0,"Disabled diagnostics captured a caught exception")
    assert(k.UI.notice=="Original UI failure","Caught exception lost its original display text")
    page.diagnostics:Click()
    k.UI:Call(owner,"Fail","PRIVATE ARGUMENT",{private=true})
    assert(k.Diagnostics:Count()==1 and traces==1,"Caught exception was not logged exactly once")
    local entry=k.db.diagnostics[1]
    assert(entry.event=="ui-error" and entry.context.operation=="Fail" and entry.context.stage=="UI call","Caught error lost method context")
    assert(entry.message:find("Original UI failure",1,true) and entry.message:find("Stack:",1,true),"Caught error lost its original stack")
    assert(not k.Diagnostics:Export():find("PRIVATE ARGUMENT",1,true),"UI logging retained call arguments")
    assert(k.UI.notice=="Original UI failure","Tracing changed the visible failure")
    local ok,why=k.UI:Call(owner,"Validate")
    assert(ok==false and why=="Invalid setting" and k.Diagnostics:Count()==1,"Ordinary validation created a duplicate exception log")
    k.Diagnostics.Record=function() error("Logger failure") end
    k.UI:Call(owner,"Fail")
    assert(k.UI.notice=="Original UI failure","Logging failure obscured the original UI error")
end

function Tests.settings_ui_control_protections_stage_per_preset_and_spells_only_protects_all_categories()
    Mock.bindings.W="MOVEFORWARD"
    local k,page=settingsUI(); Mock:ResetWrites()
    local keys={"preserveMovement","preserveCamera","preserveChat","preserveInterface","preserveTargeting","preserveGameSettings"}
    assert(page.sections.Controls:IsVisible() and not page.sections.Window:IsVisible(),"Settings did not open its Controls section")
    for _,key in ipairs(keys) do assert(k:GetSettings()[key]==false and not page[key]:GetChecked(),"New protection silently changed an existing preset") end
    local original=k:Export()
    page.preserveMovement:Click()
    assert(k:GetSettings().preserveMovement and k.dirty,"Control checkbox was not staged in this preset")
    assert(k:Export()~=original,"Preset export omitted the protection preference")
    page.spellsOnly:Click()
    for _,key in ipairs(keys) do assert(k:GetSettings()[key] and page[key]:GetChecked(),"Spells only missed "..key) end
    assert(#Mock.writes==0,"Protection settings edited live bindings before Apply")
    k.UI:ShowPage("Bindings")
    local cap=k.UI.pages.Bindings.keyboard.keys.W
    assert(cap.action and cap.action.preserved,"Protected game control disappeared from the keyboard")
    cap:Click()
    assert(not k.UI.capture or not k.UI.capture:IsShown(),"Protected control entered key capture")
    assert(not k.UI.pages.Bindings.detail.rebind:IsEnabled(),"Protected control retained a rebind button")
    local candidate
    for _,action in ipairs(k.UI.plan.actions) do if action.id=="druid.rejuvenation" then candidate=action end end
    assert(candidate and not k.UI:AssignBinding(candidate,"W"),"A spell could replace protected movement")
    assert(not k.UI:AssignBinding(candidate,"F"),"A spell could replace a protected key outside the fixed movement reservations")
    k.UI.libraryEntry={id=candidate.id,actionID=candidate.id,label=candidate.label}
    assert(not k.UI:DropLibraryEntry("F"),"Spellbook drop could replace a protected targeting control")
    assert(Mock.bindings.W=="MOVEFORWARD" and #Mock.writes==0,"Editing the preview changed protected controls")
end

function Tests.settings_ui_local_macro_and_spell_visibility_preserve_presets_and_reserved_keys()
    Mock:SetDefaultDruid()
    local learned={}
    for _,spell in ipairs(Mock.spells) do if spell.id~=24858 and spell.id~=5176 and spell.id~=5177 then learned[#learned+1]=spell end end
    Mock.spells=learned
    local k,page=settingsUI(); page.sectionButtons["Action bars"]:Click(); Mock:ResetWrites()
    local original=k:Export(); local refreshes=0
    k.NativeBars.ApplyMacroTextPreference=function() refreshes=refreshes+1 end
    page.showMacroNames:Click(); page.showMacroCode:Click()
    assert(k.db.preferences.showMacroNames==false and refreshes==1,"Macro-label preference did not refresh native labels")
    assert(k.db.preferences.showMacroCode==false,"Macro-code preference was not stored locally")
    assert(k.UI:MacroDetail({body="/cast PRIVATE",source="Curated",id="fixture"})=="Curated","Hidden macro code remained in tooltip content")
    k.UI:ShowPage("Bindings")
    local primary=k.UI.pages.Bindings.keyboard.keys["1"]
    assert(primary.action and primary.action.known==false and primary.locked,"Unlearned primary fixture was not reserved")
    local position=primary.action.key
    local talent
    for _,action in ipairs(k.UI.plan.actions) do if action.id=="druid.form_moonkin" then talent=action end end
    assert(talent and k.UI:SpellAvailability(talent)=="talent","Unknown talent was not distinguished from normal unlearned abilities")
    k.UI.pinnedLayer="CTRL-"; k.UI:RenderKeyboard()
    local talentCap=k.UI.pages.Bindings.keyboard.keys.MOUSEWHEELUP
    assert(talentCap.lockBadge:GetText()=="T" and talentCap.lockBadge:IsShown(),"Talent reservation did not get its distinct badge")
    k.UI.pinnedLayer=""; k.UI:RenderKeyboard()
    k.UI:ShowPage("Settings"); page.showUnavailableBindings:Click(); k.UI:ShowPage("Bindings")
    primary=k.UI.pages.Bindings.keyboard.keys["1"]
    assert(primary.action.key==position and primary.tag:GetText()=="Reserved" and not primary.icon:IsShown(),"Hiding unavailable abilities moved or exposed their reserved key")
    primary:Click(); assert(not k.UI.capture or not k.UI.capture:IsShown(),"A hidden reserved slot entered an unexpected rebind")
    for _,entry in ipairs(k.UI.library.entries) do assert(not k.UI:IsEditorHidden(entry),"Spellbook ignored unavailable filtering") end
    k.UI.bindingView="list"; k.UI:RenderBindings()
    for _,row in ipairs(k.UI.pages.Bindings.list.rows) do if row:IsShown() then assert(not k.UI:IsEditorHidden(row.action),"Binding list ignored unavailable filtering") end end
    assert(k:Export()==original,"Local display preferences changed the shared preset")
    k.UI:ShowPage("Settings"); page.hideUnavailableSpells:Click(); page.adaptTalents:Click()
    assert(k:GetSettings().hideUnavailableSpells and k:GetSettings().adaptTalents and k.dirty,"Native bar options were not staged")
    assert(#Mock.writes==0,"Visibility edits changed live bars before Apply")
end
