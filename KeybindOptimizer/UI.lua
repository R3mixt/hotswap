local _, K = ...

-- Native UI only. Protected writes belong to Engine and happen on Apply.
K.UI = K.UI or {}
local UI = K.UI
local specialFrame
local C = {
    bg = {0.055, 0.047, 0.035, 0.99}, panel = {0.10, 0.085, 0.065, 1},
    field = {0.08, 0.07, 0.055, 1}, edge = {0.58, 0.51, 0.37, 1},
    text = {0.95, 0.91, 0.82, 1}, muted = {0.68, 0.65, 0.58, 1},
    accent = {1, 0.82, 0, 1}, warning = {1, 0.72, 0.25, 1},
    error = {1, 0.43, 0.43, 1}, white = {1, 1, 1, 1},
}
local unpack = unpack or table.unpack
local APPLY_LABEL="Apply & save"
local APPLY_DETAIL="Back up your current setup, update this preset's assigned keys, macros and action bars, then save the game's bindings. Unrelated bindings and mouse controls stay unchanged. Draft edits are already saved in this preset."
local function color(fs, c) fs:SetTextColor(unpack(c or C.text)) end
local function box(kind, parent, fill, name)
    local f = CreateFrame(kind or "Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then
        f:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 32, edgeSize = 12, insets = {left=3, right=3, top=3, bottom=3}})
        -- The supplied Blizzard background is already dark and textured.
        f:SetBackdropColor(1, 1, 1, (fill or C.panel)[4] or 1)
        f:SetBackdropBorderColor(unpack(C.edge))
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(unpack(fill or C.panel))
        f.bg = bg
    end
    return f
end
local function label(parent, value, size, tone)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, "")
    fs:SetText(value or "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    color(fs, tone or ((size or 12) >= 15 and C.accent or C.text))
    return fs
end
local function truncate(fs, width)
    fs:SetWidth(width)
    fs:SetWordWrap(false)
end
local function tooltip(f, title, detail, spellID, locked, itemID)
    f.tipTitle, f.tipDetail, f.tipSpellID, f.tipLocked, f.tipItemID = title, detail, spellID, locked, itemID
    f:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local native
        if self.tipItemID and GameTooltip.SetItemByID then native=pcall(GameTooltip.SetItemByID,GameTooltip,self.tipItemID)
        elseif self.tipItemID and GameTooltip.SetHyperlink then native=pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..self.tipItemID)
        elseif self.tipSpellID and GameTooltip.SetSpellByID then native=pcall(GameTooltip.SetSpellByID,GameTooltip,self.tipSpellID) end
        if native then GameTooltip:AddLine(self.tipTitle or "", 1, 0.82, 0, true)
        else GameTooltip:SetText(self.tipTitle or "", 1, 1, 1) end
        if self.tipLocked then
            local note=type(self.tipLocked)=="string" and self.tipLocked or "Not learned yet — you can bind this spell now."
            GameTooltip:AddLine(note, 1, 0.72, 0.25, true)
        end
        if self.tipDetail and self.tipDetail ~= "" then GameTooltip:AddLine(self.tipDetail, 0.7, 0.78, 0.81, true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
local function button(parent, text, width, fn, primary)
    local f = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    f:SetSize(width or 100, 26)
    f:SetText(text or "")
    f.text = f:GetFontString()
    if f.text then color(f.text, primary and C.accent or C.text) end
    f:SetScript("OnClick", fn)
    return f
end
local function selectTab(tab, selected)
    if selected and PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab)
    elseif not selected and PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    if tab.text then color(tab.text, selected and C.accent or C.text) end
end
local function listRow(parent)
    local row = CreateFrame("Button", nil, parent)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.07, 0.05, 0.45)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.selection = row:CreateTexture(nil, "ARTWORK")
    row.selection:SetAllPoints()
    row.selection:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.selection:SetVertexColor(1, 0.82, 0.35, 0.35)
    row.selection:SetBlendMode("ADD")
    row.selection:Hide()
    return row
end
local function edit(parent, width, height, multiline)
    local shell = CreateFrame("Frame", nil, parent)
    shell:SetSize(width, height or 30)
    local e = CreateFrame("EditBox", nil, shell, "InputBoxTemplate")
    e:SetPoint("TOPLEFT", 9, -4)
    e:SetPoint("BOTTOMRIGHT", -6, 4)
    e:SetFontObject(ChatFontNormal or GameFontHighlight)
    e:SetAutoFocus(false)
    e:SetMultiLine(multiline and true or false)
    e:SetTextInsets(0, 0, 0, 0)
    if e.SetMaxLetters then e:SetMaxLetters(multiline and 500000 or 100) end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function() if UI.UpdateBindingTester then UI:UpdateBindingTester() end end)
    e:SetScript("OnEditFocusLost", function() if UI.UpdateBindingTester then UI:UpdateBindingTester() end end)
    shell.edit = e
    return shell, e
end
local function scroll(parent)
    local host = CreateFrame("Frame", nil, parent)
    local sf = CreateFrame("ScrollFrame", nil, host)
    sf:SetPoint("TOPLEFT")
    sf:SetPoint("BOTTOMRIGHT", -22, 0)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(600, 1)
    sf:SetScrollChild(child)
    local slider = CreateFrame("Slider", nil, host)
    slider:SetPoint("TOPRIGHT", -1, 0)
    slider:SetPoint("BOTTOMRIGHT", -1, 0)
    slider:SetWidth(16)
    slider:SetOrientation("VERTICAL")
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(24)
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(16, 24)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    slider:SetScript("OnValueChanged", function(_, value) sf:SetVerticalScroll(value) end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(_, delta)
        local lo, hi = slider:GetMinMaxValues()
        slider:SetValue(math.max(lo, math.min(hi, slider:GetValue() - delta * 54)))
    end)
    host.sf, host.child, host.slider, host.rows = sf, child, slider, {}
    function host:UpdateHeight(height)
        if self.updatingHeight then return end
        self.updatingHeight = true
        self.child:SetWidth(math.max(1, self.sf:GetWidth()))
        self.child:SetHeight(math.max(1, height))
        local range = math.max(0, height - self.sf:GetHeight())
        self.slider:SetMinMaxValues(0, range)
        self.slider:SetValue(math.min(self.slider:GetValue(), range))
        self.slider:SetShown(range > 0)
        self.updatingHeight = false
    end
    host:SetScript("OnSizeChanged", function(self) self:UpdateHeight(self.child:GetHeight()) end)
    return host
end
local function message(entry)
    if type(entry) == "table" then
        return tostring(entry.message or entry.reason or entry.label or entry.text or entry.id or "Review required")
            .. (entry.key and (" [" .. tostring(entry.key) .. "]") or "")
    end
    return tostring(entry or "")
end
local function settings()
    if K.GetSettings and K.db then return K:GetSettings() or {} end
    return K.db and K.db.settings or {}
end
local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end
-- A native multiline EditBox grows with its text. Keep the caret visible when
-- navigating long logs/exports without estimating text height or scanning lines.
function UI:ConfigureCopyScroll(text,sf)
    text.scrollFrame=sf
    sf:SetScript("OnSizeChanged",function(owner) text:SetWidth(math.max(1,owner:GetWidth())) end)
    text:SetScript("OnCursorChanged",function(_,_,y,_,height)
        local top=math.max(0,-y)
        local offset=sf:GetVerticalScroll()
        local bottom=top+(height or 0)
        if top<offset then sf:SetVerticalScroll(top)
        elseif bottom>offset+sf:GetHeight() then
            sf:SetVerticalScroll(math.max(0,math.min(sf:GetVerticalScrollRange(),bottom-sf:GetHeight())))
        end
    end)
end
function UI:Notice(text, isError)
    self.notice = tostring(text or "")
    self.noticeError = isError
    if self.status then self.status:SetText(self.operationError and self.operationError.summary or self.notice); color(self.status, (self.operationError or isError) and C.error or C.muted) end
end
function UI:ClearOperationError()
    local previous=self.operationError
    self.operationError=nil
    if previous and (self.notice==previous.message or self.notice==previous.summary) then self.notice=nil; self.noticeError=nil end
    if self.operationErrorDialog then self.operationErrorDialog:Hide() end
    if self.reviewButton then self.reviewButton:SetText("Review") end
