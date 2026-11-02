local _,K=...
K.SettingsUI={}
local V,UI,W=K.SettingsUI,K.UI,K.UI.widgets
local C=W.colors
local function preferences()
    K.db.preferences=K.db.preferences or {diagnostics=false,windowOpacity=1,windowScale=1}
    return K.db.preferences
end
local function clamp(value,low,high)
    value=tonumber(value)
    if not value or value~=value then return nil end
    return math.max(low,math.min(high,value))
end

-- Window preferences are character-local. They never enter a binding preset
-- or its export, and resizing a window never touches protected game state.
function UI:ApplyAppearance(wide)
    if not self.frame or not K.db then return end
    local p=preferences()
    local opacity=clamp(p.windowOpacity,0.4,1) or 1
    local preferred=clamp(p.windowScale,0.7,1.3) or 1
    local fit=math.min((UIParent:GetWidth()-30)/(wide and 1180 or 860),(UIParent:GetHeight()-30)/620)
    self.actualWindowScale=math.max(0.1,math.min(preferred,fit))
    self.frame:SetAlpha(opacity); self.frame:SetScale(self.actualWindowScale)
end
function UI:SetAppearance(key,value)
    local bounds=({windowOpacity={0.4,1},windowScale={0.7,1.3}})[key]
    if not bounds then return false,"Unknown appearance setting." end
    value=clamp(value,bounds[1],bounds[2])
    if not value then return false,"Choose a numeric appearance value." end
    preferences()[key]=value
    self:FitWindows()
    if self.pages and self.pages.Settings then V:Render(self.pages.Settings,self,W) end
    return true
end
function UI:ResetAppearance()
    local p=preferences(); p.windowOpacity,p.windowScale=1,1
    self:FitWindows()
    if self.pages and self.pages.Settings then V:Render(self.pages.Settings,self,W) end
end

local function appearanceSlider(parent,title,y,key,low,high)
    W.label(parent,title,11,C.text):SetPoint("TOPLEFT",14,y)
    local slider=CreateFrame("Slider",nil,parent,"OptionsSliderTemplate")
    slider:SetOrientation("HORIZONTAL"); slider:SetSize(234,18); slider:SetPoint("TOPLEFT",18,y-23)
    slider:SetMinMaxValues(low,high); slider:SetValueStep(0.05)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    for _,part in ipairs({"Low","High","Text"}) do if slider[part] then slider[part]:Hide() end end
    slider.valueLabel=W.label(parent,"",12,C.accent); slider.valueLabel:SetPoint("LEFT",slider,"RIGHT",19,0); slider.valueLabel:SetWidth(76)
    slider:SetScript("OnValueChanged",function(_,value) if not V.rendering then UI:SetAppearance(key,value) end end)
    return slider
