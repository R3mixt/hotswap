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
function V:Build(page,ui,w)
    w.label(page,"Settings",18):SetPoint("TOPLEFT")
    local note=w.label(page,"For this character only. Window settings and diagnostic logs are separate from shared presets.",11,C.muted)
    note:SetPoint("TOPLEFT",0,-29); note:SetWidth(800)
    local appearance=w.box("Frame",page); appearance:SetPoint("TOPLEFT",0,-61); appearance:SetSize(382,210)
    w.label(appearance,"Window appearance",15):SetPoint("TOPLEFT",14,-14)
    page.opacity=appearanceSlider(appearance,"Opacity",-46,"windowOpacity",0.4,1)
    page.scale=appearanceSlider(appearance,"Scale",-100,"windowScale",0.7,1.3)
    page.resetAppearance=w.button(appearance,"Reset appearance",158,function() ui:ResetAppearance() end)
    page.resetAppearance:SetPoint("BOTTOMLEFT",14,14)
    w.tooltip(page.scale,"Window scale","Choose your preferred size. Hot Swap reduces it when necessary to fit the window and spellbook on your screen.")
    local diagnostics=w.box("Frame",page); diagnostics:SetPoint("TOPRIGHT",0,-61); diagnostics:SetSize(405,210)
    w.label(diagnostics,"Diagnostics",15):SetPoint("TOPLEFT",14,-14)
    page.diagnostics=CreateFrame("CheckButton",nil,diagnostics,"UICheckButtonTemplate")
    page.diagnostics:SetPoint("TOPLEFT",10,-40); page.diagnostics:SetSize(26,26)
    if page.diagnostics.text then page.diagnostics.text:Hide() end
    w.label(page.diagnostics,"Enable diagnostic logging",12,C.text):SetPoint("LEFT",29,0)
    page.diagnostics:SetScript("OnClick",function(self)
        local ok,why=K.Diagnostics:SetEnabled(self:GetChecked() and true or false)
        if not ok then ui:Notice(why or "Could not update diagnostic logging.",true) end
        V:Render(page,ui,w)
    end)
    local detail=w.label(diagnostics,"Record setup failures and compatibility details for troubleshooting. Off by default.",11,C.muted)
    detail:SetPoint("TOPLEFT",14,-82); detail:SetWidth(375)
    page.logCount=w.label(diagnostics,"",11,C.muted); page.logCount:SetPoint("TOPLEFT",14,-132)
    page.viewLog=w.button(diagnostics,"View / copy log",160,function() V:OpenLog() end)
    page.viewLog:SetPoint("BOTTOMLEFT",14,14)
    page.clearLog=w.button(diagnostics,"Clear log",100,function() K.Diagnostics:Clear(); V:Render(page,ui,w) end)
    page.clearLog:SetPoint("BOTTOMRIGHT",-14,14)
    local info=w.label(page,"Appearance changes apply immediately. Disabling logging keeps existing entries until you clear them.\nLogs stay on this character and are never sent automatically. Use /reload or log out to save them to disk.",11,C.muted)
    info:SetPoint("TOPLEFT",0,-292); info:SetWidth(800)
end
function V:Render(page)
    if not page then return end
    local p=preferences(); self.rendering=true
    for _,entry in ipairs({{page.opacity,p.windowOpacity,0.4,1},{page.scale,p.windowScale,0.7,1.3}}) do
        local value=clamp(entry[2],entry[3],entry[4]) or 1
        entry[1]:SetValue(value); entry[1].valueLabel:SetText(math.floor(value*100+0.5).."%")
    end
    self.rendering=nil
    page.diagnostics:SetChecked(K.Diagnostics:IsEnabled())
    local count=K.Diagnostics:Count()
    page.logCount:SetText(tostring(count).." log entr"..(count==1 and "y" or "ies").." saved")
    page.clearLog:SetEnabled(count>0)
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