end
function UI:RecordOperationFailure(message,kind,job)
    local action=kind=="maintenance" and "Update" or tostring(kind or "apply"):find("restore",1,true) and "Restore" or "Apply"
    local record={message=tostring(message or "The operation could not finish."),kind=kind or "apply",outcome="not-started"}
    if job then
        record.reason=job.failure; record.stage=job.failureStage
        record.key,record.action,record.command=job.failureKey,job.failureAction,job.failureCommand
        record.backupID=job.entry and job.entry.complete~=false and job.entry.id or nil
        record.backupName=record.backupID and job.entry.name or nil
        if job.rollingBack and record.message:find("was rolled back",1,true) then record.outcome="restored"
        elseif job.changed then record.outcome="incomplete" end
    end
    if record.outcome=="restored" then
        record.summary=action.." failed; previous setup restored. Details."
        record.explanation="A later step failed, so Hot Swap restored your previous setup. Bars can appear briefly because their spells are placed before keybindings finish. Your draft remains saved for editing."
    elseif record.outcome=="incomplete" then
        record.summary=action.." failed; recovery needs attention. Details."
        record.explanation="Restoration did not finish. Some game settings may have changed. "..(record.backupID and "Open Backups to restore the recorded setup." or "No completed recovery backup was recorded; check your game bindings and action bars.")
    else
        record.summary=action.." could not start. Open Details."
        record.explanation="The installation did not start. No game changes were made. Your draft remains saved for editing."
    end
    local details={action.." failure",record.explanation,"","Full message:",record.message}
    if record.reason and record.reason~=record.message then details[#details+1]=""; details[#details+1]="Original failure: "..record.reason end
    if record.stage then details[#details+1]="Stage: "..tostring(record.stage) end
    if record.key then details[#details+1]="Binding: "..tostring(record.key)..(record.action and (" - "..tostring(record.action)) or "")..(record.command and (" ("..tostring(record.command)..")") or "") end
    details[#details+1]=record.backupID and ("Backup: "..tostring(record.backupName or record.backupID).." ["..record.backupID.."]") or "No new recovery backup was created."
    record.details=table.concat(details,"\n")
    self.operationError=record
    if self.reviewButton then self.reviewButton:SetText("Details") end
    self:Notice(record.message,true)
    if self.frame and self.frame:IsShown() then self:OpenOperationError() end
end
function UI:OpenOperationError()
    local record=self.operationError
    if not record or not self.frame or (K.Engine and K.Engine.busy) then return end
    self:CloseMenu(); self:ClearInputFocus()
    if not self.operationErrorDialog then
        local f=box("Frame",self.frame,C.bg,"KeybindOptimizerOperationError")
        f:SetAllPoints(self.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+55); f:EnableMouse(true)
        label(f,"Setup could not finish",22):SetPoint("TOPLEFT",40,-40)
        f.summary=label(f,"",14,C.error); f.summary:SetPoint("TOPLEFT",40,-80); f.summary:SetWidth(770); f.summary:SetHeight(42)
        f.explanation=label(f,"",12,C.muted); f.explanation:SetPoint("TOPLEFT",40,-130); f.explanation:SetWidth(770); f.explanation:SetHeight(64)
        label(f,"Details to copy",12):SetPoint("TOPLEFT",40,-207)
        local shell=box("Frame",f,C.field); shell:SetPoint("TOPLEFT",40,-232); shell:SetPoint("BOTTOMRIGHT",-40,110)
        local sf=CreateFrame("ScrollFrame",nil,shell,"UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT",10,-10); sf:SetPoint("BOTTOMRIGHT",-29,10)
        local text=CreateFrame("EditBox",nil,sf); text:SetMultiLine(true); text:SetAutoFocus(false); text:SetFontObject(ChatFontNormal or GameFontHighlight)
        text:SetSize(700,180); text:SetMaxLetters(2000000); sf:SetScrollChild(text); f.text=text
        self:ConfigureCopyScroll(text,sf)
        text:SetScript("OnEscapePressed",function() f:Hide() end)
        text:SetScript("OnEditFocusGained",function() UI:UpdateBindingTester() end)
        text:SetScript("OnEditFocusLost",function() UI:UpdateBindingTester() end)
        local note=label(f,"Select the text, then press Ctrl+C. Closing keeps these details available.",10,C.muted)
        note:SetPoint("BOTTOMLEFT",40,80); note:SetWidth(760)
        f.copy=button(f,"Select text",120,function() text:SetFocus(); text:HighlightText() end); f.copy:SetPoint("BOTTOMLEFT",40,40)
        f.dismiss=button(f,"Dismiss error",130,function() UI:ClearOperationError(); UI:Refresh() end); f.dismiss:SetPoint("BOTTOMRIGHT",-158,40)
        f.close=button(f,"Close",105,function() f:Hide() end,true); f.close:SetPoint("BOTTOMRIGHT",-40,40)
        f:SetScript("OnHide",function() text:ClearFocus(); UI:EndModal(f) end)
        self.operationErrorDialog=f
    end
    local f=self.operationErrorDialog
    f.summary:SetText(record.summary); f.explanation:SetText(record.explanation); f.text:SetText(record.details)
    self:BeginModal(f,"KeybindOptimizerOperationError"); f:Show()
    f.text:SetFocus(); f.text:HighlightText()
end
function UI:Call(owner, method, ...)
    if K.Engine and K.Engine.busy then
        self:UpdateBusyState()
        return false,"Hot Swap is updating your setup. Wait for it to finish."
    end
    if not owner or type(owner[method]) ~= "function" then
        self:Notice("This feature is not available in this client.", true)
        return nil
    end
    local operation=(owner==K.Presets and (method=="Activate" or method=="Optimize")) or (owner==K and (method=="Apply" or method=="Restore")) or (owner==K.Engine and method=="RestoreBackup")
    local priorError=self.operationError
    local kind=method:find("Restore",1,true) and "restore" or "apply"
    local ok,a,b
    local diagnostics=K.Diagnostics
    if diagnostics and diagnostics:IsEnabled() then
        local args,count={...},select("#",...)
        local traced
        ok,a,b=xpcall(function() return owner[method](owner,unpack(args,1,count)) end,function(problem)
            local captured,detail=pcall(diagnostics.Trace,diagnostics,problem)
            traced=captured and detail or tostring(problem)
            return problem
        end)
        if not ok then pcall(diagnostics.Record,diagnostics,"error","ui-error",traced or tostring(a),{stage="UI call",operation=method}) end
    else
        ok,a,b=pcall(owner[method],owner,...)
    end
    if not ok then
        self:Notice(tostring(a),true)
        if operation and self.operationError==priorError then self:RecordOperationFailure(a,kind) end
        return nil
    end
    if a == "pending" then self:UpdateBusyState()
    elseif a == false then self:Notice(b or "The action could not be completed.", true)
    elseif b and type(b) == "string" then self:Notice(b, false) end
    if operation and a==false and self.operationError==priorError then self:RecordOperationFailure(b,kind)
    elseif operation and a==true then self:ClearOperationError() end
    return a, b
end
function UI:UpdateBusyState()
    if not self.frame then return K.Engine and K.Engine.busy or false end
    local busy=K.Engine and K.Engine.busy and true or false
    if not busy then
        if self.busyOverlay then self.busyOverlay:Hide() end
        if self.showingBusy then
            self.showingBusy=nil
            for control,enabled in pairs(self.busyControls or {}) do control:SetEnabled(enabled) end
            self.busyControls=nil
            for _,tab in pairs(self.nav or {}) do tab:SetEnabled(true) end
            self:UpdateBindingTester()
        end
        return false
    end
    if not self.showingBusy then
        self.showingBusy=true
        self.busyControls={}
        local function disable(control)
            if control and type(control.SetEnabled)=="function" then
                self.busyControls[control]=not control.IsEnabled or control:IsEnabled()
                control:SetEnabled(false)
            end
        end
        for _,name in ipairs({"apply","optimize","restore","reviewButton"}) do disable(self[name]) end
        for _,tab in pairs(self.nav or {}) do disable(tab) end
        local pages=self.pages or {}
        for _,name in ipairs({"Setup","Presets","Bindings","Items","Safety","Share","Settings"}) do
            local page=pages[name]
            if page then
                for _,control in ipairs({"optimize","nativeBars","new","duplicate","rename","delete","usePreset","hotkey","gearCapture","gearEquip","restoreSelected","original","import","opacity","scale","resetAppearance","diagnostics","viewLog","clearLog"}) do disable(page[control]) end
                if page.detail then for _,control in ipairs({"rebind","change","reset","clearKey","talents"}) do disable(page.detail[control]) end end
                for _,row in ipairs(page.checks or {}) do disable(row); disable(row.checkbox) end
                for _,row in ipairs(page.list and page.list.rows or {}) do disable(row); disable(row.key) end
            end
        end
        self:ClearInputFocus(); self:EndCapture(); self:CloseMenu()
        if self.CancelLibraryDrag then self:CancelLibraryDrag() end
        if self.library then self.library:Hide() end
        for _,name in ipairs({"confirm","picker","review","nameDialog","nativeBarsDialog","operationErrorDialog","diagnosticLogDialog","talentDialog"}) do
            local modal=self[name]; if modal then modal:Hide() end
        end
        self:ResetKeyTest()
        if self.tester then self.tester:Hide() end
        if self.testMouseShield then self.testMouseShield:Hide() end
        -- The progress cover is not an Escape modal. Escape still closes the
        -- main window; the independent engine worker keeps running.
        if not self.escapeModal then self.restoreEscapeFrame=nil; specialFrame("KeybindOptimizerWindow",true) end
    end
    if not self.busyOverlay then
        local f=box("Frame",self.frame,C.bg)
        f:SetPoint("TOPLEFT",8,-25); f:SetPoint("BOTTOMRIGHT",-8,8)
        f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+100)
        f:EnableMouse(true); f:EnableMouseWheel(true)
        f.title=label(f,"Updating your setup",20); f.title:SetPoint("TOP",0,-153)
        f.title:SetJustifyH("CENTER"); f.title:SetWidth(700)
        f.message=label(f,"",13,C.text); f.message:SetPoint("TOP",0,-194)
        f.message:SetWidth(700); f.message:SetHeight(48); f.message:SetJustifyH("CENTER")
        local track=box("Frame",f,C.field); track:SetPoint("TOP",0,-253); track:SetSize(520,20)
        f.fill=track:CreateTexture(nil,"ARTWORK"); f.fill:SetPoint("TOPLEFT",4,-4); f.fill:SetPoint("BOTTOMLEFT",4,4)
        f.fill:SetColorTexture(0.72,0.53,0.16,1)
        f.step=label(f,"",10,C.muted); f.step:SetPoint("TOP",0,-282); f.step:SetWidth(700); f.step:SetJustifyH("CENTER")
        f.note=label(f,"You can close this window. The update continues in the background.",11,C.muted)
        f.note:SetPoint("TOP",0,-318); f.note:SetWidth(700); f.note:SetJustifyH("CENTER")
        f.close=button(f,"Close window",130,function() UI.frame:Hide() end); f.close:SetPoint("TOP",0,-355)
        f:SetScript("OnUpdate",function(owner,elapsed)
            owner.elapsed=(owner.elapsed or 0)+elapsed
            if owner.elapsed>=0.1 then owner.elapsed=0; UI:UpdateBusyState() end
        end)
        self.busyOverlay=f
    end
    local f,job=self.busyOverlay,K.Engine.job or {}
    local paused=job.paused or (InCombatLockdown and InCombatLockdown())
    local message=job.message or "Preparing the next step..."
    f.title:SetText(paused and "Paused for combat" or "Updating your setup")
    f.message:SetText(message)
    local progress=tonumber(job.progress) or 0
    progress=math.max(0,math.min(1,progress))
    f.fill:SetWidth(math.max(1,512*progress)); f.fill:SetShown(progress>0)
    local index,total=tonumber(job.index),tonumber(job.total)
    f.step:SetText(index and total and total>0 and ("Step "..math.min(index,total).." of "..total) or (progress>0 and (math.floor(progress*100).."%") or "In progress"))
    f.note:SetText(paused and "This resumes when combat ends. You can close this window." or "You can close this window. The update continues in the background.")
    f:Show()
    for _,control in ipairs({self.apply,self.optimize,self.restore,self.reviewButton,self.pages and self.pages.Setup and self.pages.Setup.optimize}) do if control then control:SetEnabled(false) end end
    for _,tab in pairs(self.nav or {}) do tab:SetEnabled(false) end
    if self.status then self.status:SetText((paused and "Paused for combat: " or "Updating: ")..message); color(self.status,paused and C.warning or C.muted) end
    return true
end
function UI:OnOperationComplete(ok,message,kind)
    if self.awaitingOptimize then
        if ok then self.followForm=true; self.pendingOptimizeBindings=true end
        self.awaitingOptimize=nil
    end
    self:UpdateBusyState()
    if ok then self:ClearOperationError(); self:Notice(message or "Setup updated.")
    else
        local job=K.Engine and K.Engine.lastJob
        if not (job and job.finished and job.ok==false and job.message==message and job.kind==kind) then job=nil end
        self:RecordOperationFailure(message,kind,job)
    end
    if K.QueueRefresh then K:QueueRefresh() end
end
function UI:Stage(key, value)
    self.notice = nil
    self:Call(K, "UpdateSetting", key, value)
    self:Refresh()
end
function UI:CloseMenu()
    if self.menu then self.menu:Hide() end
    if self.UpdateBindingTester then self:UpdateBindingTester() end
end
function UI:Menu(anchor, options, selected, callback)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    self:CloseMenu()
    if not self.menu then
        local outside = CreateFrame("Button", nil, UIParent)
        outside:SetAllPoints(UIParent)
        outside:SetFrameStrata("DIALOG")
        outside:SetFrameLevel(self.frame:GetFrameLevel()+120)
        outside:SetScript("OnClick", function() UI:CloseMenu() end)
        local panel = box("Frame", outside)
        panel.rows = {}
        outside.panel = panel
        self.menu = outside
    end
    local outside, panel = self.menu, self.menu.panel
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
    panel:SetWidth(math.max(180, anchor:GetWidth()))
    panel:SetHeight(#options * 30 + 8)
    for _, row in ipairs(panel.rows) do row:Hide() end
    for i, option in ipairs(options) do
        local row = panel.rows[i]
        if not row then row = button(panel, "", panel:GetWidth() - 8); panel.rows[i] = row end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 30)
        row:SetWidth(panel:GetWidth() - 8)
        row.text:SetText((option.value == selected and "> " or "") .. option.label)
        row:SetScript("OnClick", function() UI:CloseMenu(); callback(option.value) end)
        row:Show()
    end
    outside:Show()
    self:UpdateBindingTester()
end
local function check(parent, text, hint, key, y)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetSize(620, 37)
    local square = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    square:SetSize(26, 26)
    square:SetPoint("TOPLEFT", -3, 3)
    if square.text and type(square.text.Hide) == "function" then square.text:Hide() end
    local mark = square:GetCheckedTexture()
    local name = label(row, text, 12)
    name:SetPoint("TOPLEFT", 27, -1)
    local note = label(row, hint, 10, C.muted)
    note:SetPoint("TOPLEFT", 27, -18)
    row.mark, row.checkbox, row.settingKey = mark, square, key
    row:SetScript("OnClick", function() UI:Stage(key, not settings()[key]) end)
    square:SetScript("OnClick", function() UI:Stage(key, not settings()[key]) end)
    return row
end
local function keyName(key)
    local names = {MOUSEWHEELUP = "Wheel up", MOUSEWHEELDOWN = "Wheel down", BUTTON3 = "Middle", BUTTON4 = "Mouse 4", BUTTON5 = "Mouse 5", SPACE = "Space"}
    local prefix, base = "", key or ""
    if base:find("CTRL%-") then prefix = prefix .. "Ctrl+"; base = base:gsub("CTRL%-", "") end
    if base:find("SHIFT%-") then prefix = prefix .. "Shift+"; base = base:gsub("SHIFT%-", "") end
    if base:find("ALT%-") then prefix = prefix .. "Alt+"; base = base:gsub("ALT%-", "") end
    return prefix .. (names[base] or base)
end
local function bindingLabel(command)
    if K.API and K.API.BindingLabel then return K.API:BindingLabel(command) end
    return command and command ~= "" and "Existing game action" or "Unassigned"
end
local function mouseKey(buttonName)
    local map = {LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3"}
    return map[buttonName] or string.upper(tostring(buttonName or ""))
end
local function modifiers(key)
    local out = ""
    if IsAltKeyDown and IsAltKeyDown() then out = out .. "ALT-" end
    if IsControlKeyDown and IsControlKeyDown() then out = out .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then out = out .. "SHIFT-" end
    return out .. key
end
specialFrame = function(name, enabled)
    if not UISpecialFrames then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end
    end
    if enabled then table.insert(UISpecialFrames, name) end
end
function UI:BeginModal(frame, name)
    self:ResetKeyTest()
    if self.tester then self.tester:Hide() end
    if self.escapeModal and self.escapeModal ~= frame then self.escapeModal:Hide() end
    self.restoreEscapeFrame = nil
    specialFrame("KeybindOptimizerWindow", false)
    specialFrame(name, true)
    self.escapeModal, self.escapeModalName = frame, name
    if self.SyncLibrary then self:SyncLibrary(false) end
    self:UpdateBindingTester()
end
function UI:EndModal(frame)
    if self.escapeModal ~= frame then return end
    specialFrame(self.escapeModalName, false)
    self.escapeModal, self.escapeModalName = nil, nil
    -- CloseSpecialWindows walks every UISpecialFrame. Restore the main frame
    -- next tick, after the Escape that dismissed this modal has finished.
    self.restoreEscapeFrame = true
    if self.events then
        self.events:SetScript("OnUpdate", function(owner)
            owner:SetScript("OnUpdate", nil)
            if UI.restoreEscapeFrame and not UI.escapeModal then
                UI.restoreEscapeFrame = nil
                specialFrame("KeybindOptimizerWindow", true)
                if UI.ActionPageChanged then UI:ActionPageChanged() end
                if UI.SyncLibrary then UI:SyncLibrary() end
                UI:UpdateBindingTester()
            end
        end)
    end
end
function UI:EndCapture()
    if self.endingCapture then return end
    if self.captureDispatch and self.capture and self.capture:IsShown() and self.frame:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
        -- A successful rebind must consume the same key/mouse event that chose
        -- it. Releasing capture here could execute that key's old game binding.
        self:EndModal(self.capture)
        self.captureAction=nil
        self.capture:SetScript("OnUpdate", function(owner) owner:SetScript("OnUpdate",nil); UI:EndCapture() end)
        return
    end
    self.endingCapture = true
    if self.capture then
        self:EndModal(self.capture)
        self.capture:SetScript("OnUpdate", nil)
        if not (InCombatLockdown and InCombatLockdown()) then
            self.capture:EnableKeyboard(false)
            if self.capture.SetPropagateKeyboardInput then self.capture:SetPropagateKeyboardInput(true) end
        end
        self.capture:Hide()
    end
    self.captureAction = nil
    self.endingCapture = nil
end
function UI:ClearInputFocus()
    for _, page in pairs(self.pages or {}) do
        if page.search then page.search:ClearFocus() end
        if page.idInput then page.idInput:ClearFocus() end
        if page.transfer then page.transfer:ClearFocus() end
    end
    if self.picker and self.picker.search then self.picker.search:ClearFocus() end
    if self.nameDialog and self.nameDialog.input then self.nameDialog.input:ClearFocus() end
    if self.library and self.library.search then self.library.search:ClearFocus() end
    if self.operationErrorDialog then self.operationErrorDialog.text:ClearFocus() end
    if K.ItemsUI and K.ItemsUI.ClearFocus then K.ItemsUI:ClearFocus() end
    if K.SettingsUI and K.SettingsUI.ClearFocus then K.SettingsUI:ClearFocus() end
end
function UI:LinkedBindings(action)
    local group={}
    if action and action.barSlot and action.form and action.form~="all" then
        for _,candidate in ipairs((self.plan or {}).actions or {}) do
            if candidate.barSlot==action.barSlot and candidate.form and candidate.form~="all" then group[#group+1]=candidate end
        end
    end
    if #group==0 and action then group[1]=action end
    return group
end
local function groupIDs(group)
    local ids={}; for _,action in ipairs(group) do ids[action.id]=true end; return ids
end
local function groupOverlaps(group,other)
    for _,action in ipairs(group) do
        if (action.form or "all")=="all" or (other.form or "all")=="all" or action.form==other.form then return true end
    end
    return false
end
local function sameGroupScope(a,b)
    local left,right={},{}
    for _,action in ipairs(a) do left[action.form or "all"]=true end
    for _,action in ipairs(b) do right[action.form or "all"]=true end
    for form in pairs(left) do if not right[form] then return false end end
    for form in pairs(right) do if not left[form] then return false end end
    return true
end
function UI:AssignBinding(action, key)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return false end
    if not action then return false end
    if action.preserved or self:IsProtectedKey(key) then self:Notice("This control is protected in Settings. Turn off its category to edit it.",true); return false end
    if action.presetName then
        local ok,why=self:Call(K.Presets,"SetHotkey",action.presetName,key)
        if ok then self:EndCapture(); if self.picker then self.picker:Hide() end; self:Refresh(); self:Notice(why or "Hot Swap key saved. Choose Apply & save to enable it.") end
        return ok
    end
    key = K.API and K.API.NormalizeKey and K.API:NormalizeKey(key) or key
    if not key then self:Notice("Choose a valid key.", true); return false end
    local system = action.kind == "system" or action.category == "System"
    if key:find("ALT%-") and (not system or (key ~= "ALT-`" and key ~= "ALT-MOUSEWHEELUP" and key ~= "ALT-MOUSEWHEELDOWN")) then
        self:Notice("Alt is reserved for self-cast, camera zoom, and auto-run.", true); return false
    end
    local reserved = {W=true,A=true,S=true,D=true,SPACE=true,TAB=true,ESCAPE=true,ENTER=true}
    if (reserved[key] and not system) or key:match("BUTTON[12]$") then
        self:Notice("That key is reserved for movement or targeting. Choose a free key.", true); return false
    end
    local group=self:LinkedBindings(action)
    local selectedIDs=groupIDs(group)
    local collisions={}
    for _,other in ipairs((self.plan or {}).actions or {}) do
        if not selectedIDs[other.id] and groupOverlaps(group,other) and (other.key==key or other.selfKey==key) then collisions[#collisions+1]=other end
    end
    if #collisions>0 then
        local other=collisions[1]
        for _,candidate in ipairs(collisions) do if candidate.form==action.form then other=candidate; break end end
        local otherGroup=self:LinkedBindings(other)
        local otherIDs=groupIDs(otherGroup)
        local oldKey=action.key and K.API and K.API.NormalizeKey and K.API:NormalizeKey(action.key) or action.key
        local canSwap=not system and other.kind~="system" and other.category~="System" and sameGroupScope(group,otherGroup)
            and oldKey and oldKey~=key and not oldKey:find("ALT%-") and not reserved[oldKey] and not oldKey:match("BUTTON[12]$")
        if canSwap then
            for _,candidate in ipairs(collisions) do if not otherIDs[candidate.id] or candidate.key~=key then canSwap=false; break end end
            for _,candidate in ipairs(group) do if candidate.key~=oldKey then canSwap=false; break end end
            for _,candidate in ipairs(otherGroup) do if candidate.key~=key then canSwap=false; break end end
        end
        if canSwap then
            for _,candidate in ipairs((self.plan or {}).actions or {}) do
                if not selectedIDs[candidate.id] and not otherIDs[candidate.id] and groupOverlaps(otherGroup,candidate) and (candidate.key==oldKey or candidate.selfKey==oldKey) then canSwap=false; break end
            end
        end
        if canSwap then
            self:EndCapture()
            if self.picker then self.picker:Hide() end
            local linked=#group>1 or #otherGroup>1
            local detail=keyName(key).." -> "..(action.label or action.id).."\n"..keyName(oldKey).." -> "..(other.label or other.id)
                ..(linked and "\n\nBoth action-bar positions change in every form." or "\n\nBoth changes will be saved together in this preset.")
            self:Confirm(linked and "Swap these action-bar positions?" or "Swap these bindings?",detail,function()
                local overrides=copy(settings().bindingOverrides)
                for _,candidate in ipairs(group) do overrides[candidate.id]=key end
                for _,candidate in ipairs(otherGroup) do overrides[candidate.id]=oldKey end
                UI.selectedAction=action
                UI:Stage("bindingOverrides",overrides)
                UI:Notice(linked and "Positions swapped in every form. Apply & save installs them." or "Bindings swapped in this preset. Apply & save installs them.")
            end)
            return false
        end
        local why=keyName(key).." is used by "..(other.label or other.id)..". Choose a free key, or rebind that action first."
        self:Notice(why,true)
        if self.capture and self.capture:IsShown() then self.captureHint:SetText(why) end
        if self.picker and self.picker:IsShown() then self.picker.note:SetText(why); color(self.picker.note,C.error) end
        return false
    end
    -- Replacing an existing game binding is expected when installing a preset.
    -- This edit is only staged; the explicit Apply & save action performs it.
    local overrides = copy(settings().bindingOverrides)
    for _,candidate in ipairs(group) do overrides[candidate.id]=key end
    self:EndCapture()
    if self.picker then self.picker:Hide() end
    self.selectedAction = action
    self:Stage("bindingOverrides", overrides)
    self:Notice((#group>1 and "Position saved in every form: " or "Binding saved to ") .. keyName(key) .. ". Apply & save installs it.")
    return true
end
function UI:CaptureInput(key)
    if key == "ESCAPE" then self:EndCapture(); return end
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or key == "UNKNOWN" then return end
    if self.captureMode == "mouse" then
        local number = tonumber(key:match("^BUTTON(%d+)$"))
        if not number or number < 4 then
            self.captureHint:SetText("Press a side button (Mouse 4 or higher). Escape finishes.")
            return
        end
        local buttons = copy(settings().mouseButtons)
        buttons[key] = true
        self:Call(K, "UpdateSetting", "mouseButtons", buttons)
        self.captureHint:SetText(keyName(key) .. " recorded. Press another side button, or Escape to finish.")
        self:Refresh()
        return
    end
    if key == "BUTTON1" or key == "BUTTON2" then
        self.captureHint:SetText("Left and right mouse clicks stay available for movement and targeting.")
        return
    end
    local full = modifiers(key)
    local a = self.captureAction
    if self.captureMode == "preset" then
        if full:find("ALT%-") then self.captureHint:SetText("Alt stays reserved for self-cast. Use a free key, Shift, or Ctrl."); return end
        local ok, why = self:Call(K.Presets, "SetHotkey", a.presetName, full)
        if ok then self:EndCapture(); self:Refresh(); self:Notice("Hot Swap key saved. Choose Apply & save to enable the updated shortcut.")
        elseif why then self.captureHint:SetText(why) end
        return
    end
    local system = a and (a.kind=="system" or a.category=="System")
    if full:find("ALT%-") and not system then
        self.captureHint:SetText("Alt is reserved for self-cast. Use the key alone, Shift, or Ctrl.")
        return
    end
    self:AssignBinding(a, full)
end
function UI:BeginActionCapture(action)
    if not action then return end
    if action.preserved then self:Notice("This control is protected in Settings. Its current game binding is kept."); return end
    if action.presetID and K.Presets and K.Presets.FindID then
        local name=K.Presets:FindID(action.presetID)
        if name then action.presetName=name end
    end
    self:BeginCapture(action.presetName and "preset" or "key",action)
end
function UI:BeginCapture(mode, action)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    if InCombatLockdown and InCombatLockdown() then self:Notice("Rebinding is paused during combat.", true); return end
    self:CloseMenu()
    self:ClearInputFocus()
    if not self.capture then
        local f = box("Frame", self.frame, C.bg, "KeybindOptimizerCapture")
        f:SetAllPoints(self.frame)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(self.frame:GetFrameLevel() + 60)
        f:EnableMouse(true)
        f:EnableMouseWheel(true)
        local title = label(f, "", 22, C.accent)
        title:SetPoint("TOPLEFT", 64, -168)
        title:SetWidth(730)
        local hint = label(f, "", 14, C.text)
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
        hint:SetWidth(730)
        local note = label(f, "", 12, C.muted)
        note:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -22)
        note:SetWidth(730)
        local cancel = button(f, "Cancel", 120, function() UI:EndCapture(); UI:Refresh() end)
        cancel:SetPoint("BOTTOMRIGHT", -40, 40)
        f.targetLabel=label(f,"Targeting",12,C.text); f.targetLabel:SetPoint("TOPLEFT",64,-329)
        f.targetMode=button(f,"Default",190,function(self) UI:OpenTargetMenu(self) end)
        f.targetMode:SetPoint("TOPLEFT",155,-320)
        f.talents=button(f,"Talent choices",150,function()
            local selected=UI.captureAction; UI:EndCapture()
            if selected then UI:OpenTalentChoices(selected) end
        end)
        f.talents:SetPoint("TOPLEFT",64,-368)
        local function dispatch(key)
            UI.captureDispatch=true
            local ok, why=pcall(UI.CaptureInput,UI,key)
            UI.captureDispatch=nil
            if not ok then error(why) end
        end
        f:SetScript("OnKeyDown", function(owner, key)
            if UI.menu and UI.menu:IsShown() then if key=="ESCAPE" then UI:CloseMenu() end; return end
            if key == "ESCAPE" then
                -- Keep keyboard propagation disabled for the entire key event.
                owner:SetScript("OnUpdate", function(self) self:SetScript("OnUpdate", nil); UI:EndCapture() end)
            else dispatch(key) end
        end)
        f:SetScript("OnMouseDown", function(_, key) dispatch(mouseKey(key)) end)
        f:SetScript("OnMouseWheel", function(_, delta) dispatch(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
        f:SetScript("OnHide", function() UI:EndCapture() end)
        self.capture, self.captureTitle, self.captureHint = f, title, hint
        self.captureNote, self.captureDone = note, cancel
    end
    self.captureMode, self.captureAction = mode, action
    self:BeginModal(self.capture, "KeybindOptimizerCapture")
    self.captureTitle:SetText(mode == "mouse" and "Record your mouse buttons" or (mode == "preset" and "Hot Swap key for " or "Edit ") .. tostring(action.label or action.id))
    self.captureHint:SetText(mode == "mouse" and "Press each side button once." or "Press the new key, mouse button, or wheel direction. Hold Shift or Ctrl if needed.")
    local linked=mode=="key" and #self:LinkedBindings(action)>1
    self.captureNote:SetText(mode == "mouse" and "Recorded buttons are kept. Escape or Done finishes. Apply & save installs your changes." or (linked and "Escape cancels. This action-bar position changes in every form. Apply & save installs it." or "Escape cancels this key change. Apply & save installs your changes."))
    self.captureDone.text:SetText(mode == "mouse" and "Done" or (mode=="key" and "Done" or "Cancel"))
    self.capture.talents:SetShown(mode=="key" and self.CanEditTalentChoices and self:CanEditTalentChoices(action) or false)
    self:RenderCaptureTarget()
    if self.capture.targetMode:IsShown() then self.captureHint:SetText("Press a new key to rebind, or choose Targeting below. Hold Shift or Ctrl for a modified key.") end
    self.capture:EnableKeyboard(true)
    if self.capture.SetPropagateKeyboardInput then self.capture:SetPropagateKeyboardInput(false) end
    self.capture:Show()
end

function UI:SetNativeBarPreference(toggle,shown)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return false end
    if type(shown)~="boolean" then return false end
    -- Required bars come from the planned layout, not the stored preference.
    -- Recheck the row before staging so a stale checkbox cannot hide one.
    local options=K.NativeBars:GetBarOptions(self.plan,settings())
    for _,option in ipairs(options) do
        if option.toggle==toggle and option.available and not option.required then
            local preferences=copy(settings().nativeBars)
            preferences[toggle]=shown
            self:Stage("nativeBars",preferences)
            return true
        end
    end
    return false
end
function UI:RenderNativeBars()
    local f=self.nativeBarsDialog
    if not f or not f:IsShown() then return end
    local options=K.NativeBars:GetBarOptions(self.plan,settings())
    for _,row in ipairs(f.rows) do row:Hide() end
    for index,option in ipairs(options) do
        local row=f.rows[index]
        if not row then
            row=listRow(f); row:SetSize(760,44)
            row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.check:SetSize(26,26); row.check:SetPoint("LEFT",6,0)
            if row.check.text then row.check.text:Hide() end
            row.name=label(row,"",12); row.name:SetPoint("TOPLEFT",43,-6)
            row.current=label(row,"",10,C.muted); row.current:SetPoint("TOPLEFT",43,-24)
            row.state=label(row,"",11,C.muted); row.state:SetPoint("RIGHT",-12,0)
            row.state:SetWidth(350); row.state:SetJustifyH("RIGHT")
            local function toggle() UI:SetNativeBarPreference(row.option.toggle,not row.effective) end
            row:SetScript("OnClick",toggle); row.check:SetScript("OnClick",toggle)
            f.rows[index]=row
        end
        local effective=option.requested
        if effective==nil then effective=option.shown end
        if option.required then effective=true end
        row.option,row.effective=option,effective and true or false
        row:SetPoint("TOPLEFT",50,-120-(index-1)*47)
        row.name:SetText(option.label); color(row.name,option.available and C.text or C.muted)
        row.current:SetText(option.available and (option.shown and "Currently shown" or "Currently hidden") or "This client does not provide this bar.")
        if not option.available then row.state:SetText("Unavailable on this client")
        elseif option.required then row.state:SetText("Required by preset")
        elseif option.requested==nil then row.state:SetText("Keep current visibility")
        else row.state:SetText(option.requested and "Show when applied" or "Hide when applied") end
        color(row.state,option.required and C.accent or C.muted)
        row.check:SetChecked(row.effective)
        row:SetEnabled(option.available and not option.required)
        row.check:SetEnabled(option.available and not option.required)
        tooltip(row,option.label,option.required and "Hot Swap enables this bar automatically so the preset's actions remain visible." or option.available and "Choose its visibility for this preset. Apply & save installs the change." or "This client does not provide the bar, so it cannot be enabled here.")
        row:Show()
    end
end
function UI:OpenNativeBars()
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    self:CloseMenu(); self:ClearInputFocus()
    if not self.nativeBarsDialog then
        local f=box("Frame",self.frame,C.bg,"KeybindOptimizerNativeBars")
        f:SetAllPoints(self.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+50)
        f:EnableMouse(true); f.rows={}
        label(f,"Action bars",22):SetPoint("TOPLEFT",50,-43)
        local note=label(f,"Bars needed by this preset are always enabled. Choose which other Blizzard bars to show.\nThese preferences stay in the draft until you choose Apply & save.",12,C.muted)
        note:SetPoint("TOPLEFT",50,-80); note:SetWidth(755)
        f.reset=button(f,"Use defaults",145,function() UI:Stage("nativeBars",{}) end)
        f.reset:SetPoint("BOTTOMLEFT",50,50)
        tooltip(f.reset,"Use default bar visibility","Clear explicit choices. Required bars stay enabled; unused bars keep their current visibility when you choose Apply & save.")
        f.done=button(f,"Done",110,function() f:Hide() end,true); f.done:SetPoint("BOTTOMRIGHT",-50,50)
        f:SetScript("OnHide",function() UI:EndModal(f) end)
        self.nativeBarsDialog=f
    end
    self:BeginModal(self.nativeBarsDialog,"KeybindOptimizerNativeBars")
    self.nativeBarsDialog:Show(); self:RenderNativeBars()
end

function UI:BuildSetup(page)
    local head = label(page, "Controls", 18)
    head:SetPoint("TOPLEFT")
    local sub = label(page, "Choose your controls, then Optimize to fill Blizzard's action bars.", 11, C.muted)
    sub:SetPoint("TOPLEFT", 0, -28)
    local flavor = button(page, "Game version", 190, function(self)
        UI:Menu(self, {{value="auto",label="Auto-detect client"},{value="forever",label="WoW Forever"},{value="era",label="Classic Era"},{value="retail",label="Retail"}}, settings().flavor or "auto", function(v) UI:Stage("flavor", v) end)
    end)
    flavor:SetPoint("TOPLEFT", 0, -55)
    local detect = button(page, "Record side buttons", 180, function() UI:BeginCapture("mouse") end)
    detect:SetPoint("TOPLEFT", 205, -55)
    local reset = button(page, "Use two buttons", 145, function() UI:Stage("mouseButtons", {BUTTON4=true, BUTTON5=true}) end)
    reset:SetPoint("TOPLEFT", 400, -55)
    local hardware = label(page, "", 11, C.muted)
    hardware:SetPoint("TOPLEFT", 0, -95)
    hardware:SetWidth(620)
    page.flavor, page.hardware, page.checks = flavor, hardware, {}
    local opts = {
        {"Use the mouse wheel", "Keep Alt + wheel for camera zoom.", "wheel"},
        {"Use middle click", "Adds a separate wheel-click binding.", "middle"},
        {"Use Ctrl modifiers", "Shift is available; Alt stays reserved for self-cast.", "ctrl"},
    }
    for i, opt in ipairs(opts) do page.checks[#page.checks+1] = check(page, opt[1], opt[2], opt[3], -122 - (i-1)*40) end
    local advanced = button(page, "Advanced options", 160, function()
        page.advanced:SetShown(not page.advanced:IsShown())
    end)
    advanced:SetPoint("TOPLEFT", 0, -284)
    page.nativeBars=button(page,"Action bars",145,function() UI:OpenNativeBars() end)
    page.nativeBars:SetPoint("TOPLEFT",175,-284)
    tooltip(page.nativeBars,"Blizzard action bars","Show additional native bars, inspect bars required by your preset, and distinguish hidden bars from bars unavailable on this client.")
    page.nativeNote=label(page,"Uses Blizzard's main and form bars, plus the extra bars it needs.\nFuture spells keep their places as you level.",11,C.muted)
    page.nativeNote:SetPoint("TOPLEFT",0,-249); page.nativeNote:SetWidth(615)
    local optimize=box("Frame",page)
    optimize:SetPoint("TOPRIGHT",0,0); optimize:SetSize(168,198)
    label(optimize,"Ready to play",15):SetPoint("TOPLEFT",13,-14)
    local detail=label(optimize,"Create a full-level layout using these controls.",11,C.muted)
    detail:SetPoint("TOPLEFT",13,-43); detail:SetWidth(142)
    page.optimize=button(optimize,"Optimize",140,function() UI:Optimize() end,true)
    page.optimize:SetPoint("TOPLEFT",14,-96); page.optimize:SetHeight(32)
    local note=label(optimize,"Backs up bindings and bars, then applies the new layout. Keeps your saved presets.",10,C.muted)
    note:SetPoint("TOPLEFT",13,-141); note:SetWidth(142)
    page.advanced = box("Frame", page)
    page.advanced:SetPoint("TOPLEFT", 0, -117)
    page.advanced:SetSize(625, 320)
    page.advanced:SetFrameLevel(page:GetFrameLevel() + 8)
    page.advanced:EnableMouse(true)
    page.advanced:Hide()
    label(page.advanced, "Advanced controls", 15):SetPoint("TOPLEFT", 14, -15)
    local back = button(page.advanced, "Back", 65, function() page.advanced:Hide() end)
    back:SetPoint("TOPRIGHT", -12, -10)
    local inner = CreateFrame("Frame", nil, page.advanced)
    inner:SetPoint("TOPLEFT", 14, -55)
    inner:SetSize(595, 250)
    page.checks[#page.checks+1] = check(inner, "Allow self as the final healing fallback", "Alt explicitly casts on you either way.", "selfFallback", 0)
    page.checks[#page.checks+1] = check(inner, "Allow utility macros to leave form", "Some healing and control spells require caster form.", "cancelForUtility", -37)
    page.checks[#page.checks+1] = check(inner, "Place ground spells at the cursor", "Cast immediately at the cursor instead of confirming a targeting circle.", "groundAtCursor", -74)
    page.mageLabel = label(inner, "Mage primary filler", 12)
    page.mageLabel:SetPoint("TOPLEFT", 0, -128)
    page.school = button(inner, "Frostbolt on 1", 190, function(self)
        UI:Menu(self, {{value="frost",label="Frostbolt on 1"},{value="fire",label="Fireball on 1"}}, settings().primarySchool or "frost", function(v) UI:Stage("primarySchool", v) end)
    end)
    page.school:SetPoint("TOPLEFT", 0, -150)
    page.schoolNote = label(inner, "The other filler moves to Shift+1. Pinned overrides stay unchanged.", 11, C.muted)
    page.schoolNote:SetPoint("TOPLEFT", 0, -189)
    page.schoolNote:SetWidth(570)
end

local function actionName(action)
    return action.label or action.displayName or action.spellName or action.id or "Action"
end
local modifierKeys = {LSHIFT="SHIFT-",RSHIFT="SHIFT-",LCTRL="CTRL-",RCTRL="CTRL-",LALT="ALT-",RALT="ALT-"}
local function isSpellAction(action)
    return action and not action.kind and not action.builtin
end
local function actionIcon(action)
    if not action then return nil end
    if action.displayIcon or action.icon then return action.displayIcon or action.icon end
    if action.presetName then return "Interface\\Icons\\INV_Misc_Book_09" end
    if action.itemSlot then return "Interface\\Icons\\INV_Jewelry_TrinketPVP_01" end
    if action.id == "item.mount" then return "Interface\\Icons\\Ability_Mount_RidingHorse" end
    if action.id == "item.potion" then return "Interface\\Icons\\INV_Potion_54" end
    if action.id == "item.healthstone" then return "Interface\\Icons\\INV_Stone_04" end
    if action.builtin == "cancel" then return "Interface\\Icons\\Spell_Nature_WispSplode" end
    if action.builtin then return "Interface\\Icons\\Ability_Hunter_SniperShot" end
    if isSpellAction(action) then return "Interface\\Icons\\INV_Misc_Book_09" end
    return "Interface\\Icons\\INV_Misc_Bag_08"
end
function UI:SpellAvailability(action)
    if not action then return nil end
    local descriptor=action.descriptor
    local spell=descriptor and descriptor.kind=="spell" or (not descriptor and isSpellAction(action))
    if not spell then return nil end
    local state=action.availabilityState or (action.known==false and (action.talent and "talent" or "unlearned") or "ready")
    local text=action.availabilityLabel or (state=="talent" and "Talent not learned" or state=="unlearned" and "Not learned" or "Ready")
    local tone=state=="talent" and {0.55,0.78,1,1} or C.warning
    return state,text,tone
end
function UI:IsEditorHidden(action)
    if not K.db or not K.db.preferences or K.db.preferences.showUnavailableBindings~=false then return false end
    local state=self:SpellAvailability(action)
    return state~=nil and state~="ready"
end
function UI:DisplayActions()
    local actions={}
    for _,action in ipairs((self.plan or {}).actions or {}) do actions[#actions+1]=action end
    for _,action in ipairs((self.plan or {}).preservedActions or {}) do actions[#actions+1]=action end
    return actions
end
function UI:IsProtectedKey(key)
    for _,action in ipairs((self.plan or {}).preservedActions or {}) do if action.key==key or action.selfKey==key then return true end end
    return false
end
function UI:MacroDetail(action)
    local show=not K.db or not K.db.preferences or K.db.preferences.showMacroCode~=false
    return (show and action.body) or action.source or action.id
end
function UI:IsKeyTestAvailable()
    return self.frame and self.frame:IsShown() and self.activePage == "Bindings" and self.bindingView ~= "list"
        and not (K.Engine and K.Engine.busy)
        and not (InCombatLockdown and InCombatLockdown()) and not self.escapeModal
        and not (self.menu and self.menu:IsShown()) and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
end
function UI:ResetKeyTest()
    self.testKeys, self.testExpires, self.testPrefix = {}, {}, nil
    local board = self.pages and self.pages.Bindings and self.pages.Bindings.keyboard
    for _, cap in pairs(board and board.keys or {}) do cap.pressed=false; if cap.pressGlow then cap.pressGlow:Hide() end end
end
function UI:TestKeyDown(base)
    if not self:IsKeyTestAvailable() then return end
    if base == "ESCAPE" then
        if self.libraryEntry or self.libraryDrag then self:CancelLibraryDrag() else self.testerClose = true end
        return
    end
    if base == "UNKNOWN" then return end
    self.testKeys = self.testKeys or {}
    self.testExpires = self.testExpires or {}
    self.testKeys[base] = modifiers(base)
    if modifierKeys[base] then self:RenderKeyboard(); return end
    self.testPrefix = modifiers("")
    local full = self.testKeys[base]
    local actions = self.keyIndex and self.keyIndex[full] or {}
    local names = {}
    for _, action in ipairs(actions) do names[#names+1] = (self:IsEditorHidden(action) and "Reserved unavailable spell" or actionName(action)) .. (#actions > 1 and (" (" .. (action.form or "all") .. ")") or "") end
    self.lastTest = keyName(full) .. " -> " .. (#names > 0 and table.concat(names, " / ") or "Unassigned")
    if actions[1] and not self:IsEditorHidden(actions[1]) then self.selectedAction=actions[1]; self:BindingDetail(actions[1]) end
    self.pages.Bindings.keyboard.note:SetText("Testing planned binds — no casting  |  " .. self.lastTest)
    self:RenderKeyboard()
end
function UI:TestKeyUp(base)
    if self.testKeys then self.testKeys[base]=nil end
    if self.testExpires then self.testExpires[base]=nil end
    local any
    for key in pairs(self.testKeys or {}) do if not modifierKeys[key] then any=true; break end end
    if not any then self.testPrefix=nil end
    self:RenderKeyboard()
end
function UI:AttachTestMouse(frame, preserveWheel)
    frame:EnableMouse(true)
    if not preserveWheel then frame:EnableMouseWheel(true) end
    frame:HookScript("OnMouseDown", function(_, name)
        local base=mouseKey(name)
        if base~="BUTTON1" and base~="BUTTON2" then UI:TestKeyDown(base) end
    end)
    frame:HookScript("OnMouseUp", function(_, name) UI:TestKeyUp(mouseKey(name)) end)
    if not preserveWheel then
        frame:HookScript("OnMouseWheel", function(_, delta)
            if not UI:IsKeyTestAvailable() then return end
            local base=delta>0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
            UI:TestKeyDown(base)
            UI.testExpires[base]=(GetTime and GetTime() or 0)+0.18
        end)
    end
end
function UI:UpdateBindingTester()
    local available=self:IsKeyTestAvailable()
    local mouseContext=self.frame and self.frame:IsShown() and self.activePage=="Bindings" and self.bindingView~="list" and not (K.Engine and K.Engine.busy) and not (InCombatLockdown and InCombatLockdown())
    local sink=mouseContext and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) and not (self.escapeModal and self.escapeModal==self.capture)
    if not sink then
        if self.tester then self.tester:Hide() end
        if self.testMouseShield then self.testMouseShield:SetShown(mouseContext and true or false) end
        self:ResetKeyTest()
        local board=self.pages and self.pages.Bindings and self.pages.Bindings.keyboard
        if board then
            if InCombatLockdown and InCombatLockdown() then board.note:SetText("Key testing paused during combat. Normal game controls are active.")
            else board.note:SetText("Key testing paused while editing. Return to the keyboard to test bindings.") end
        end
        return
    end
    if not self.tester then
        -- Configure keyboard capture only out of combat. No propagation setting
        -- is changed in a key handler or when combat begins; hiding releases it.
        local listener=CreateFrame("Frame", nil, self.frame)
        listener:SetAllPoints(self.frame)
        listener:EnableKeyboard(true)
        if listener.SetPropagateKeyboardInput then listener:SetPropagateKeyboardInput(false) end
        listener:SetScript("OnKeyDown", function(_, key)
            if key=="ESCAPE" and not UI:IsKeyTestAvailable() then
                UI.testerDismiss=UI.escapeModal or (UI.menu and UI.menu:IsShown() and UI.menu) or nil
            else UI:TestKeyDown(key) end
        end)
        listener:SetScript("OnKeyUp", function(_, key) UI:TestKeyUp(key) end)
        listener:SetScript("OnUpdate", function(owner, elapsed)
            if UI.testerClose then UI.testerClose=nil; UI.frame:Hide(); return end
            if UI.testerDismiss then local target=UI.testerDismiss; UI.testerDismiss=nil; target:Hide(); UI:UpdateBindingTester(); return end
            if not UI:IsKeyTestAvailable() then UI:UpdateBindingTester(); return end
            owner.elapsed=(owner.elapsed or 0)+elapsed
            if owner.elapsed<0.05 then return end
            owner.elapsed=0
            local now=GetTime and GetTime() or 0
            local released={}
            for key in pairs(UI.testKeys or {}) do
                local expiry=UI.testExpires and UI.testExpires[key]
                if (expiry and now>=expiry) or (not expiry and not key:match("^BUTTON%d+$") and IsKeyDown and IsKeyDown(key)==false) then released[#released+1]=key end
            end
            for _, key in ipairs(released) do UI:TestKeyUp(key) end
        end)
        self.tester=listener
        -- A mouse-only shield behind this window prevents clicks or wheel input
        -- over the world/action bars from executing while preview testing.
        local shield=CreateFrame("Frame", nil, UIParent)
        shield:SetAllPoints(UIParent); shield:SetFrameStrata("HIGH"); shield:SetFrameLevel(math.max(0,self.frame:GetFrameLevel()-1))
        self:AttachTestMouse(shield)
        self.testMouseShield=shield
    end
    self.testMouseShield:Show()
    self.tester:Show()
    if available then
        self.pages.Bindings.keyboard.note:SetText(self.lastTest and ("Testing planned binds — no casting  |  " .. self.lastTest) or "Test keys here — no casting. Click to rebind. L = unlearned; T = talent.")
    else
        self:ResetKeyTest()
        self.pages.Bindings.keyboard.note:SetText("Choose an action or press Escape to return to key testing. No casting.")
    end
end
local function makeKey(parent, base, caption, x, y, width, height, mouse)
    local b = box("Button", parent, C.field)
    b:SetSize(width, height)
    b:SetPoint("TOPLEFT", x, -y)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.035, 0.03, 0.022, 0.95)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.pressGlow=b:CreateTexture(nil,"OVERLAY")
    b.pressGlow:SetPoint("TOPLEFT",3,-3); b.pressGlow:SetPoint("BOTTOMRIGHT",-3,3)
    b.pressGlow:SetColorTexture(1,0.82,0.1,0.32); b.pressGlow:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    local iconSize = mouse and 22 or (height < 30 and 10 or 18)
    b.icon:SetSize(iconSize, iconSize)
    b.icon:SetPoint(mouse and "LEFT" or "BOTTOM", mouse and 8 or 0, mouse and 0 or 4)
    b.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    b.caption = label(b, caption or keyName(base), mouse and 10 or (height < 30 and 8 or 9), C.text)
    b.caption:SetPoint(mouse and "TOPLEFT" or "TOP", mouse and 36 or 0, mouse and -7 or (height < 30 and -2 or -4))
    b.caption:SetJustifyH(mouse and "LEFT" or "CENTER")
    b.caption:SetWidth(width - (mouse and 38 or 4))
    b.caption:SetWordWrap(false)
    b.caption:SetHeight(mouse and 12 or (height < 30 and 9 or 11))
    b.tag = label(b, "", mouse and 9 or 7, C.muted)
    b.tag:SetPoint(mouse and "BOTTOMLEFT" or "BOTTOM", mouse and 36 or 0, mouse and 6 or 4)
    b.tag:SetWidth(width - (mouse and 38 or 4))
    b.tag:SetWordWrap(false)
    b.tag:SetJustifyH(mouse and "LEFT" or "CENTER")
    b.count = label(b, "", 9, C.accent)
    b.count:SetPoint("BOTTOMRIGHT", -3, 2)
    b.lockBadge=label(b,"L",8,C.warning)
    b.lockBadge:SetPoint("BOTTOMLEFT",4,3); b.lockBadge:Hide()
    b.targetBadge=label(b,"",7,{0.55,0.82,1,1})
    b.targetBadge:SetPoint("TOPRIGHT",-4,-3); b.targetBadge:SetWidth(15); b.targetBadge:SetJustifyH("RIGHT")
    b.base = base
    b:SetScript("OnClick", function() UI:KeyboardKeyClick(base) end)
    b:SetScript("OnReceiveDrag",function() if UI.libraryDrag then UI:DropLibraryEntry(b.fullKey) end end)
    UI:AttachTestMouse(b)
    return b
end
function UI:BuildKeyboard(page)
    local board = CreateFrame("Frame", nil, page)
    board:SetPoint("TOPLEFT", 0, -78)
    board:SetSize(804, 266)
    board.keys, board.mouseCaps = {}, {}
    page.keyboard = board
    local function key(base, caption, x, y, w, h)
        board.keys[base] = makeKey(board, base, caption, x, y, w, h or 39)
    end
    key("ESCAPE", "Esc", 0, 0, 40, 26)
    for i=1,12 do key("F"..i, "F"..i, 50+(i-1)*45, 0, 41, 26) end
    local numbers = {"`","1","2","3","4","5","6","7","8","9","0","-","="}
    for i, base in ipairs(numbers) do key(base, base, (i-1)*42, 31, 39) end
    key("BACKSPACE", "Backspace", 546, 31, 74)
    key("TAB", "Tab", 0, 74, 56)
    local top = {"Q","W","E","R","T","Y","U","I","O","P","[","]","\\"}
    for i, base in ipairs(top) do key(base, base, 59+(i-1)*43, 74, 40) end
    key("CAPSLOCK", "Caps", 0, 117, 67)
    local home = {"A","S","D","F","G","H","J","K","L",";","'"}
    for i, base in ipairs(home) do key(base, base, 70+(i-1)*43, 117, 40) end
    key("ENTER", "Enter", 543, 117, 77)
    key("LSHIFT", "Shift", 0, 160, 88)
    local lower = {"Z","X","C","V","B","N","M",",",".","/"}
    for i, base in ipairs(lower) do key(base, base, 91+(i-1)*43, 160, 40) end
    key("RSHIFT", "Shift", 521, 160, 99)
    key("LCTRL", "Ctrl", 0, 203, 67, 34)
    key("LALT", "Alt", 70, 203, 67, 34)
    key("SPACE", "Space", 140, 203, 320, 34)
    key("RALT", "Alt", 463, 203, 77, 34)
    key("RCTRL", "Ctrl", 543, 203, 77, 34)
    board.note = label(board, "Test keys here — no casting. Click to rebind. L = unlearned; T = talent.", 10, C.muted)
    board.note:SetPoint("TOPLEFT", 0, -247)
    board.note:SetWidth(800)
    label(board, "MOUSE", 10, C.muted):SetPoint("TOPLEFT", 644, -7)
    self:AttachTestMouse(board)
end
local actionPageNames={caster="Base",cat="Cat",bear="Bear",moonkin="Moonkin",all="All pages"}
function UI:CacheActionPages()
    self.availableActionPages={caster=true}
    for _,action in ipairs((self.plan or {}).actions or {}) do
        if action.form=="cat" or action.form=="bear" or action.form=="moonkin" then self.availableActionPages[action.form]=true end
    end
    self.previewForms=K.API and K.API.GetForms and K.API:GetForms() or {}
end
function UI:CurrentActionPage()
    local current="caster"
    if K.API and K.API.GetActiveActionPage then current=K.API:GetActiveActionPage(settings(),self.previewForms or {})
    else
        local index=GetShapeshiftForm and GetShapeshiftForm() or 0
        for kind,form in pairs(self.previewForms or {}) do if form.index==index then current=kind; break end end
    end
    if current=="prowl" then current="cat" end
    if not (self.availableActionPages or {})[current] then current="caster" end
    return current
end
function UI:SetActionPage(value)
    if value=="prowl" then value="cat" end
    if value~="all" and not (self.availableActionPages or {})[value] then value="caster" end
    self.followForm=false; self.formFilter=value
    self:ResetKeyTest(); self:RenderBindings(true)
end
function UI:SetFollowForm(value)
    self.followForm=value and true or false
    self:ResetKeyTest(); self:RenderBindings(true)
end
function UI:ActionPageChanged()
    if self.activePage~="Bindings" or self.followForm==false or self.escapeModal then return end
    local current=self:CurrentActionPage()
    if self.formFilter~=current then self.formFilter=current; self:ResetKeyTest(); self:RenderBindings(true) end
end
function UI:IndexKeyboard(reuseIcons)
    local page = self.pages.Bindings
    self.keyIndex = {}
    if not reuseIcons or not self.keyIcons then self.keyIcons = {} end
    local filter = self.formFilter or "all"
    for _, a in ipairs(self:DisplayActions()) do
        if not reuseIcons or self.keyIcons[a.id]==nil then self.keyIcons[a.id] = a.displayIcon or a.icon or (a.itemSlot and GetInventoryItemTexture and GetInventoryItemTexture("player", a.itemSlot)) or actionIcon(a) end
        if filter == "all" or a.form == "all" or not a.form or a.form == filter then
            for _, key in ipairs({a.key or false, a.selfKey or false}) do
                if key then
                    self.keyIndex[key] = self.keyIndex[key] or {}
                    self.keyIndex[key][#self.keyIndex[key]+1] = a
                end
            end
        end
    end
    local mouse = {"MOUSEWHEELUP", "MOUSEWHEELDOWN", "BUTTON3"}
    local side = {}
    for key, enabled in pairs(settings().mouseButtons or {}) do if enabled then side[#side+1]=key end end
    table.sort(side, function(a,b) return (tonumber(a:match("%d+")) or 0) < (tonumber(b:match("%d+")) or 0) end)
    for _, key in ipairs(side) do mouse[#mouse+1]=key end
    for _, cap in ipairs(page.keyboard.mouseCaps) do cap:Hide(); page.keyboard.keys[cap.base]=nil end
    local height = #mouse > 5 and 27 or 39
    for i, base in ipairs(mouse) do
        if i <= 8 then
            local cap = page.keyboard.mouseCaps[i]
            if not cap then cap=makeKey(page.keyboard,base,keyName(base),644,31,156,height,true); page.keyboard.mouseCaps[i]=cap end
            cap.base = base
            cap:SetScript("OnClick", function() UI:KeyboardKeyClick(base) end)
            cap:ClearAllPoints(); cap:SetPoint("TOPLEFT", 644, -31-(i-1)*(height+3)); cap:SetHeight(height)
            cap.caption:SetText(keyName(base))
            cap:Show()
            page.keyboard.keys[base]=cap
        end
    end
end
function UI:RenderKeyboard()
    local page = self.pages and self.pages.Bindings
    if not page or not page.keyboard then return end
    local held = modifiers("")
    local prefix = self.testPrefix ~= nil and self.testPrefix or (held ~= "" and held or self.pinnedLayer or "")
    self.modifierPrefix = prefix
    for layer, b in pairs(page.layers) do color(b.text, prefix == layer and C.accent or C.muted) end
    page.layerHint:SetText(prefix:find("ALT%-") and "Alt: self-cast + camera / auto-run" or "Hold modifiers; Alt = self-cast.")
    local mods = modifierKeys
    for base, cap in pairs(page.keyboard.keys) do
        local full = prefix .. base
        cap.actions = self.keyIndex and self.keyIndex[full] or {}
        cap.action, cap.fullKey = cap.actions[1], full
        local a = cap.action
        local hidden=self:IsEditorHidden(a)
        local state,status,tone=self:SpellAvailability(a)
        tone=tone or C.warning
        cap.alias = a and a.selfKey == full and a.key ~= full or false
        cap.icon:SetShown(a ~= nil and not hidden and (a.kind ~= "system" or a.presetName~=nil))
        cap.icon:SetTexture(a and ((self.keyIcons or {})[a.id] or actionIcon(a)) or nil)
        cap.locked = state~=nil and state~="ready" and not hidden or false
        cap.icon:SetAlpha(cap.locked and 0.85 or 1)
        if cap.icon.SetDesaturated then cap.icon:SetDesaturated(cap.locked) end
        cap.icon:SetVertexColor(unpack(cap.locked and tone or C.white))
        cap.lockBadge:SetShown(cap.locked)
        cap.lockBadge:SetText(state=="talent" and "T" or "L"); color(cap.lockBadge,tone)
        local badge,target=self:TargetDescription(a)
        cap.targetBadge:SetText(badge or ""); cap.targetBadge:SetShown(badge~=nil and not hidden)
        if cap.SetBackdropBorderColor then cap:SetBackdropBorderColor(unpack(cap.locked and tone or C.edge)) end
        cap.pressed = self.testKeys and self.testKeys[base] ~= nil or false
        if mods[base] then
            local down = mods[base]=="SHIFT-" and IsShiftKeyDown or (mods[base]=="CTRL-" and IsControlKeyDown or IsAltKeyDown)
            cap.pressed = self:IsKeyTestAvailable() and down and down() or false
        end
        cap.pressGlow:SetShown(cap.pressed)
        cap.tag:SetText(hidden and "Reserved" or (a and a.kind == "system" and not a.presetName and actionName(a) or ""))
        cap.count:SetText(#cap.actions > 1 and tostring(#cap.actions) or (cap.alias and "S" or ""))
        color(cap.caption, mods[base] and prefix:find(mods[base],1,true) and C.accent or (a and C.text or C.muted))
        local detail = {}
        for _, action in ipairs(cap.actions) do
            local actionState,actionStatus=self:SpellAvailability(action)
            detail[#detail+1] = self:IsEditorHidden(action) and "Reserved unavailable spell. Enable Show unavailable spells in Settings to inspect it." or (actionName(action) .. " (" .. (action.form or "all") .. ")" .. (actionState and actionState~="ready" and " — "..actionStatus or action.known==false and " — "..(action.itemAvailability or "unavailable") or ""))
        end
        if mods[base] then detail={"Click to preview this modifier layer. Hold the physical key to preview combinations."}
        elseif cap.alias then detail[#detail+1]="Self-cast alias. Edit the normal binding to move both keys."
        elseif #detail == 0 then detail[1]="Unassigned. Click to choose an action." end
        if target and not hidden then detail[#detail+1]="Targeting: "..target end
        if a and a.preserved then detail[#detail+1]="Protected in Settings. Current game binding is kept." end
        tooltip(cap, keyName(full), table.concat(detail,"\n"), not hidden and a and (a.displaySpellID or a.spellID), cap.locked and status or nil,a and a.itemID)
    end
end
function UI:KeyboardKeyClick(base)
    local cap=self.pages.Bindings.keyboard.keys[base]
    if self.libraryEntry and cap then self:DropLibraryEntry(cap.fullKey); return end
    local modifier = {LSHIFT="SHIFT-",RSHIFT="SHIFT-",LCTRL="CTRL-",RCTRL="CTRL-",LALT="ALT-",RALT="ALT-"}
    if modifier[base] then
        self.pinnedLayer = self.pinnedLayer == modifier[base] and "" or modifier[base]
        self:RenderKeyboard(); return
    end
    local cap = self.pages.Bindings.keyboard.keys[base]
    if not cap then return end
    local function selectAction(action)
        if UI:IsEditorHidden(action) then UI:Notice("This key is reserved. Enable Show unavailable spells in Settings to edit it."); return end
        UI.selectedAction = action
        UI:BindingDetail(action)
        if cap.alias then UI:Notice("Self-cast follows " .. keyName(action.key) .. ". Rebind the normal action to move both.") end
        UI:BeginActionCapture(action)
    end
    if #cap.actions > 1 then
        local options = {}
        for _, action in ipairs(cap.actions) do options[#options+1]={value=action,label=actionName(action).." · "..(action.form or "all")} end
        self:Menu(cap,options,nil,selectAction)
    elseif cap.action then selectAction(cap.action)
    elseif (cap.fullKey or ""):find("ALT%-") then self:Notice("Alt aliases are created from helpful actions. Choose their normal key to edit them.")
    else self:OpenActionPicker(cap.fullKey) end
end
function UI:OpenActionPicker(key)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    self:CloseMenu(); self:ClearInputFocus()
    if not self.picker then
        local f = box("Frame", self.frame, C.bg, "KeybindOptimizerActionPicker")
        f:SetAllPoints(self.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+50); f:EnableMouse(true)
        f.title=label(f,"Choose an action",20); f.title:SetPoint("TOPLEFT",40,-42)
        f.note=label(f,"",11,C.muted); f.note:SetPoint("TOPLEFT",40,-77); f.note:SetWidth(775)
        local shell, search = edit(f, 580, 30); shell:SetPoint("TOPLEFT",40,-109); f.search=search
        search:SetScript("OnTextChanged",function(_,user) if user then UI:RenderActionPicker() end end)
        search:SetScript("OnEscapePressed",function() f:Hide() end)
        tooltip(shell,"Find an action","Search spells, actions, categories, and existing keys. Includes reserved talent slots.")
        local cancel=button(f,"Cancel",100,function() f:Hide() end); cancel:SetPoint("TOPRIGHT",-40,-110)
        f.list=scroll(f); f.list:SetPoint("TOPLEFT",40,-154); f.list:SetPoint("BOTTOMRIGHT",-40,40)
        f:SetScript("OnHide",function() f.search:ClearFocus(); UI:EndModal(f) end)
        self.picker=f
    end
    self.picker.key=key
    self.picker.title:SetText("Choose an action for " .. keyName(key))
    self.picker.note:SetText("Select an action to move its binding here. Other forms keep their own keys."); color(self.picker.note,C.muted)
    self.picker.search:SetText("")
    self:BeginModal(self.picker,"KeybindOptimizerActionPicker")
    self.picker:Show(); self.picker.search:SetFocus(); self:RenderActionPicker()
end
function UI:RenderActionPicker()
    local f=self.picker
    if not f then return end
    local query=string.lower(f.search:GetText() or "")
    local matches={}
    for _, a in ipairs((self.plan or {}).actions or {}) do
        local hay=string.lower(actionName(a).." "..(a.key or "").." "..(a.category or ""))
        local form=self.formFilter or "all"
        if not self:IsEditorHidden(a) and (form=="all" or not a.form or a.form=="all" or a.form==form) and (query=="" or hay:find(query,1,true)) then matches[#matches+1]=a end
    end
    local list=f.list
    for _,row in ipairs(list.rows) do row:Hide() end
    for i,a in ipairs(matches) do
        local row=list.rows[i]
        if not row then
            row=listRow(list.child); row:SetHeight(36)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",5,0)
            row.name=label(row,"",12); row.name:SetPoint("LEFT",41,0); truncate(row.name,440)
            row.key=label(row,"",11,C.muted); row.key:SetPoint("RIGHT",-9,0)
            row:SetScript("OnClick",function(self) UI:AssignBinding(self.action,UI.picker.key) end)
            list.rows[i]=row
        end
        row.action=a; row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(i-1)*38); row:SetWidth(math.max(600,list.child:GetWidth()))
        local state,status,tone=self:SpellAvailability(a); tone=tone or C.warning
        row.icon:SetTexture(actionIcon(a))
        if row.icon.SetDesaturated then row.icon:SetDesaturated(a.known==false) end
        row.icon:SetVertexColor(unpack(a.known==false and tone or C.white))
        row.name:SetText(actionName(a)..(state and state~="ready" and " · "..status or a.known==false and " · unavailable" or "")); row.key:SetText(keyName(a.key or "Unbound"))
        color(row.name,a.known==false and tone or C.text)
        tooltip(row,actionName(a),"Click to bind this action to "..keyName(f.key)..".",a.displaySpellID or a.spellID,state and state~="ready" and status)
        row:Show()
    end
    if not list.empty then list.empty=label(list.child,"",12,C.muted); list.empty:SetPoint("TOPLEFT",10,-15) end
    list.empty:SetText(#matches==0 and "No matching actions. Clear the search or change the form filter." or "")
    list:UpdateHeight(math.max(50,#matches*38))
end

function UI:BuildBindings(page)
    label(page, "Bindings", 18):SetPoint("TOPLEFT")
    page.modeButtons = {}
    for i, mode in ipairs({"Keyboard", "List"}) do
        local b = button(page, mode, 85, function()
            UI.bindingView = mode == "List" and "list" or "keyboard"
            UI:RenderBindings()
        end)
        b:SetPoint("TOPLEFT", 123 + (i-1)*91, 3)
        page.modeButtons[mode] = b
    end
    page.libraryToggle=button(page,"Spellbook",105,function() UI:ToggleLibrary() end)
    page.libraryToggle:SetPoint("TOPLEFT",310,3)
    local searchShell, search = edit(page, 230, 30)
    page.search = search
    searchShell:SetPoint("TOPRIGHT", -2, 4)
    search:SetScript("OnTextChanged", function(self, user)
        if user then
            UI.search = string.lower(self:GetText() or "")
            if UI.search ~= "" then UI.bindingView = "list" end
            UI:RenderBindings()
        end
    end)
    tooltip(searchShell, "Search bindings", "Find an action by spell, key, category, or action ID.")
    local hint = label(page, "Search spell / key", 11, C.muted)
    hint:SetPoint("RIGHT", searchShell, "LEFT", -9, 0)
    page.tabs = {}
    page.form = button(page, "Action page: Base", 175, function(self)
        local options={}
        for _,value in ipairs({"caster","cat","bear","moonkin"}) do
            if (UI.availableActionPages or {})[value] then options[#options+1]={value=value,label=actionPageNames[value]} end
        end
        UI:Menu(self, options, UI.formFilter or "caster", function(value) UI:SetActionPage(value) end)
    end)
    page.form:SetPoint("TOPLEFT", 0, -37)
    tooltip(page.form,"Action page preview","Choose which action page to inspect. This does not change your character's form. Travel and Aquatic use Base; Prowl uses Cat.")
    page.follow=CreateFrame("CheckButton",nil,page,"UICheckButtonTemplate")
    page.follow:SetSize(24,24); page.follow:SetPoint("TOPLEFT",181,-38)
    if page.follow.text and page.follow.text.Hide then page.follow.text:Hide() end
    local followLabel=label(page.follow,"Follow form",10,C.text); followLabel:SetPoint("LEFT",26,0); followLabel:SetWidth(80)
    page.follow:SetScript("OnClick",function(self) UI:SetFollowForm(self:GetChecked()) end)
    tooltip(page.follow,"Follow your form","Keep the preview on your current action page. Turn this off, or choose a page, to inspect another form without shifting.")
    page.layers = {}
    local x = 292
    for _, layer in ipairs({{"","No mod",60},{"SHIFT-","Shift",46},{"CTRL-","Ctrl",42},{"CTRL-SHIFT-","Ctrl+Shift",77},{"ALT-","Alt",43}}) do
        local prefix = layer[1]
        local b = button(page, layer[2], layer[3], function() UI.pinnedLayer=prefix; UI:RenderKeyboard() end)
        b:SetPoint("TOPLEFT", x, -37)
        x = x + layer[3] + 4
        page.layers[prefix] = b
    end
    page.layerHint = label(page, "Hold modifiers; Alt = self-cast.", 10, C.muted)
    page.layerHint:SetPoint("TOPRIGHT", -2, -46)
    page.layerHint:SetWidth(205); page.layerHint:SetJustifyH("RIGHT")
    page.listHeader = CreateFrame("Frame", nil, page)
    page.listHeader:SetAllPoints(page)
    label(page.listHeader, "KEY", 10, C.muted):SetPoint("TOPLEFT", 10, -85)
    label(page.listHeader, "ACTION", 10, C.muted):SetPoint("TOPLEFT", 131, -85)
    label(page.listHeader, "PAGE", 10, C.muted):SetPoint("TOPLEFT", 520, -85)
    label(page.listHeader, "STATE", 10, C.muted):SetPoint("TOPRIGHT", -22, -85)
    local list = scroll(page)
    list:SetPoint("TOPLEFT", 0, -105)
    list:SetPoint("BOTTOMRIGHT", 0, 92)
    page.list = list
    local detail = box("Frame", page)
    detail:SetPoint("BOTTOMLEFT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", 0, 0)
    detail:SetHeight(80)
    detail.title = label(detail, "Select a binding", 12)
    detail.title:SetPoint("TOPLEFT", 12, -10)
    truncate(detail.title, 440)
    detail.desc = label(detail, "Press a key to test its planned action. Click an icon to rebind.", 11, C.muted)
    detail.desc:SetPoint("TOPLEFT", 12, -31)
    detail.desc:SetWidth(440)
    detail.rebind = button(detail, "Rebind", 100, function()
        if UI.selectedAction then UI:BeginActionCapture(UI.selectedAction) end
    end)
    detail.rebind:SetPoint("TOPRIGHT", -230, -12)
    detail.rebind:SetEnabled(false)
    detail.change = button(detail, "Change action", 112, function()
        if UI.selectedAction and UI.selectedAction.key then UI:OpenActionPicker(UI.selectedAction.key) end
    end)
    detail.change:SetPoint("TOPRIGHT", -112, -12)
    detail.change:SetEnabled(false)
    detail.reset = button(detail, "Reset key", 94, function()
        if not UI.selectedAction then return end
        if UI.selectedAction.presetName then UI:Call(K.Presets,"ClearHotkey",UI.selectedAction.presetName); UI:Refresh(); return end
        local overrides = copy(settings().bindingOverrides)
        for _,action in ipairs(UI:LinkedBindings(UI.selectedAction)) do overrides[action.id]=nil end
        UI:Stage("bindingOverrides", overrides)
    end)
    detail.reset:SetPoint("TOPRIGHT", -12, -12)
    detail.reset:SetEnabled(false)
    detail.note = label(detail, "Apply & save installs your changes.", 10, C.muted)
    detail.note:SetPoint("TOPLEFT", 12, -62); detail.note:SetWidth(630)
    detail.talents=button(detail,"Talent choices",128,function() if UI.selectedAction then UI:OpenTalentChoices(UI.selectedAction) end end)
    detail.talents:SetPoint("TOPRIGHT",-12,-44); detail.talents:SetEnabled(false)
    page.detail = detail
    self:BuildKeyboard(page)
end
function UI:RenderBindings(reusePageCache)
    local page = self.pages and self.pages.Bindings
    if not page then return end
    if not reusePageCache or not self.availableActionPages then self:CacheActionPages() end
    local filter=self.followForm~=false and self:CurrentActionPage() or self.formFilter or "caster"
    if filter~="all" and not self.availableActionPages[filter] then filter="caster" end
    self.formFilter = filter
    if self.lastRenderedActionPage~=filter then
        self.lastRenderedActionPage=filter; self.lastTest=nil; self:ResetKeyTest()
        local selected=self.selectedAction
        if selected and filter~="all" and selected.form and selected.form~="all" and selected.form~=filter then
            self.selectedAction=nil
            page.detail.title:SetText("Select a binding")
            page.detail.desc:SetText("Press a key to test its planned action. Click an icon to rebind.")
            page.detail.rebind:SetEnabled(false); page.detail.change:SetEnabled(false); page.detail.reset:SetEnabled(false)
            page.detail.talents:SetEnabled(false)
            page.detail:EnableMouse(false)
        end
    end
    page.form.text:SetText("Action page: "..(actionPageNames[filter] or filter))
    page.form:SetEnabled((self.plan or {}).class == "DRUID")
    page.follow:SetChecked(self.followForm~=false)
    page.follow:SetEnabled((self.plan or {}).class=="DRUID")
    local listView = self.bindingView == "list"
    page.list:SetShown(listView)
    page.listHeader:SetShown(listView)
    page.keyboard:SetShown(not listView)
    for name, b in pairs(page.modeButtons) do color(b.text, (name == "List") == listView and C.accent or C.muted) end
    self:IndexKeyboard(reusePageCache)
    self:RenderKeyboard()
    self:UpdateBindingTester()
    self:SyncLibrary(not reusePageCache)
    if self.selectedAction and self:IsEditorHidden(self.selectedAction) then self.selectedAction=nil end
    if not self.selectedAction then
        page.detail.title:SetText("Select a binding"); page.detail.desc:SetText("Press a key to test its planned action. Click an icon to rebind.")
        page.detail.rebind:SetEnabled(false); page.detail.change:SetEnabled(false); page.detail.reset:SetEnabled(false); page.detail.talents:SetEnabled(false)
        page.detail.note:SetText("Apply & save installs your changes."); page.detail:EnableMouse(false)
    end
    if self.selectedAction then
        for _, a in ipairs(self:DisplayActions()) do if a.id == self.selectedAction.id then self.selectedAction=a; break end end
        self:BindingDetail(self.selectedAction)
    end
    if not listView then return end
    local list, results = page.list, {}
    for _, a in ipairs(self:DisplayActions()) do
        local form = a.form or "all"
        local hay = string.lower(table.concat({a.label or "", a.key or "", a.id or "", a.category or "", a.spellName or ""}, " "))
        if not self:IsEditorHidden(a) and (filter == "all" or form == "all" or form == filter) and (not self.search or self.search == "" or hay:find(self.search, 1, true)) then results[#results+1] = a end
    end
    for _, row in ipairs(list.rows) do row:Hide() end
    for i, a in ipairs(results) do
        local row = list.rows[i]
        if not row then
            row = listRow(list.child)
            row:SetHeight(37)
            row.key = button(row, "", 116, function(self) UI:BeginActionCapture(self:GetParent().action) end)
            row.key:SetHeight(27)
            row.key:SetPoint("LEFT", 5, 0)
            row.name = label(row, "", 11)
            row.name:SetPoint("LEFT", 131, 0)
            truncate(row.name, 370)
            row.form = label(row, "", 10, C.muted)
            row.form:SetPoint("LEFT", 520, 0)
            truncate(row.form, 110)
            row.state = label(row, "", 10, C.muted)
            row.state:SetPoint("RIGHT", -8, 0)
            row.state:SetJustifyH("RIGHT")
            row:SetScript("OnClick", function(self)
                UI.selectedAction = self.action
                UI:RenderBindings()
            end)
            list.rows[i] = row
        end
        row.action = a
        row.selection:SetShown(self.selectedAction and self.selectedAction.id == a.id or false)
        row:SetPoint("TOPLEFT", 0, -(i-1)*39)
        row:SetWidth(math.max(560, list.child:GetWidth()))
        row.key.text:SetText(keyName(a.key or "Unbound"))
        row.key:SetEnabled(not a.preserved)
        row.name:SetText(a.label or a.spellName or a.id)
        row.form:SetText(a.form == "all" and "Every page" or (actionPageNames[a.form] or a.form or "Every page"))
        local pinned = (settings().bindingOverrides or {})[a.id]
        local state,status,tone=self:SpellAvailability(a); tone=tone or C.warning
        row.state:SetText(a.preserved and "Protected" or state and state~="ready" and status or a.known==false and "Unavailable" or (pinned and "Pinned" or "Ready"))
        color(row.name, a.known == false and tone or C.text)
        color(row.state, a.known==false and tone or (pinned and C.accent or C.muted))
        tooltip(row.key, a.label or a.id, a.preserved and "Protected in Settings. Current game binding is kept." or "Click to capture a replacement key. A pinned key is retained when the profile updates.",a.displaySpellID or a.spellID,state and state~="ready" and status)
        row:Show()
    end
    if not list.empty then list.empty = label(list.child, "", 13, C.muted); list.empty:SetPoint("TOPLEFT", 10, -18); list.empty:SetWidth(550) end
    list.empty:SetText(#results == 0 and "No matching bindings. Clear the search or select All." or "")
    list:UpdateHeight(math.max(50, #results*39))
    if self.selectedAction then
        for _, a in ipairs(self:DisplayActions()) do if a.id == self.selectedAction.id then self.selectedAction = a; break end end
        self:BindingDetail(self.selectedAction)
    end
end
function UI:BindingDetail(a)
    local d = self.pages.Bindings.detail
    d.title:SetText((a.label or a.id) .. "  /  " .. keyName(a.key or "Unbound"))
    local _,target=self:TargetDescription(a)
    local parts = {a.category or "Action",target or "Default behavior"}
    local state,status=self:SpellAvailability(a)
    if state and state~="ready" then parts[#parts+1]=status.."; key reserved"
    elseif a.known==false then parts[#parts+1]=a.itemAvailability or "Unavailable" end
    if a.preserved then parts[#parts+1]="Protected in Settings" end
    if a.previousBinding and a.previousBinding ~= "" then parts[#parts+1] = "replaces " .. bindingLabel(a.previousBinding) end
    d.desc:SetText(table.concat(parts, "  |  "))
    local linked=self:LinkedBindings(a)
    local pinned=false
    for _,action in ipairs(linked) do if (settings().bindingOverrides or {})[action.id]~=nil then pinned=true; break end end
    d.reset:SetEnabled(not a.preserved and (a.presetName~=nil or pinned))
    d.note:SetText(#linked>1 and "This action-bar position changes in every form." or "Apply & save installs your changes.")
    d.reset.text:SetText(a.presetName and "Clear key" or "Reset key")
    d.rebind:SetEnabled(not a.preserved)
    d.change:SetEnabled(not a.preserved and a.key ~= nil and a.kind ~= "system" and not a.presetName)
    d.talents:SetEnabled(self.CanEditTalentChoices and self:CanEditTalentChoices(a) or false)
    tooltip(d, a.label or a.id, self:MacroDetail(a),a.displaySpellID or a.spellID,state and state~="ready" and status,a.itemID)
    d:EnableMouse(true)
end

function UI:PromptPresetName(title, initial, callback)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    self:CloseMenu(); self:ClearInputFocus()
    if not self.nameDialog then
        local f=box("Frame",self.frame,C.bg,"KeybindOptimizerPresetName")
        f:SetAllPoints(self.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+50); f:EnableMouse(true)
        f.title=label(f,"",20); f.title:SetPoint("TOPLEFT",95,-163)
        local shell,input=edit(f,650,32); shell:SetPoint("TOPLEFT",95,-207); input:SetMaxLetters(48); f.input=input
        f.note=label(f,"",11,C.muted); f.note:SetPoint("TOPLEFT",95,-251); f.note:SetWidth(650)
        local function save()
            local ok,why=f.callback(input:GetText())
            if ok then f:Hide(); UI:Refresh()
            else f.note:SetText(why or "Choose a different name."); color(f.note,C.error) end
        end
        input:SetScript("OnEnterPressed",save)
        input:SetScript("OnEscapePressed",function() f:Hide() end)
        f.save=button(f,"Save",100,save,true); f.save:SetPoint("TOPRIGHT",-115,-293)
        local cancel=button(f,"Cancel",100,function() f:Hide() end); cancel:SetPoint("TOPRIGHT",-225,-293)
        f:SetScript("OnHide",function() input:ClearFocus(); UI:EndModal(f) end)
        self.nameDialog=f
        if self.pages.Presets then self.pages.Presets.nameEdit=input end
    end
    local f=self.nameDialog
    f.callback=callback; f.title:SetText(title); f.input:SetText(initial or "")
    f.note:SetText("Choose a name for this complete binding, control and item setup."); color(f.note,C.muted)
    self:BeginModal(f,"KeybindOptimizerPresetName"); f:Show(); f.input:SetFocus(); f.input:HighlightText()
end
function UI:OpenPresetTransfer(exporting)
    self:ShowPage("Share")
    if exporting then self:ExportToShare(false) end
end
function UI:ExportToShare(selectedOnly)
    local value=self:Call(K,"Export",selectedOnly and K.db.activePreset or nil)
    local page=self.pages.Share
    if type(value)=="string" then
        page.transfer:SetText(value); page.transfer:SetFocus(); page.transfer:HighlightText()
        self.shareResult=(selectedOnly and ("Exported "..K.db.activePreset..".") or "Exported all saved presets.").." Press Ctrl+C to copy."
        self.shareError=false; self:RenderShare()
    end
end
function UI:BuildShare(page)
    label(page,"Import / export",18):SetPoint("TOPLEFT")
    label(page,"Share a preset with another player, or keep your own collection in a file.",11,C.muted):SetPoint("TOPLEFT",0,-29)
    page.exportSelected=button(page,"Export selected",142,function() UI:ExportToShare(true) end); page.exportSelected:SetPoint("TOPLEFT",0,-55)
    page.exportAll=button(page,"Export all",105,function() UI:ExportToShare(false) end); page.exportAll:SetPoint("TOPLEFT",150,-55)
    page.copy=button(page,"Select to copy",130,function()
        page.transfer:SetFocus(); page.transfer:HighlightText(); UI.shareResult="Press Ctrl+C to copy the selected text."; UI.shareError=false; UI:RenderShare()
    end); page.copy:SetPoint("TOPLEFT",263,-55)
    page.clear=button(page,"Clear",80,function() page.transfer:SetText(""); page.transfer:ClearFocus(); UI.shareResult=nil; UI:RenderShare() end); page.clear:SetPoint("TOPRIGHT",0,-55)
    local shell=box("Frame",page,C.field); shell:SetPoint("TOPLEFT",0,-96); shell:SetPoint("BOTTOMRIGHT",0,108)
    local sf=CreateFrame("ScrollFrame",nil,shell,"UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT",10,-10); sf:SetPoint("BOTTOMRIGHT",-29,10)
    local e=CreateFrame("EditBox",nil,sf); e:SetMultiLine(true); e:SetAutoFocus(false); e:SetFontObject(ChatFontNormal or GameFontHighlight)
    e:SetSize(700,100); e:SetMaxLetters(2000000); sf:SetScrollChild(e); page.transfer=e
    self:ConfigureCopyScroll(e,sf)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnTextChanged",function() if page.copy then page.copy:SetEnabled(e:GetText()~=""); page.import:SetEnabled(e:GetText()~="") end end)
    page.message=label(page,"",11,C.muted); page.message:SetPoint("BOTTOMLEFT",0,77); page.message:SetWidth(795); page.message:SetHeight(25)
    page.help=label(page,"To save a file: export, press Ctrl+C, then paste into a text editor and save as .hotswap.\nTo import: open a shared file, copy its text and paste it above. Nothing is applied automatically.",10,C.muted)
    page.help:SetPoint("BOTTOMLEFT",0,21); page.help:SetWidth(600); page.help:SetHeight(42)
    page.import=button(page,"Import presets",150,function()
        local ok,why=UI:Call(K,"Import",e:GetText())
        UI.shareResult=why or (ok and "Presets imported. Select a draft, then choose Apply & save when ready." or "Paste valid exported preset text first.")
        UI.shareError=not ok
        if ok then e:ClearFocus(); UI:Refresh() else UI:RenderShare() end
    end,true); page.import:SetPoint("BOTTOMRIGHT",0,25)
end
function UI:RenderShare()
    local page=self.pages and self.pages.Share
    if not page then return end
    page.message:SetText(self.shareResult or ("Selected: "..tostring(K.db and K.db.activePreset or "none").."  ·  Imported drafts stay inactive until Apply & save."))
    color(page.message,self.shareError and C.error or C.muted)
    local hasText=page.transfer:GetText()~=""
    page.copy:SetEnabled(hasText); page.import:SetEnabled(hasText)
end
function UI:Optimize()
    self.notice=nil
    local ok,why=self:Call(K.Presets,"Optimize")
    if ok=="pending" then
        self.awaitingOptimize=true
    elseif ok==true then
        self.followForm=true
        self.pendingOptimizeBindings=true
        self:Notice(why or "Optimized layout active. Previous bindings and bars are backed up.")
    end
    if K.QueueRefresh then K:QueueRefresh() end
end
function UI:UseSelectedPreset()
    self.notice=nil
    local ok,why=self:Call(K.Presets,"Activate",K.db and K.db.activePreset)
    if K.QueueRefresh then K:QueueRefresh() end
    if ok==true then self:Notice(why or "Preset active. Your previous setup was backed up.") end
end
function UI:BuildPresets(page)
    label(page,"Presets",18):SetPoint("TOPLEFT")
    page.active=label(page,"",11,C.accent); page.active:SetPoint("TOPRIGHT",-2,-5); page.active:SetWidth(540); page.active:SetJustifyH("RIGHT")
    label(page,"Select a preset to edit its draft. Apply & save backs up and installs your changes.",11,C.muted):SetPoint("TOPLEFT",0,-29)
    page.list=scroll(page); page.list:SetPoint("TOPLEFT",0,-57); page.list:SetPoint("BOTTOMLEFT",0,94); page.list:SetWidth(232)
    page.new=button(page,"New",108,function()
        UI:PromptPresetName("New preset","",function(name) return UI:Call(K.Presets,"Create",name,false) end)
    end); page.new:SetPoint("BOTTOMLEFT",0,55)
    page.duplicate=button(page,"Duplicate",112,function()
        UI:PromptPresetName("Duplicate preset",(K.db and K.db.activePreset or "Preset").." copy",function(name) return UI:Call(K.Presets,"Create",name,true) end)
    end); page.duplicate:SetPoint("BOTTOMLEFT",116,55)
    local d=box("Frame",page); d:SetPoint("TOPLEFT",248,-57); d:SetPoint("TOPRIGHT",0,-57); d:SetHeight(235); page.detail=d
    d.title=label(d,"",17); d.title:SetPoint("TOPLEFT",14,-13); truncate(d.title,358)
    d.state=label(d,"",11,C.muted); d.state:SetPoint("TOPLEFT",14,-42); d.state:SetWidth(515)
    d.description=label(d,"Draft edits are saved automatically. Apply & save installs the selected draft in the game.",11,C.muted)
    d.description:SetPoint("TOPLEFT",14,-68); d.description:SetWidth(515)
    label(d,"Hot Swap key",12):SetPoint("TOPLEFT",14,-111)
    d.hotkey=button(d,"Set key",130,function()
        local name=K.db and K.db.activePreset
        UI:BeginCapture("preset",{id="preset."..tostring(name),label=name,presetName=name})
    end); d.hotkey:SetPoint("TOPLEFT",134,-103)
    d.clearKey=button(d,"Clear",68,function() UI:Call(K.Presets,"ClearHotkey",K.db.activePreset); UI:Refresh() end); d.clearKey:SetPoint("TOPLEFT",270,-103)
    d.keyHint=label(d,"Switches the complete setup out of combat. Apply & save enables updated shortcuts.",10,C.muted)
    d.keyHint:SetPoint("TOPLEFT",14,-140); d.keyHint:SetWidth(515)
    d.rename=button(d,"Rename",100,function()
        local name=K.db.activePreset
        UI:PromptPresetName("Rename preset",name,function(value) return UI:Call(K.Presets,"Rename",name,value) end)
    end); d.rename:SetPoint("BOTTOMLEFT",14,17)
    d.delete=button(d,"Delete",85,function()
        local name=K.db.activePreset
        UI:Confirm("Delete "..name.."?","Remove this saved preset. Your active game setup is kept.",function() UI:Call(K.Presets,"Delete",name); UI:Refresh() end)
    end); d.delete:SetPoint("BOTTOMLEFT",122,17)
    d.use=button(d,APPLY_LABEL,128,function() UI:UseSelectedPreset() end,true); d.use:SetPoint("BOTTOMRIGHT",-14,17)
    tooltip(d.use,APPLY_LABEL,APPLY_DETAIL)
    page.rename,page.delete,page.usePreset,page.hotkey=d.rename,d.delete,d.use,d.hotkey
    local bindings=button(page,"Edit bindings",132,function() UI:ShowPage("Bindings") end); bindings:SetPoint("TOPLEFT",248,-305)
    local items=button(page,"Edit items",110,function() UI:ShowPage("Items") end); items:SetPoint("TOPLEFT",388,-305)
    local controls=button(page,"Controls",100,function() UI:ShowPage("Setup") end); controls:SetPoint("TOPLEFT",506,-305)
    local note=label(page,"New starts with the recommended layout. Duplicate copies the selected setup.",10,C.muted)
    note:SetPoint("BOTTOMLEFT",0,24); note:SetWidth(575)
    local export=button(page,"Export all",102,function() UI:OpenPresetTransfer(true) end); export:SetPoint("BOTTOMRIGHT",-116,11)
    local import=button(page,"Import",102,function() UI:OpenPresetTransfer(false) end); import:SetPoint("BOTTOMRIGHT",0,11)
end
function UI:RenderPresets()
    local page=self.pages and self.pages.Presets
    if not page then return end
    local names=K.Presets and K.Presets:List() or {}
    local selected=K.db and K.db.activePreset
    local active=K.db and K.db.enabled and K.db.appliedPreset or nil
    page.active:SetText(active and ("Active: "..active) or "No Hot Swap preset active")
    local list=page.list
    for _,row in ipairs(list.rows) do row:Hide() end
    for i,name in ipairs(names) do
        local row=list.rows[i]
        if not row then
            row=listRow(list.child); row:SetHeight(48)
            row.name=label(row,"",12); row.name:SetPoint("TOPLEFT",8,-7); truncate(row.name,192)
            row.state=label(row,"",10,C.muted); row.state:SetPoint("TOPLEFT",8,-27); truncate(row.state,192)
            row:SetScript("OnClick",function(self) UI:Call(K.Presets,"Select",self.presetName); UI:Refresh() end)
            list.rows[i]=row
        end
        local preset=K.db.presets[name]
        row.presetName=name; row:SetPoint("TOPLEFT",0,-(i-1)*50); row:SetWidth(math.max(200,list.child:GetWidth()))
        row.name:SetText(name); row.state:SetText((name==active and "Active" or "Saved")..(preset.hotkey and ("  ·  "..keyName(preset.hotkey)) or ""))
        color(row.state,name==active and C.accent or C.muted); row.selection:SetShown(name==selected); row:Show()
    end
    list:UpdateHeight(math.max(50,#names*50))
    local preset=K.db and K.db.presets and K.db.presets[selected] or {}
    local d=page.detail; d.title:SetText(selected or "Choose a preset")
    d.state:SetText(selected==active and (K.dirty and "Editing the active preset's draft · changes are not applied yet" or "This preset is active") or "Editing this preset's draft · your active setup is unchanged")
    d.hotkey.text:SetText(preset.hotkey and keyName(preset.hotkey) or "Set key")
    d.clearKey:SetEnabled(preset.hotkey~=nil)
    d.delete:SetEnabled(#names>1 and selected~=active)
    local combat=InCombatLockdown and InCombatLockdown()
    d.use:SetEnabled(not combat and not self.previewFailed and #((self.plan or {}).errors or {})==0)
    d.hotkey:SetEnabled(not combat)
    d.use.text:SetText(APPLY_LABEL)
end

UI.widgets={button=button,label=label,box=box,scroll=scroll,edit=edit,tooltip=tooltip,truncate=truncate,color=color,colors=C,keyName=keyName,listRow=listRow,actionPageNames=actionPageNames}
function UI:BuildItems(page)
    return K.ItemsUI:Build(page,self,self.widgets)
end
function UI:RenderItems()
    local page=self.pages and self.pages.Items
    if page then return K.ItemsUI:Render(page,self,self.widgets) end
end

function UI:BuildSafety(page)
    label(page,"Backups",18):SetPoint("TOPLEFT")
    label(page,"Saved before each use. Stored per character; WoW writes them on reload or logout.",11,C.muted):SetPoint("TOPLEFT",0,-29)
    page.list=scroll(page); page.list:SetPoint("TOPLEFT",0,-57); page.list:SetPoint("BOTTOMRIGHT",0,90)
    page.selected=label(page,"",11,C.muted); page.selected:SetPoint("BOTTOMLEFT",0,61); page.selected:SetWidth(795)
    page.restoreSelected=button(page,"Restore selected",152,function()
        if not UI.selectedBackup then return end
        local ok,why=UI:Call(K.Engine,"RestoreBackup",UI.selectedBackup)
        if K.InvalidatePreview then K:InvalidatePreview() end
        if K.QueueRefresh then K:QueueRefresh() end
        if ok then UI:Notice(why or "Backup restored.") end
    end,true); page.restoreSelected:SetPoint("BOTTOMRIGHT",0,17)
    page.original=button(page,"Restore original setup",195,function()
        UI:Confirm("Restore the original game setup?","Restore the bindings and action bars saved before Hot Swap first changed them. Presets and named backups are kept.",function()
            local ok,why=UI:Call(K,"Restore")
            if K.QueueRefresh then K:QueueRefresh() end
            if ok then UI:Notice(why or "Original setup restored.") end
        end)
    end); page.original:SetPoint("BOTTOMLEFT",0,17)
end
function UI:RenderSafety()
    local page=self.pages and self.pages.Safety
    if not page then return end
    local backups=K.Engine and K.Engine.ListBackups and K.Engine:ListBackups() or {}
    local chosen
    for _,backup in ipairs(backups) do if backup.id==self.selectedBackup then chosen=backup end end
    if not chosen then chosen=backups[1]; self.selectedBackup=chosen and chosen.id or nil end
    local list=page.list
    for _,row in ipairs(list.rows) do row:Hide() end
    for i,backup in ipairs(backups) do
        local row=list.rows[i]
        if not row then
            row=listRow(list.child); row:SetHeight(54)
            row.name=label(row,"",12); row.name:SetPoint("TOPLEFT",10,-8); truncate(row.name,715)
            row.note=label(row,"",10,C.muted); row.note:SetPoint("TOPLEFT",10,-29); truncate(row.note,715)
            row:SetScript("OnClick",function(self) UI.selectedBackup=self.backup.id; UI:RenderSafety() end)
            list.rows[i]=row
        end
        row.backup=backup; row:SetPoint("TOPLEFT",0,-(i-1)*56); row:SetWidth(math.max(560,list.child:GetWidth()))
        row.name:SetText(backup.name or "Saved setup")
        row.note:SetText(backup.preset and ("Preset: "..backup.preset) or "Game bindings before a preset was active")
        row.selection:SetShown(backup.id==self.selectedBackup); row:Show()
    end
    if not list.empty then list.empty=label(list.child,"",12,C.muted); list.empty:SetPoint("TOPLEFT",10,-18); list.empty:SetWidth(740) end
    list.empty:SetText(#backups==0 and "No named backups yet. Apply & save creates one automatically." or "")
    list:UpdateHeight(math.max(65,#backups*56))
    page.selected:SetText(chosen and ("Selected: "..chosen.name) or "Your original setup is also kept separately.")
    local combat=InCombatLockdown and InCombatLockdown()
    page.restoreSelected:SetEnabled(chosen~=nil and not combat)
    page.original:SetEnabled(not combat and K.db and K.db.backup~=nil)
end
function UI:OpenReview()
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    if self.operationError then return self:OpenOperationError() end
    self:CloseMenu(); self:ClearInputFocus()
    local plan=self:Call(K,"Preview")
    if type(plan)=="table" then self.plan=plan end
    if not self.review then
        local f=box("Frame",self.frame,C.bg,"KeybindOptimizerReview")
        f:SetAllPoints(self.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+50); f:EnableMouse(true)
        label(f,"Planned changes",20):SetPoint("TOPLEFT",40,-42)
        f.summary=label(f,"",12,C.text); f.summary:SetPoint("TOPLEFT",40,-78); f.summary:SetWidth(770)
        f.expected=button(f,"Show expected replacements",250,function() UI.reviewExpanded=not UI.reviewExpanded; UI:RenderReview() end)
        f.expected:SetPoint("TOPLEFT",40,-110)
        f.list=scroll(f); f.list:SetPoint("TOPLEFT",40,-153); f.list:SetPoint("BOTTOMRIGHT",-40,85)
        local close=button(f,"Close",100,function() f:Hide() end); close:SetPoint("BOTTOMRIGHT",-40,40)
        label(f,"Apply & save backs up, updates planned keys and bars, and keeps other controls.",11,C.muted):SetPoint("BOTTOMLEFT",40,48)
        f:SetScript("OnHide",function() UI:EndModal(f) end)
        self.review=f
    end
    self:BeginModal(self.review,"KeybindOptimizerReview"); self.review:Show(); self:RenderReview()
end
function UI:RenderReview()
    local f=self.review
    if not f then return end
    local p=self.plan or {}; local coverage=p.coverage or {}; local replacements=p.conflicts or {}; local lines={}
    local errors=#(p.errors or {})
    f.summary:SetText(tostring(coverage.bound or 0).." / "..tostring(coverage.total or 0).." learned spells bound  |  "..tostring(#replacements).." expected replacements"..(errors>0 and ("  |  "..errors.." issues to fix") or "  |  Ready to use"))
    color(f.summary,errors>0 and C.error or C.text)
    f.expected.text:SetText((self.reviewExpanded and "Hide" or "Show").." expected replacements ("..#replacements..")")
    for _,entry in ipairs(p.errors or {}) do lines[#lines+1]={text=message(entry),tone=C.error} end
    for _,entry in ipairs(coverage.missing or {}) do lines[#lines+1]={text="Unbound spell: "..message(entry),tone=C.error} end
    if errors==0 then
        lines[#lines+1]={text="Apply & save updates the keys assigned by this preset after creating a backup. Other bindings and mouse controls stay unchanged.",tone=C.muted}
        lines[#lines+1]={text="Keys no longer used by Hot Swap regain their previous binding only if they still match Hot Swap's last assignment. Later manual changes are kept.",tone=C.muted}
    end
    if self.reviewExpanded then
        for _,entry in ipairs(replacements) do
            lines[#lines+1]={text=keyName(entry.key)..": "..bindingLabel(entry.previous).." -> "..tostring(entry.label or "Preset action"),tone=C.muted}
        end
    end
    for _,entry in ipairs(p.warnings or {}) do
        local value=message(entry)
        if not value:find("Talent, rank, and item changes",1,true) then lines[#lines+1]={text=value,tone=C.warning} end
    end
    for _,entry in ipairs(p.changes or {}) do lines[#lines+1]={text=message(entry),tone=C.muted} end
    local list,y=f.list,0
    for _,row in ipairs(list.rows) do row:Hide() end
    for i,entry in ipairs(lines) do
        local row=list.rows[i]
        if not row then row=label(list.child,"",11); list.rows[i]=row end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",4,-y); row:SetWidth(math.max(540,list.child:GetWidth()-12))
        row:SetText(entry.text); color(row,entry.tone); row:Show(); y=y+math.max(17,row:GetStringHeight())+9
    end
    list:UpdateHeight(y)
end
function UI:Confirm(title, detail, callback)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    self:CloseMenu()
    if not self.confirm then
        local overlay = box("Frame", self.frame, C.bg, "KeybindOptimizerConfirm")
        overlay:SetAllPoints(self.frame)
        overlay:SetFrameStrata("DIALOG")
        overlay:SetFrameLevel(self.frame:GetFrameLevel() + 50)
        overlay:EnableMouse(true)
        overlay:SetScript("OnHide", function()
            local cancel=overlay.cancelCallback; overlay.cancelCallback=nil
            if cancel and not overlay.accepted then cancel() end
            overlay.accepted=nil; UI:EndModal(overlay)
        end)
        overlay.title = label(overlay, "", 22)
        overlay.title:SetPoint("TOPLEFT", 95, -190)
        overlay.detail = label(overlay, "", 13, C.muted)
        overlay.detail:SetPoint("TOPLEFT", 95, -232)
        overlay.detail:SetWidth(660)
        local cancel = button(overlay, "Cancel", 100, function() overlay:Hide() end)
        cancel:SetPoint("BOTTOMRIGHT", -210, 180)
        local yes = button(overlay, "Continue", 100, function() local cb = overlay.callback; overlay.accepted=true; overlay:Hide(); if cb then cb() end end, true)
        yes:SetPoint("BOTTOMRIGHT", -95, 180)
        overlay.acceptButton,overlay.cancelButton=yes,cancel
        self.confirm = overlay
    end
    if self.confirm:IsShown() then self.confirm:Hide() end
    self.confirm.title:SetText(title)
    self.confirm.detail:SetText(detail)
    self.confirm.callback = callback
    self.confirm.accepted=nil; self.confirm.cancelCallback=nil
    self:BeginModal(self.confirm, "KeybindOptimizerConfirm")
    self.confirm:Show()
end
function UI:ShowPage(name)
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    self:CloseMenu()
    self:ClearInputFocus()
    self.activePage = name
    self:SyncLibrary(false)
    self:UpdateBindingTester()
    for id, page in pairs(self.pages) do page:SetShown(id == name); selectTab(self.nav[id], id == name) end
    self:Refresh()
end
function UI:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "KeybindOptimizerWindow", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(860, 620)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(20)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnHide", function()
        UI:CancelLibraryDrag()
        if UI.tester then UI.tester:Hide() end
        if UI.testMouseShield then UI.testMouseShield:Hide() end
        UI:ResetKeyTest()
        UI:EndCapture(); UI:CloseMenu(); UI:ClearInputFocus()
        if UI.confirm then UI.confirm:Hide() end
        if UI.picker then UI.picker:Hide() end
        if UI.review then UI.review:Hide() end
        if UI.nameDialog then UI.nameDialog:Hide() end
        if UI.nativeBarsDialog then UI.nativeBarsDialog:Hide() end
        if UI.operationErrorDialog then UI.operationErrorDialog:Hide() end
        if UI.diagnosticLogDialog then UI.diagnosticLogDialog:Hide() end
        if UI.talentDialog then UI.talentDialog:Hide() end
    end)
    specialFrame("KeybindOptimizerWindow", true)
    local title = f.TitleText or label(f, "", 14, C.accent)
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, -5)
    title:SetText("Hot Swap")
    color(title, C.accent)
    self.subtitle = label(f, "Consistent controls. Deliberate changes.", 11, C.muted)
    self.subtitle:SetPoint("TOPLEFT", 22, -28)
    self.subtitleTip = CreateFrame("Frame", nil, f)
    self.subtitleTip:SetAllPoints(self.subtitle)
    self.subtitleTip:EnableMouse(true)
    local close = f.CloseButton or CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    self.closeButton = close
    local inset = f.Inset or f.InsetBg
    if inset then
        inset:ClearAllPoints()
        inset:SetPoint("TOPLEFT", 16, -79)
        inset:SetPoint("BOTTOMRIGHT", -16, 75)
    end
    self.pages, self.nav = {}, {}
    local ids = {"Setup", "Presets", "Bindings", "Items", "Safety", "Share", "Settings"}
    local classic = WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
    local tabTemplate = classic and "CharacterFrameTabButtonTemplate" or "PanelTabButtonTemplate"
    local tabX = 18
    for i, id in ipairs(ids) do
        local b = CreateFrame("Button", "KeybindOptimizerWindowTab" .. i, f, tabTemplate)
        b:SetID(i)
        b:SetText(id == "Safety" and "Backups" or (id=="Share" and "Import / export" or id))
        b.text = b:GetFontString()
        local tabWidth = id == "Share" and 145 or 110
        b:SetSize(tabWidth, 32)
        -- Modern tabs resize themselves on show and display changes. Keep the
        -- native artwork while preserving our compact, predictable tab layout.
        if not classic then
            local function resizeTab(self)
                if PanelTemplates_TabResize then PanelTemplates_TabResize(self, 0, tabWidth)
                else self:SetWidth(tabWidth) end
            end
            b:SetScript("OnShow", resizeTab)
            b:SetScript("OnEvent", resizeTab)
            resizeTab(b)
        end
        b:SetPoint("TOPLEFT", tabX, -47)
        b:SetScript("OnClick", function() UI:ShowPage(id) end)
        tabX = tabX + b:GetWidth() - 5
        self.nav[id] = b
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", 28, -94)
        page:SetPoint("BOTTOMRIGHT", -28, 85)
        page:Hide()
        self.pages[id] = page
    end
    self.frame = f
    self:AttachTestMouse(f)
    self:BuildSetup(self.pages.Setup)
    self:BuildPresets(self.pages.Presets)
    self:BuildBindings(self.pages.Bindings)
    self:BuildItems(self.pages.Items)
    self:BuildSafety(self.pages.Safety)
    self:BuildShare(self.pages.Share)
    K.SettingsUI:Build(self.pages.Settings,self,self.widgets)
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", 18, 15)
    footer:SetPoint("BOTTOMRIGHT", -18, 15)
    footer:SetHeight(50)
    self.status = label(footer, "", 11, C.muted)
    self.status:SetPoint("TOPLEFT", 12, -10)
    self.status:SetWidth(326)
    self.status:SetHeight(34)
    local preview = button(footer, "Review", 84, function() UI:OpenReview() end)
    self.reviewButton=preview
    preview:SetPoint("RIGHT", -390, 0)
    self.restore = button(footer, "Backups", 92, function() UI:ShowPage("Safety") end)
    self.restore:SetPoint("RIGHT", -292, 0)
    self.apply = button(footer, APPLY_LABEL, 128, function() UI:UseSelectedPreset() end, true)
    self.apply:SetPoint("RIGHT", -154, 0)
    tooltip(self.apply,APPLY_LABEL,APPLY_DETAIL)
    self.optimize=button(footer,"Optimize",134,function() UI:Optimize() end,true)
    self.optimize:SetPoint("RIGHT",-10,0)
    tooltip(self.optimize,"Optimize and apply a new layout","Creates a full-level preset from your controls, preserves your existing presets, backs up current bindings and bars, then fills Blizzard's action bars.")
    self.events = CreateFrame("Frame", nil, f)
    self.events:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.events:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.events:RegisterEvent("MODIFIER_STATE_CHANGED")
    self.events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self.events:RegisterEvent("UPDATE_STEALTH")
    self.events:SetScript("OnEvent", function(_, event)
        if not f:IsShown() then return end
        if K.Engine and K.Engine.busy then UI:UpdateBusyState(); return end
        if event=="PLAYER_REGEN_DISABLED" then
            if UI.capture and UI.capture:IsShown() then UI:EndCapture() end
            UI:UpdateBindingTester()
        elseif event=="PLAYER_REGEN_ENABLED" then UI:UpdateBindingTester() end
        if event == "MODIFIER_STATE_CHANGED" then
            if UI.activePage == "Bindings" and not UI.escapeModal then UI:RenderKeyboard() end
        elseif event=="UPDATE_SHAPESHIFT_FORM" or event=="UPDATE_STEALTH" then UI:ActionPageChanged()
        elseif K.QueueRefresh then K:QueueRefresh()
        else UI:Refresh() end
    end)
    self.activePage = "Setup"
    self.pages.Setup:Show()
    f:Hide()
end
function UI:Refresh()
    if not self.frame then return end
    if not K.db then self:Notice("Waiting for character data to load."); return end
    if self:UpdateBusyState() then return end
    if self.pendingOptimizeBindings then
        self.pendingOptimizeBindings=nil
        self.activePage="Bindings"
        for id,page in pairs(self.pages) do page:SetShown(id=="Bindings"); selectTab(self.nav[id],id=="Bindings") end
    end
    local p = self:Call(K, K.PreviewCached and "PreviewCached" or "Preview")
    self.previewFailed = type(p) ~= "table"
    self.plan = type(p) == "table" and p or K.plan or self.plan or {}
    local s = settings()
    local setup = self.pages.Setup
    local flavors = {auto="Auto-detect client",forever="WoW Forever",era="Classic Era",retail="Retail"}
    if self.activePage == "Setup" then
    for _, row in ipairs(setup.checks) do row.checkbox:SetChecked(s[row.settingKey] and true or false) end
    setup.flavor.text:SetText(flavors[s.flavor or "auto"] or tostring(s.flavor))
    local mage = self.plan.class == "MAGE"
    setup.mageLabel:SetShown(mage)
    setup.school:SetShown(mage)
    setup.schoolNote:SetShown(mage)
    setup.school.text:SetText(s.primarySchool == "fire" and "Fireball on 1" or "Frostbolt on 1")
    local buttons = {}
    for key, enabled in pairs(s.mouseButtons or {}) do if enabled then buttons[#buttons+1] = keyName(key) end end
    table.sort(buttons)
    setup.hardware:SetText(tostring(#buttons) .. " side buttons: " .. (#buttons > 0 and table.concat(buttons, ", ") or "none recorded"))
    end
    local className = UnitClass and UnitClass("player") or self.plan.class or "Character"
    self.subtitle:SetText(className .. "  ·  " .. (flavors[self.plan.flavor or s.flavor or "auto"] or "World of Warcraft").."  ·  Editing: "..tostring(K.db.activePreset or "Preset"))
    truncate(self.subtitle,790)
    tooltip(self.subtitleTip, "Client details", "Build " .. tostring(self.plan.build or "unknown"))
    if self.activePage == "Bindings" then self:RenderBindings()
    elseif self.activePage == "Presets" then self:RenderPresets()
    elseif self.activePage == "Items" then self:RenderItems()
    elseif self.activePage == "Safety" then self:RenderSafety()
    elseif self.activePage == "Share" then self:RenderShare()
    elseif self.activePage == "Settings" then K.SettingsUI:Render(self.pages.Settings,self,self.widgets) end
    self:RenderNativeBars()
    self.reviewButton:SetText(self.operationError and "Details" or "Review")
    for id, b in pairs(self.nav) do selectTab(b, id == self.activePage) end
    local errors = #(self.plan.errors or {})
    local combat = InCombatLockdown and InCombatLockdown()
    self.optimize:SetEnabled(not combat)
    setup.optimize:SetEnabled(not combat)
    color(self.optimize.text,combat and C.muted or C.accent)
    self.apply:SetEnabled(not combat and errors == 0 and not self.previewFailed)
    self.restore:SetEnabled(true)
    color(self.apply.text, (combat or errors > 0 or self.previewFailed) and C.muted or C.accent)
    if combat then self.status:SetText("In combat. Preset switching and restoring are paused."); color(self.status, C.warning)
    elseif self.previewFailed then self.status:SetText("This preset could not be prepared. Open Review to check it."); color(self.status, C.error)
    elseif self.operationError then self.status:SetText(self.operationError.summary); color(self.status,C.error)
    elseif self.notice then self.status:SetText(self.notice); color(self.status, self.noticeError and C.error or C.muted)
    elseif errors > 0 then self.status:SetText(errors .. " binding issue(s) to fix. Open Review before applying this preset."); color(self.status, C.error)
    else
        local cov = self.plan.coverage or {}
        local active=K.db.enabled and K.db.appliedPreset
        self.status:SetText(string.format("%s / %s spells  |  %s expected replacements%s", tostring(cov.bound or 0), tostring(cov.total or 0), tostring(#(self.plan.conflicts or {})), (K.dirty or K.db.activePreset~=active) and "  |  Draft (unapplied)" or "  |  Active"))
        color(self.status,C.muted)
    end
end
function UI:Open()
    self:Create()
    if not self.escapeModal then
        self.restoreEscapeFrame = nil
        specialFrame("KeybindOptimizerWindow", true)
    end
    self.frame:Show()
    if self.frame.Raise then self.frame:Raise() end
    self:Refresh()
    self:FitWindows()
end
function UI:Toggle()
    self:Create()
    if self.frame:IsShown() then self.frame:Hide(); return end
    self:Open()
end
