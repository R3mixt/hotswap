local _,K=...
local UI,W=K.UI,K.UI.widgets
local C=W.colors
local modifiers={LSHIFT=true,RSHIFT=true,LCTRL=true,RCTRL=true,LALT=true,RALT=true,UNKNOWN=true}
local forms={caster=1,cat=2,bear=3,moonkin=4,all=5}
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function mouseKey(name)
    return ({LeftButton="BUTTON1",RightButton="BUTTON2",MiddleButton="BUTTON3"})[name] or tostring(name):upper()
end
local function combination(key)
    return (IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")
        ..(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")
        ..(IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "")..key
end
local function spell(action) return action and not action.kind and not action.builtin end

-- This editor owns input only while active. AssignBinding remains the single
-- authority for reserved keys, protected controls, linked pages and swaps.
function UI:CloseHoverBindings()
    local f=self.hoverBindings
    if not f or f.closing then return end
    f.closing=true; f.active=false; f.resumeAfterModal=nil; f.hoveredID=nil
    if self.hoverInput then self.hoverInput:Hide() end
    if self.hoverMouseShield then self.hoverMouseShield:Hide() end
    if GameTooltip then GameTooltip:Hide() end
    f:Hide(); self:EndModal(f)
    f.closing=nil
    self:UpdateBindingTester()
end
function UI:BeforeHoverModal(frame)
    local f=self.hoverBindings
    if not f or not f.active or frame==f then return end
    if f.assigning and frame==self.confirm then
        -- Retain the keyboard sink through collision confirmation. Resume on
        -- the next frame, after its callback has staged the swap or cancelled.
        f.resumeAfterModal=frame
    else self:CloseHoverBindings() end
end
function UI:UpdateHoverInput()
    local f=self.hoverBindings
    if not f or not f.active then return end
    if not self.frame:IsShown() or inCombat() or (K.Engine and K.Engine.busy) then self:CloseHoverBindings(); return end
    self.hoverInput:Show(); self.hoverMouseShield:Show()
end
function UI:HoverBindingInput(key)
    local f=self.hoverBindings
    if not f or not f.active or inCombat() or (K.Engine and K.Engine.busy) then return end
    if key=="ESCAPE" then
        self.hoverInput.dismiss=f.resumeAfterModal or f
        return
    end
    if f.resumeAfterModal or modifiers[key] or key=="BUTTON1" or key=="BUTTON2" then return end
    local row=f.hoveredID and f.rows[f.hoveredID]
    if not row or not row:IsVisible() then
        f.feedback:SetText("Hover a spell, then press its new key."); W.color(f.feedback,C.muted); return
    end
    local keyWithModifiers=combination(key)
    if row.action.key==keyWithModifiers then return end
    f.assigning=true
    self:Call(self,"AssignBinding",row.action,keyWithModifiers)
    f.assigning=nil
    f.feedback:SetText(self.notice or "Choose a free key, or review the proposed swap.")
    W.color(f.feedback,self.noticeError and C.error or C.text)
end
function UI:HoverBindingEnter(row)
    local f=self.hoverBindings
    if not f or not f.active or f.resumeAfterModal then return end
    if f.hoveredID and f.rows[f.hoveredID] then f.rows[f.hoveredID].selection:Hide() end
    f.hoveredID=row.action.id; row.selection:Show()
    f.current:SetText((row.action.label or row.action.name or row.action.id).."  |  "..W.keyName(row.action.key)
        ..(row.action.barSlot and "  |  This position changes in every form." or ""))
end
function UI:RenderHoverBindings()
    local f=self.hoverBindings
    if not f or not f.active then return end
    local actions={}
    for _,action in ipairs((self.plan or {}).actions or {}) do if spell(action) then actions[#actions+1]=action end end
    local function group(action)
        local form=action.form or "all"
        local category=f.categories[action.id] or f.categories[action.name] or action.category or "General"
        return form,category,(W.actionPageNames[form] or form).." / "..category
    end
    table.sort(actions,function(a,b)
        local af,ac=group(a); local bf,bc=group(b)
        if af~=bf then return (forms[af] or 9)<(forms[bf] or 9) end
        if ac~=bc then return ac<bc end
        local an,bn=a.label or a.name or a.id,b.label or b.name or b.id
        return an==bn and a.id<b.id or an<bn
    end)
    -- Resolve the anchored scroll width before laying out the first grid.
    f.list:UpdateHeight(math.max(40,f.list.child:GetHeight()))
    for _,heading in ipairs(f.headings) do heading:Hide() end
    local displayed={}
    local y,column,previous,headings=0,0,nil,0
    local available=f.list.child:GetWidth()
    local columns=math.max(1,math.min(6,math.floor((available+8)/190)))
    local width=(available-(columns-1)*8)/columns
    for _,action in ipairs(actions) do
        displayed[action.id]=true
        local _,_,title=group(action)
        if title~=previous then
            if column>0 then y=y+59; column=0 end
            if previous then y=y+9 end
            headings=headings+1
            local heading=f.headings[headings]
            if not heading then heading=W.label(f.list.child,"",12,C.accent); f.headings[headings]=heading end
            heading:ClearAllPoints(); heading:SetPoint("TOPLEFT",2,-y); heading:SetWidth(740); heading:SetText(title); heading:Show()
            previous=title; y=y+23
        end
        local row=f.rows[action.id]
        if not row then
            row=W.listRow(f.list.child); row:EnableMouse(true); row:EnableMouseWheel(true)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("LEFT",7,0); row.icon:SetSize(31,31)
            row.name=W.label(row,"",11,C.text); row.name:SetPoint("TOPLEFT",45,-6)
            row.binding=W.label(row,"",10,C.accent); row.binding:SetPoint("TOPLEFT",45,-24)
            row.state=W.label(row,"",9,C.muted); row.state:SetPoint("TOPLEFT",45,-39)
            row:SetScript("OnMouseDown",function(_,name) UI:HoverBindingInput(mouseKey(name)) end)
            row:SetScript("OnMouseWheel",function(_,delta) UI:HoverBindingInput(delta>0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
            f.rows[action.id]=row
        end
        row.action=action; row:ClearAllPoints(); row:SetPoint("TOPLEFT",column*(width+8),-y); row:SetSize(width,55)
        row.icon:SetTexture(action.displayIcon or action.icon or "Interface\\Icons\\INV_Misc_Book_09")
        local state,status,tone=self:SpellAvailability(action)
        if row.icon.SetDesaturated then row.icon:SetDesaturated(state~=nil and state~="ready") end
        row.name:SetText(action.label or action.displayName or action.name or action.id); W.truncate(row.name,width-53)
        row.binding:SetText(W.keyName(action.key)); W.truncate(row.binding,width-53)
        row.state:SetText(state=="talent" and "T - Talent not learned" or state=="unlearned" and "L - Not learned" or "Learned")
        W.color(row.state,state and state~="ready" and tone or C.muted); W.truncate(row.state,width-53)
        W.tooltip(row,action.label or action.name,"Current key: "..W.keyName(action.key)..". Hover and press a key to stage a new binding.",action.displaySpellID or action.spellID,state and state~="ready" and status)
        row:HookScript("OnEnter",function(owner) UI:HoverBindingEnter(owner) end)
        row:HookScript("OnLeave",function(owner)
            owner.selection:Hide()
            if f.hoveredID==owner.action.id then f.hoveredID=nil; f.current:SetText("Hover an ability to choose its key.") end
        end)
        row.selection:SetShown(f.hoveredID==action.id); row:Show()
        column=column+1
        if column==columns then y=y+59; column=0 end
    end
    if column>0 then y=y+59 end
    for id,row in pairs(f.rows) do if not displayed[id] then row:Hide() end end
    f.list:UpdateHeight(math.max(40,y))
    f.subtitle:SetText(tostring(#actions).." spell bindings, including future abilities. Changes stay in preset: "..tostring(K.db.activePreset))
    f.apply:SetEnabled(#((self.plan or {}).errors or {})==0 and not inCombat())
    if f.hoveredID and f.rows[f.hoveredID] then self:HoverBindingEnter(f.rows[f.hoveredID]) end
end
function UI:OpenHoverBindings()
    if self.bindingSource~="draft" then self:Notice("Choose Preset draft for the all-spells hover grid. Use the spellbook to edit Current bindings."); return end
    if inCombat() then self:Notice("Hover binding is unavailable during combat.",true); return end
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    self:CloseMenu(); self:ClearInputFocus(); self:EndCapture(); self:CancelLibraryDrag()
    local f=self.hoverBindings
    if not f then
        f=W.box("Frame",self.frame,C.bg,"KeybindOptimizerHoverBindings")
        f:SetAllPoints(self.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+55); f:EnableMouse(true); f:EnableMouseWheel(true)
        if f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(true) end
        local backing=f:CreateTexture(nil,"BACKGROUND",nil,-8); backing:SetAllPoints(); backing:SetColorTexture(C.bg[1],C.bg[2],C.bg[3],1)
        W.label(f,"Hover bind",22):SetPoint("TOPLEFT",32,-31)
        f.subtitle=W.label(f,"",11,C.muted); f.subtitle:SetPoint("TOPLEFT",32,-65); W.truncate(f.subtitle,790)
        local instructions=W.label(f,"Hover an ability, then press a key. Shift / Ctrl work; Alt stays reserved. No casting.\nWheel over an ability binds it. Scroll over blank space or use the scrollbar to browse.",11,C.text)
        instructions:SetPoint("TOPLEFT",32,-89); instructions:SetSize(790,32)
        f.list=W.scroll(f); f.list:SetPoint("TOPLEFT",32,-136); f.list:SetPoint("BOTTOMRIGHT",-32,131)
        f:SetScript("OnMouseDown",function() f.hoveredID=nil end)
        f:SetScript("OnMouseWheel",function(_,delta)
            f.hoveredID=nil
            local low,high=f.list.slider:GetMinMaxValues()
            f.list.slider:SetValue(math.max(low,math.min(high,f.list.slider:GetValue()-delta*59)))
        end)
        f.current=W.label(f,"Hover an ability to choose its key.",11,C.accent); f.current:SetPoint("BOTTOMLEFT",32,108); W.truncate(f.current,790)
        f.feedback=W.label(f,"",11,C.muted); f.feedback:SetPoint("BOTTOMLEFT",32,72); f.feedback:SetSize(790,30)
        f.done=W.button(f,"Done - keep draft",156,function() UI:CloseHoverBindings() end); f.done:SetPoint("BOTTOMRIGHT",-182,31)
        f.apply=W.button(f,"Apply & save",138,function() UI:CloseHoverBindings(); UI:UseSelectedPreset() end,true); f.apply:SetPoint("BOTTOMRIGHT",-32,31)
        W.label(f,"Escape leaves hover mode. Draft edits are kept.",10,C.muted):SetPoint("BOTTOMLEFT",32,39)
        f.rows,f.headings={},{}
        f:SetScript("OnHide",function()
            if f.resumeAfterModal then UI:EndModal(f) else UI:CloseHoverBindings() end
        end)
        self.hoverBindings=f
        local input=CreateFrame("Frame",nil,self.frame)
        input:SetAllPoints(self.frame); input:EnableMouse(false)
        input:SetFrameStrata("DIALOG"); input:SetFrameLevel(f:GetFrameLevel()+10); input:EnableKeyboard(true)
        if input.SetPropagateKeyboardInput then input:SetPropagateKeyboardInput(false) end
        input.held={}
        input:SetScript("OnKeyDown",function(owner,key)
            if not owner.held[key] then owner.held[key]=true; UI:HoverBindingInput(key) end
        end)
        input:SetScript("OnKeyUp",function(owner,key) owner.held[key]=nil end)
        input:SetScript("OnUpdate",function(owner)
            if owner.dismiss then
                local target=owner.dismiss; owner.dismiss=nil
                if target==f then UI:CloseHoverBindings(); return else target:Hide() end
            end
            UI:UpdateHoverInput()
            if not f.active then return end
            for key in pairs(owner.held) do if IsKeyDown and IsKeyDown(key)==false then owner.held[key]=nil end end
            if f.resumeAfterModal and not f.resumeAfterModal:IsShown() and not UI.escapeModal then
                f.resumeAfterModal=nil; UI:BeginModal(f,"KeybindOptimizerHoverBindings"); f:Show(); UI:RenderHoverBindings()
                f.feedback:SetText(UI.notice or "Hover the next spell to continue."); W.color(f.feedback,UI.noticeError and C.error or C.text)
            end
        end)
        self.hoverInput=input
        local shield=CreateFrame("Frame",nil,UIParent)
        shield:SetAllPoints(UIParent); shield:SetFrameStrata("HIGH"); shield:SetFrameLevel(math.max(0,self.frame:GetFrameLevel()-1))
        shield:EnableMouse(true); shield:EnableMouseWheel(true)
        -- Outside clicks/wheel are consumed, never bound to a stale hover target.
        shield:SetScript("OnMouseDown",function() f.hoveredID=nil end)
        shield:SetScript("OnMouseWheel",function() f.hoveredID=nil end)
        self.hoverMouseShield=shield
    end
    f.categories={}
    for _,entry in ipairs(K.Library:List({tab="spells"})) do
        f.categories[entry.actionID or entry.id]=entry.category; if entry.name then f.categories[entry.name]=entry.category end
    end
    f.active=true; f.resumeAfterModal=nil; f.hoveredID=nil
    self.hoverInput.held={}; self.hoverInput.dismiss=nil
    f.feedback:SetText("Hover binding edits only the draft. Apply & save installs it after creating a backup."); W.color(f.feedback,C.muted)
    self:BeginModal(f,"KeybindOptimizerHoverBindings"); f:Show(); self:RenderHoverBindings(); self:UpdateBindingTester()
end
