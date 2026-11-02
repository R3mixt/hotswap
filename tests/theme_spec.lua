-- Appearance changes must stay local and must not turn a visual preference
-- into a binding edit, even when Current already has pending changes.
local function themeAddon(open)
    local k=TestAddon; k:Init()
    if open~=false then k.UI:Open() end
    return k
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a) do if not same(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end

function Tests.theme_defaults_migration_and_validation_keep_existing_preferences()
    local k=TestAddon
    for _,invalid in ipairs({"missing",true,17,{}}) do
        KeybindOptimizerDB={preferences={theme=invalid,windowOpacity=0.7,windowScale=1.2,confirmSwaps=false}}
        k:Init()
        assert(k.Themes:GetID()=="classic","Unknown saved theme did not fall back to Classic")
        assert(k.db.preferences.windowOpacity==0.7 and k.db.preferences.windowScale==1.2 and k.db.preferences.confirmSwaps==false,"Theme migration overwrote independent preferences")
    end
    assert(k.Themes:Set("modern"))
    local before=k.Copy(k.db.preferences)
    for _,invalid in ipairs({"missing",false,23,{}}) do
        assert(k.Themes:Set(invalid)==false,"Invalid theme was accepted")
        assert(k.Themes:GetID()=="modern" and same(before,k.db.preferences),"Invalid theme replaced the user's valid preference")
    end
    assert(k.Themes:Set(nil)==false,"Missing theme was accepted")
end

function Tests.theme_persists_on_reopen_and_init_without_entering_profile_exports()
    local k=themeAddon(false); local exported=k:Export(); local dirty=k.dirty
    Mock:ResetWrites()
    assert(k.Themes:Set("modern"))
    assert(k.db.preferences.theme=="modern","Theme was not saved per character")
    k:Init(); k.UI:Open()
    assert(k.Themes:GetID()=="modern" and k.UI.frame.hotSwapTheme=="modern","First window creation ignored saved theme")
    k.UI.frame:Hide(); k.UI:Open()
    assert(k.Themes:GetID()=="modern" and k.UI.frame.hotSwapTheme=="modern","Reopening reset theme")
    assert(k:Export()==exported and k.dirty==dirty,"Theme leaked into shared binding presets")
    assert(#Mock.writes==0,"Changing theme modified live bindings, bars or macros")
end

function Tests.theme_switch_preserves_pending_current_edits_and_draft_state()
    Mock.bindings.F="OPENCHAT"
    local k=themeAddon(); local ui=k.UI
    assert(ui:AssignBinding(ui.bindingPlan.byKey.F,"F9"))
    k:UpdateSetting("wheel",false)
    local exported,dirty,selected=k:Export(),k.dirty,k.db.activePreset
    local edits=k.Copy(k.CurrentBindings.edits)
    local layout=k.Copy(k.db.currentLayout)
    Mock:ResetWrites()
    assert(ui:SetTheme("modern")); assert(ui:SetTheme("classic"))
    assert(ui.bindingSource=="current" and ui.activePage=="Bindings","Theme changed the selected layout/page")
    assert(k.CurrentBindings:HasEdits() and same(k.CurrentBindings.edits,edits),"Theme discarded or rewrote pending Current edits")
    assert(same(k.db.currentLayout,layout),"Theme rewrote the saved Current layout")
    assert(ui.bindingPlan.byKey.F9.command=="OPENCHAT" and not ui.bindingPlan.byKey.F,"Theme rebuilt Current from live state and lost its edit")
    assert(k:Export()==exported and k.dirty==dirty and k.db.activePreset==selected,"Theme changed the selected preset draft")
    assert(#Mock.writes==0,"Theme committed pending game changes")
end

function Tests.theme_setting_menu_and_reset_are_immediate_and_local()
    local k=themeAddon(); local ui=k.UI
    ui:ShowPage("Settings"); local page=ui.pages.Settings
    page.sectionButtons.Window:Click()
    local exported,dirty=k:Export(),k.dirty
    page.theme:Click()
    local modern
    for _,row in ipairs(ui.menu.panel.rows) do
        if row.text:GetText()=="Modern" then modern=row end
    end
    assert(modern,"Settings theme menu does not offer Modern")
    modern:Click()
    assert(k.Themes:GetID()=="modern" and ui.frame.hotSwapTheme=="modern","Theme selection did not immediately reskin the existing window")
    assert(page.theme:GetText():find("Modern",1,true),"Theme selector does not show its selection")
    page.opacity:SetValue(0.6); page.scale:SetValue(1.2)
    Mock:ResetWrites(); page.resetAppearance:Click()
    assert(k.Themes:GetID()=="classic" and ui.frame.hotSwapTheme=="classic","Reset appearance did not restore Classic")
    assert(k.db.preferences.windowOpacity==1 and k.db.preferences.windowScale==1,"Reset appearance left scale or opacity customized")
    assert(page.theme:GetText():find("Classic",1,true),"Reset appearance left the theme selector stale")
    assert(k:Export()==exported and k.dirty==dirty and #Mock.writes==0,"Appearance menu/reset modified a binding preset or game state")
end

function Tests.theme_switch_does_not_recreate_widgets_or_change_button_handlers()
    local k=themeAddon(); local ui=k.UI
    local frame,apply,keyboard=ui.frame,ui.apply,ui.pages.Bindings.keyboard
    local handler=apply:GetScript("OnClick")
    assert(k.Themes:Set("modern")); assert(k.Themes:Set("classic"))
    local count=#Mock.frames
    for _=1,4 do assert(k.Themes:Set("modern")); assert(k.Themes:Set("classic")) end
    assert(ui.frame==frame and ui.apply==apply and ui.pages.Bindings.keyboard==keyboard,"Theme rebuilt active widgets")
    assert(apply:GetScript("OnClick")==handler,"Theme replaced the Apply handler")
    assert(#Mock.frames==count,"Repeated theme changes accumulated permanent frames")
end

function Tests.theme_native_artwork_and_fonts_restore_after_modern()
    local k=themeAddon()
    local button=CreateFrame("Button",nil,k.UI.frame,"UIPanelButtonTemplate")
    local ornament=button:CreateTexture(nil,"BACKGROUND")
    ornament:SetTexture("fixture-native-art"); ornament:SetAlpha(0.75)
    button:SetNormalTexture("fixture-native-button"); local normal=button:GetNormalTexture(); normal:SetAlpha(0.6)
    button:Disable()
    k.Themes:Skin(button,"button")
    local text=button:GetFontString(); text:SetFont("Fonts\\MORPHEUS.TTF",17,"OUTLINE")
    k.Themes:Font(text,17,k.Themes.Colors.text)
    assert(k.Themes:Set("modern"))
    assert(ornament:GetAlpha()==0 and normal:GetAlpha()==0,"Modern left native button artwork visible beneath its surface")
    assert(text.font[1]==k.Themes:GetFont() and text.font[2]==17 and text.font[3]=="OUTLINE","Modern font lost the existing size or flags")
    assert(not button:IsEnabled(),"Reskinning enabled an unavailable action")
    assert(k.Themes:Set("classic"))
    assert(ornament:GetAlpha()==0.75 and normal:GetAlpha()==0.6,"Returning to Classic lost native decoration opacity")
    assert(ornament:GetTexture()=="fixture-native-art" and normal:GetTexture()=="fixture-native-button","Theme replaced original texture assets")
    assert(text.font[1]=="Fonts\\MORPHEUS.TTF" and text.font[2]==17 and text.font[3]=="OUTLINE","Returning to Classic did not restore the original font")
    assert(not button:IsEnabled(),"Returning to Classic enabled an unavailable action")
end

function Tests.theme_lazy_modal_uses_active_theme_without_dismissing_pending_confirmation()
    local k=themeAddon(); local ui=k.UI; local accepted=0
    assert(k.Themes:Set("modern"))
    ui:Confirm("Confirm change","A pending operation",function() accepted=accepted+1 end)
    local dialog=ui.confirm
    assert(dialog.hotSwapTheme=="modern" and dialog.title.font[1]==k.Themes:GetFont(),"A lazily created dialog used stale Classic styling")
    assert(k.Themes:Set("classic"))
    assert(dialog:IsShown() and accepted==0,"Theme switch accepted or dismissed an active confirmation")
    assert(dialog.hotSwapTheme=="classic" and dialog.title.font[1]==STANDARD_TEXT_FONT,"A visible modal did not return to Classic")
    dialog.cancelButton:Click()
    assert(accepted==0 and not dialog:IsShown(),"Restyled confirmation lost its cancellation behavior")
end

function Tests.theme_modern_keeps_locale_font_for_cjk_glyph_coverage()
    local k=themeAddon(false)
    assert(k.Themes:Set("modern"))
    for _,locale in ipairs({"koKR","zhCN","zhTW"}) do
        GetLocale=function() return locale end
        assert(k.Themes:GetFont()==STANDARD_TEXT_FONT,"Modern selected a Latin font for "..locale)
    end
end

function Tests.theme_combat_is_cosmetic_and_busy_transaction_rejects_switch_atomically()
    local k=themeAddon(); local exported=k:Export()
    Mock:ResetWrites(); Mock.combat=true; Mock.strictInputRestrictions=true
    assert(k.Themes:Set("modern"),"Cosmetic theme switch was unavailable in combat")
    assert(k:Export()==exported and #Mock.writes==0,"Combat theme switch touched protected game state")
    k.Engine.busy=true
    local before=k.Copy(k.db.preferences)
    local ok,why=k.Themes:Set("classic")
    assert(ok==false and type(why)=="string" and #why>0,"Busy transaction did not provide an actionable rejection")
    assert(same(k.db.preferences,before) and k.Themes:GetID()=="modern","Busy theme change partially updated preferences")
end

function Tests.theme_button_feedback_survives_tooltips_and_respects_disabled_state()
    local k=themeAddon(); assert(k.Themes:Set("modern"))
    local w=k.UI.widgets; local clicks=0
    local button=w.button(k.UI.frame,"Fixture action",130,function() clicks=clicks+1 end)
    w.tooltip(button,"Action details","This tooltip must not replace theme feedback.")
    local surface=k.Themes.widgets[button].surface
    local normal=k.Copy(surface.colorTexture)
    button:GetScript("OnEnter")(button)
    local hovered=k.Copy(surface.colorTexture)
    assert(not same(normal,hovered) and GameTooltip:IsShown(),"Tooltip setup removed button hover feedback")
    button:GetScript("OnMouseDown")(button,"LeftButton")
    assert(not same(hovered,surface.colorTexture),"Pressed button has no distinct visual feedback")
    button:GetScript("OnMouseUp")(button,"LeftButton")
    assert(same(hovered,surface.colorTexture),"Mouse release left the button visually pressed")
    button:GetScript("OnLeave")(button)
    assert(same(normal,surface.colorTexture) and not GameTooltip:IsShown(),"Mouse leave did not restore the idle surface and dismiss tooltip")
    button:Disable()
    local disabled=k.Copy(surface.colorTexture)
    button:GetScript("OnEnter")(button)
    button:GetScript("OnMouseDown")(button,"LeftButton")
    assert(same(disabled,surface.colorTexture),"Disabled button displays active hover or press feedback")
    assert(same(button.text.textColor,k.Themes.Colors.muted),"Disabled action text does not look disabled")
    button:GetScript("OnLeave")(button); button:Enable(); button:Click()
    assert(same(normal,surface.colorTexture) and clicks==1,"Skinning changed enabled action behavior")
end

function Tests.theme_checked_state_tracks_native_updates_and_disables_without_losing_value()
    local k=themeAddon(); assert(k.Themes:Set("modern"))
    local check=CreateFrame("CheckButton",nil,k.UI.frame,"UICheckButtonTemplate")
    check:SetCheckedTexture("fixture-checked"); check:SetDisabledCheckedTexture("fixture-disabled-check")
    k.Themes:Skin(check,"check")
    local mark=k.Themes.widgets[check].checkMark
    check:SetChecked(true)
    assert(mark:IsShown(),"Programmatic check updates did not reveal the modern indicator")
    check:Disable()
    assert(mark:IsShown() and same(mark.colorTexture,k.Themes.Colors.muted),"Disabling a checked control left its active indicator")
    assert(check:GetChecked(),"Visual disabled state cleared its preference")
    assert(check:GetCheckedTexture():GetAlpha()==0 and check:GetDisabledCheckedTexture():GetAlpha()==0,"Modern checkbox retained native checked artwork")
    check:Enable(); check:SetChecked(false)
    assert(not mark:IsShown(),"Unchecking a control retained the modern indicator")
    assert(k.Themes:Set("classic"))
    assert(check:GetCheckedTexture():GetAlpha()==1 and check:GetDisabledCheckedTexture():GetAlpha()==1,"Classic checkbox did not regain both native check textures")
end

-- Track texture cropping locally: the general mock otherwise treats
-- SetTexCoord as a no-op, which would conceal an icon-masking regression.
local function trackThemeIconCrops()
    local create=CreateFrame
    CreateFrame=function(...)
        local frame=create(...)
        if frame.kind=="Texture" then
            local set=frame.SetTexCoord
            frame.SetTexCoord=function(self,...)
                self.themeTestCrop={...}; return set(self,...)
            end
        end
        return frame
    end
end
local function themeIconSnapshot(icon)
    assert(icon and icon:IsVisible() and icon:GetAlpha()>0,"Fixture spell icon must be visible")
    assert(icon:GetTexture(),"Fixture spell icon must have its native artwork")
    return {
        icon=icon,texture=icon:GetTexture(),alpha=icon:GetAlpha(),
        crop=TestAddon.Copy(icon.themeTestCrop),vertex=TestAddon.Copy(icon.vertexColor),
        solid=TestAddon.Copy(icon.colorTexture),desaturated=icon.desaturated,
        width=icon:GetWidth(),height=icon:GetHeight(),
    }
end
local function assertThemeIconsUnchanged(snapshots)
    for _,entry in ipairs(snapshots) do
        local icon=entry.icon
        assert(icon:IsVisible() and icon:GetAlpha()==entry.alpha,"Theme hid or faded a spell icon")
        assert(icon:GetTexture()==entry.texture and same(icon.colorTexture,entry.solid),"Theme replaced spell artwork with a flat surface")
        assert(same(icon.themeTestCrop,entry.crop),"Theme changed spell icon cropping")
        assert(same(icon.vertexColor,entry.vertex) and icon.desaturated==entry.desaturated,"Theme recolored a spell icon or changed its learned-state treatment")
        assert(icon:GetWidth()==entry.width and icon:GetHeight()==entry.height,"Theme changed spell icon dimensions")
    end
end

function Tests.theme_current_keyboard_and_spellbook_keep_original_spell_artwork()
    trackThemeIconCrops()
    local spells={{5177,"Interface\\Icons\\Spell_Nature_AbolishMagic"},{8921,"Interface\\Icons\\Spell_Nature_StarFall"},{2912,"Interface\\Icons\\Spell_Arcane_StarFire"}}
    for slot,spell in ipairs(spells) do
        Mock:Spell(spell[1]).icon=spell[2]
        Mock.actions[slot]={"spell",spell[1]}; Mock.bindings[tostring(slot)]="ACTIONBUTTON"..slot
    end
    local k=themeAddon(); local ui=k.UI; local snapshots={}
    for slot,spell in ipairs(spells) do
        local icon=ui.pages.Bindings.keyboard.keys[tostring(slot)].icon
        assert(icon:GetTexture()==spell[2],"Current keyboard omitted the native spell texture")
        snapshots[#snapshots+1]=themeIconSnapshot(icon)
    end
    local libraryIcons=0
    for _,row in ipairs(ui.library.list.rows) do
        if row:IsVisible() and row.icon:GetTexture() then
            libraryIcons=libraryIcons+1; snapshots[#snapshots+1]=themeIconSnapshot(row.icon)
        end
    end
    assert(libraryIcons>=3,"Fixture did not expose enough spellbook icons")
    for _,theme in ipairs({"modern","classic","modern"}) do
        assert(ui:SetTheme(theme)); assertThemeIconsUnchanged(snapshots)
    end
end

function Tests.theme_lazy_hover_editor_keeps_spell_icons_through_switches()
    trackThemeIconCrops()
    local k=themeAddon(); local ui=k.UI
    assert(ui:SetTheme("modern")); ui:OpenHoverBindings()
    assert(ui.hoverBindings and ui.hoverBindings:IsShown(),"Hover editor did not open in Modern")
    local snapshots={}
    for _,row in pairs(ui.hoverBindings.rows) do
        if row:IsVisible() then snapshots[#snapshots+1]=themeIconSnapshot(row.icon) end
    end
    assert(#snapshots>=10,"Fixture did not populate the hover editor's spell icons")
    for _,theme in ipairs({"classic","modern","classic"}) do
        assert(ui:SetTheme(theme)); assertThemeIconsUnchanged(snapshots)
    end
end
