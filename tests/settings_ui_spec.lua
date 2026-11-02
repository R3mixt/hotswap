local function settingsUI()
    local k=TestAddon; k:Init(); k.UI:Open(); k.UI.nav.Settings:Click()
    return k,k.UI.pages.Settings
end
function Tests.settings_ui_appearance_is_local_immediate_and_fits_the_keyboard_with_spellbook()
    local k,page=settingsUI(); Mock:ResetWrites()
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