end
local protectionOptions={
    {"preserveMovement","Keep current movement","Keep your movement and auto-run keys."},
    {"preserveCamera","Keep camera and selection","Keep mouse camera, selection and zoom controls."},
    {"preserveChat","Keep current chat controls","Keep chat entry, replies and chat commands."},
    {"preserveInterface","Keep other game controls","Keep bags, character panels, menus and other interface keys."},
    {"preserveTargeting","Keep current targeting","Keep target-selection and focus controls."},
    {"preserveGameSettings","Keep casting settings","Keep the current self-cast and related casting settings."},
}
local function option(page,parent,key,title,detail,x,y,localPreference)
    local check=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    check:SetPoint("TOPLEFT",x,y); check:SetSize(26,26)
    if check.text then check.text:Hide() end
    W.label(check,title,12,C.text):SetPoint("LEFT",29,0)
    W.tooltip(check,title,detail)
    check.settingKey,check.localPreference=key,localPreference
    check:SetScript("OnClick",function(self)
        if localPreference then V:SetLocalPreference(key,self:GetChecked() and true or false)
        else UI:Stage(key,self:GetChecked() and true or false) end
    end)
    page[key]=check; page.checks[#page.checks+1]=check
    return check
end
function V:ShowSection(page,name)
    self.section=name
    for id,frame in pairs(page.sections) do frame:SetShown(id==name); W.color(page.sectionButtons[id].text,id==name and C.accent or C.muted) end
    page.scope:SetText((name=="Controls" or name=="Action bars") and ("Editing preset: "..tostring(K.db.activePreset or "")..". Preset options take effect with Apply & save.") or "For this character only. These preferences are not included in shared presets.")
end
function V:SetLocalPreference(key,value)
    if K.Engine and K.Engine.busy then UI:UpdateBusyState(); return end
    if key~="showMacroNames" and key~="showMacroCode" and key~="showUnavailableBindings" then return end
    preferences()[key]=value and true or false
    if key=="showMacroNames" and K.NativeBars and K.NativeBars.ApplyMacroTextPreference then K.NativeBars:ApplyMacroTextPreference() end
    if key=="showUnavailableBindings" then UI:CancelLibraryDrag(); UI.selectedAction=nil end
    UI:Refresh()
end
function V:Build(page,ui,w)
    w.label(page,"Settings",18):SetPoint("TOPLEFT")
    page.scope=w.label(page,"",11,C.muted); page.scope:SetPoint("TOPLEFT",0,-28); page.scope:SetWidth(800)
    page.sections,page.sectionButtons,page.checks={},{},{}
    for i,name in ipairs({"Controls","Action bars","Window","Diagnostics"}) do
        local section=w.box("Frame",page); section:SetPoint("TOPLEFT",0,-84); section:SetPoint("BOTTOMRIGHT",0,0)
        page.sections[name]=section
        local tab=w.button(page,name,143,function() V:ShowSection(page,name) end)
        tab:SetPoint("TOPLEFT",(i-1)*151,-49); page.sectionButtons[name]=tab
    end
    local controls=page.sections.Controls
    w.label(controls,"Keep existing controls",15):SetPoint("TOPLEFT",16,-16)
    local intro=w.label(controls,"Checked categories keep their current bindings when this preset is applied.",11,C.muted)
    intro:SetPoint("TOPLEFT",16,-44); intro:SetWidth(766)
    for i,entry in ipairs(protectionOptions) do
        option(page,controls,entry[1],entry[2],entry[3],14+((i-1)%2)*390,-73-math.floor((i-1)/2)*43)
    end
    page.spellsOnly=w.button(controls,"Spells only",145,function()
        local values={}; for _,entry in ipairs(protectionOptions) do values[entry[1]]=true end
        ui.bindingSource="draft"
        ui:Call(K,"UpdateSettings",values)
        ui:Refresh()
    end)
    page.spellsOnly:SetPoint("TOPLEFT",18,-221); page.checks[#page.checks+1]=page.spellsOnly
    local keep=w.label(controls,"Protect all six categories. Spell and item assignments remain editable.\nUnrelated bindings are always preserved.",11,C.muted)
    keep:SetPoint("TOPLEFT",181,-223); keep:SetSize(589,34)
    local bars=page.sections["Action bars"]
    w.label(bars,"Preset behavior",15):SetPoint("TOPLEFT",16,-16)
    option(page,bars,"hideUnavailableSpells","Hide unavailable spells on action bars","Leave unavailable spell slots empty on Blizzard's bars. Their keys and positions stay reserved.",14,-44)
    option(page,bars,"adaptTalents","Adapt to learned talents","Keep unavailable talents off Blizzard's bars while retaining their reserved keys.",14,-79)
    option(page,bars,"allowAccountMacros","Allow account-wide macro overflow","Generated macros use character-specific slots by default. Enable only to allow additional account-wide slots shared by all characters. Existing personal macros are never overwritten.",14,-114)
    w.label(bars,"Display on this character",15):SetPoint("TOPLEFT",16,-167)
    option(page,bars,"showMacroNames","Show macro names on action buttons","Show or hide macro labels on Blizzard's original action buttons. The macro itself is unchanged.",14,-195,true)
    option(page,bars,"showMacroCode","Show macro code in Hot Swap tooltips","Show generated macro instructions in binding-detail tooltips. Spell and target descriptions stay visible.",14,-230,true)
    option(page,bars,"showUnavailableBindings","Show unavailable spells in the editor","Include unlearned and unselected talent spells in the keyboard, binding list and spellbook. Hiding them does not move or release their keys.",14,-265,true)
    local localNote=w.label(bars,"Display options apply immediately. Hidden abilities keep their assigned positions.",10,C.muted)
    localNote:SetPoint("TOPLEFT",18,-315); localNote:SetWidth(760)
    local appearance=page.sections.Window
    w.label(appearance,"Window appearance",15):SetPoint("TOPLEFT",16,-16)
    page.opacity=appearanceSlider(appearance,"Opacity",-56,"windowOpacity",0.4,1)
    page.scale=appearanceSlider(appearance,"Scale",-117,"windowScale",0.7,1.3)
    page.resetAppearance=w.button(appearance,"Reset appearance",158,function() ui:ResetAppearance() end)
    page.resetAppearance:SetPoint("TOPLEFT",18,-197)
    local windowNote=w.label(appearance,"Changes apply immediately. The window fits the available screen space.\nUse /reload or log out to save preferences to disk.",11,C.muted)
    windowNote:SetPoint("TOPLEFT",18,-254); windowNote:SetSize(760,34)
    w.tooltip(page.scale,"Window scale","Choose your preferred size. Hot Swap reduces it when necessary to fit the window and spellbook on your screen.")
    local diagnostics=page.sections.Diagnostics
    w.label(diagnostics,"Diagnostic logging",15):SetPoint("TOPLEFT",16,-16)
    page.diagnostics=CreateFrame("CheckButton",nil,diagnostics,"UICheckButtonTemplate")
    page.diagnostics:SetPoint("TOPLEFT",14,-48); page.diagnostics:SetSize(26,26)
    if page.diagnostics.text then page.diagnostics.text:Hide() end
    w.label(page.diagnostics,"Enable diagnostic logging",12,C.text):SetPoint("LEFT",29,0)
    page.diagnostics:SetScript("OnClick",function(self)
        local ok,why=K.Diagnostics:SetEnabled(self:GetChecked() and true or false)
        if not ok then ui:Notice(why or "Could not update diagnostic logging.",true) end
        V:Render(page,ui,w)
    end)
    local detail=w.label(diagnostics,"Record setup failures and compatibility details for troubleshooting. Off by default.",11,C.muted)
    detail:SetPoint("TOPLEFT",18,-93); detail:SetWidth(760)
    page.logCount=w.label(diagnostics,"",11,C.muted); page.logCount:SetPoint("TOPLEFT",18,-136)
    page.viewLog=w.button(diagnostics,"View / copy log",160,function() V:OpenLog() end)
    page.viewLog:SetPoint("TOPLEFT",18,-170)
    page.clearLog=w.button(diagnostics,"Clear log",100,function() K.Diagnostics:Clear(); V:Render(page,ui,w) end)
    page.clearLog:SetPoint("TOPLEFT",190,-170)
    local info=w.label(diagnostics,"Disabling logging keeps existing entries until you clear them. Logs stay local and are never sent automatically.\nUse /reload or log out to save the log to disk.",11,C.muted)
    info:SetPoint("TOPLEFT",18,-238); info:SetSize(760,42)
    self:ShowSection(page,self.section or "Controls")
end
function V:Render(page)
    if not page then return end
    local p=preferences(); self.rendering=true
    for _,entry in ipairs({{page.opacity,p.windowOpacity,0.4,1},{page.scale,p.windowScale,0.7,1.3}}) do
        local value=clamp(entry[2],entry[3],entry[4]) or 1
        entry[1]:SetValue(value); entry[1].valueLabel:SetText(math.floor(value*100+0.5).."%")
    end
    local s=K:GetSettings()
    for _,check in ipairs(page.checks) do
        if check.settingKey then
            local value=check.localPreference and p[check.settingKey] or s[check.settingKey]
            if check.localPreference then value=p[check.settingKey]~=false end
            check:SetChecked(value==true)
        end
    end
    self.rendering=nil
    page.diagnostics:SetChecked(K.Diagnostics:IsEnabled())
    local count=K.Diagnostics:Count()
    page.logCount:SetText(tostring(count).." log entr"..(count==1 and "y" or "ies").." recorded")
    page.clearLog:SetEnabled(count>0)
    self:ShowSection(page,self.section or "Controls")
end
function V:ClearFocus()
    if UI.diagnosticLogDialog then UI.diagnosticLogDialog.text:ClearFocus() end
end
function V:OpenLog()
    if K.Engine and K.Engine.busy then UI:UpdateBusyState(); return end
    UI:CloseMenu(); UI:ClearInputFocus()
    local f=UI.diagnosticLogDialog
    if not f then
        f=W.box("Frame",UI.frame,C.bg,"KeybindOptimizerDiagnosticLog")
        f:SetAllPoints(UI.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(UI.frame:GetFrameLevel()+55); f:EnableMouse(true)
        W.label(f,"Diagnostic log",22):SetPoint("TOPLEFT",40,-40)
        f.note=W.label(f,"",12,C.muted); f.note:SetPoint("TOPLEFT",40,-80); f.note:SetSize(760,32)
        local shell=W.box("Frame",f,C.field); shell:SetPoint("TOPLEFT",40,-117); shell:SetPoint("BOTTOMRIGHT",-40,100)
        local scroll=CreateFrame("ScrollFrame",nil,shell,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",10,-10); scroll:SetPoint("BOTTOMRIGHT",-29,10)
        local text=CreateFrame("EditBox",nil,scroll); text:SetMultiLine(true); text:SetAutoFocus(false); text:SetFontObject(ChatFontNormal or GameFontHighlight)
        text:SetSize(700,300); text:SetMaxLetters(2000000); scroll:SetScrollChild(text); f.text=text
        UI:ConfigureCopyScroll(text,scroll)
        text:SetScript("OnEscapePressed",function() f:Hide() end)
        text:SetScript("OnEditFocusGained",function() UI:UpdateBindingTester() end)
        text:SetScript("OnEditFocusLost",function() UI:UpdateBindingTester() end)
        f.copy=W.button(f,"Select text",120,function() text:SetFocus(); text:HighlightText() end); f.copy:SetPoint("BOTTOMLEFT",40,40)
        f.clear=W.button(f,"Clear log",110,function() K.Diagnostics:Clear(); V:OpenLog(); V:Render(UI.pages.Settings) end); f.clear:SetPoint("BOTTOMRIGHT",-160,40)
        f.close=W.button(f,"Close",105,function() f:Hide() end,true); f.close:SetPoint("BOTTOMRIGHT",-40,40)
        f:SetScript("OnHide",function() text:ClearFocus(); UI:EndModal(f) end)
        UI.diagnosticLogDialog=f
    end
    f.note:SetText("Logging "..(K.Diagnostics:IsEnabled() and "on" or "off")..". Select text and press Ctrl+C to copy it.\nUse /reload or log out to save the log to disk.")
    f.text:SetText(K.Diagnostics:Export()); f.clear:SetEnabled(K.Diagnostics:Count()>0)
    UI:BeginModal(f,"KeybindOptimizerDiagnosticLog"); f:Show(); f.text:SetFocus(); f.text:HighlightText()
end
