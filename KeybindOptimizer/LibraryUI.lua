local _, K = ...

-- The keyboard's companion spellbook and target editor. This module extends
-- the existing UI object so capture callbacks and clients keep one public API.
-- Dragging is only a visual operation: preset data changes on a reviewed drop,
-- and protected action-bar writes remain the Engine's responsibility.
local UI, W = K.UI, K.UI.widgets
local button, label, box, scroll, edit = W.button, W.label, W.box, W.scroll, W.edit
local tooltip, truncate, color, listRow = W.tooltip, W.truncate, W.color, W.listRow
local C, keyName, actionPageNames = W.colors, W.keyName, W.actionPageNames
local function settings() return K:GetSettings() end

-- A talent group is an ordered draft choice for one shared utility position.
-- It never changes another spell's key or chooses an action during combat.
function UI:CanEditTalentChoices(action)
    local override=action and (settings().actionOverrides or {})[action.id]
    if override and (override.spellID or override.replacement) then return false end
    return K.TalentBindings and action and not action.preserved and K.TalentBindings:IsEligible(action) or false
end
function UI:SaveTalentChoices(ids)
    local f=self.talentDialog
    if not f or not f.actionID then return false end
    if K.TalentBindings:GetMode(f.actionID)~="shared" then return false end
    local ok,why=self:Call(K.TalentBindings,"SetChoices",f.actionID,ids)
    if ok then self:Refresh(); self:RenderTalentChoices()
    elseif why then f.note:SetText(why); color(f.note,C.error) end
    return ok
end
function UI:SetTalentKeyMode(mode)
    local f=self.talentDialog; if not f then return false end
    local ok,why=self:Call(K.TalentBindings,"SetMode",f.actionID,mode)
    if ok then self:Refresh(); self:RenderTalentChoices()
    elseif why then f.note:SetText(why); color(f.note,C.error) end
    return ok
end
function UI:RebindOwnTalentKey()
    local f=self.talentDialog
    if not f or K.TalentBindings:GetMode(f.actionID)~="separate" then return end
    for _,action in ipairs((self.plan or {}).actions or {}) do
        if action.id==f.actionID then f:Hide(); self.selectedAction=action; self:BeginActionCapture(action); return end
    end
end
function UI:MoveTalentChoice(index,delta)
    local f=self.talentDialog; if not f then return end
    local ids={}; for _,id in ipairs(K.TalentBindings:GetChoices(f.actionID)) do ids[#ids+1]=id end
    local target=index+delta
    if index<1 or target<1 or index>#ids or target>#ids then return end
    ids[index],ids[target]=ids[target],ids[index]
    self:SaveTalentChoices(ids)
end
function UI:RemoveTalentChoice(index)
    local f=self.talentDialog; if not f then return end
    local ids={}; for _,id in ipairs(K.TalentBindings:GetChoices(f.actionID)) do ids[#ids+1]=id end
    if #ids<=1 then return end
    table.remove(ids,index); self:SaveTalentChoices(ids)
end
function UI:RenderTalentChoices()
    local f=self.talentDialog; if not f then return end
    local shared=K.TalentBindings:GetMode(f.actionID)=="shared"
    f.mode=shared and "shared" or "separate"
    for mode,control in pairs(f.modeButtons) do color(control.text,mode==f.mode and C.accent or C.muted) end
    f.list:SetShown(shared); f.add:SetShown(shared); f.reset:SetShown(shared); f.ownInfo:SetShown(not shared)
    local choices=K.TalentBindings:GetChoices(f.actionID)
    f.choices=choices
    local byID={}
    for _,candidate in ipairs(f.candidates or {}) do byID[candidate.id]=candidate end
    for _,action in ipairs((self.plan or {}).actions or {}) do if not byID[action.id] then byID[action.id]=action end end
    local primary=byID[f.actionID] or {label=f.actionID}
    local current
    for _,action in ipairs((self.plan or {}).actions or {}) do if action.id==f.actionID then current=action; break end end
    f.title:SetText("Talent keys: "..tostring(primary.label or f.actionID).." / "..keyName(current and current.key))
    f.ownInfo.name:SetText(primary.label or f.actionID)
    f.ownInfo.binding:SetText("Own key: "..keyName(current and current.key).."  |  "..(primary.known and "Learned" or "Inactive until learned"))
    f.ownInfo.rebind:SetEnabled(current~=nil and current.preserved~=true)
    local active
    for _,id in ipairs(choices) do if byID[id] and byID[id].known then active=id; break end end
    f.note:SetText(shared and "Use one key for ordered talent choices. The first learned choice is used; if none are learned, it stays inactive. Other keys remain unchanged." or "Keep this ability on its own custom key. It stays inactive until learned. Other talent abilities keep their independent keys."); color(f.note,C.muted)
    for _,row in ipairs(f.rows) do row:Hide() end
    for index,id in ipairs(choices) do
        local row=f.rows[index]
        if not row then
            row=listRow(f.list.child); row:SetHeight(36)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("LEFT",8,0); row.icon:SetSize(25,25)
            row.name=label(row,"",12); row.name:SetPoint("LEFT",43,0); truncate(row.name,340)
            row.state=label(row,"",10,C.muted); row.state:SetPoint("RIGHT",-233,0); row.state:SetWidth(126); row.state:SetJustifyH("RIGHT")
            row.up=button(row,"Up",53,function(self) UI:MoveTalentChoice(self:GetParent().index,-1) end); row.up:SetPoint("RIGHT",-172,0)
            row.down=button(row,"Down",61,function(self) UI:MoveTalentChoice(self:GetParent().index,1) end); row.down:SetPoint("RIGHT",-105,0)
            row.remove=button(row,"Remove",89,function(self) UI:RemoveTalentChoice(self:GetParent().index) end); row.remove:SetPoint("RIGHT",-8,0)
            f.rows[index]=row
        end
        local candidate=byID[id] or {label=id}
        row.index,row.choiceID=index,id
        row:SetPoint("TOPLEFT",0,-(index-1)*40); row:SetWidth(math.max(700,f.list.child:GetWidth()))
        row.icon:SetTexture(candidate.displayIcon or candidate.icon or "Interface\\Icons\\INV_Misc_Book_09")
        if row.icon.SetDesaturated then row.icon:SetDesaturated(not candidate.known) end
        row.name:SetText(index..". "..tostring(candidate.label or candidate.name or id))
        row.state:SetText(active==id and "Used when applied" or candidate.known and "Learned" or "Not learned")
        color(row.state,active==id and C.accent or C.muted)
        row.up:SetEnabled(index>1); row.down:SetEnabled(index<#choices); row.remove:SetEnabled(#choices>1)
        row:Show()
    end
    f.list:UpdateHeight(math.max(45,#choices*40)); f.add:SetEnabled(shared and #choices<8)
end
function UI:OpenTalentChoices(action)
    if not self:CanEditTalentChoices(action) then return end
    if K.Engine and K.Engine.busy then self:UpdateBusyState(); return end
    local candidates=K.TalentBindings:ListCandidates(action) or {}
    if #candidates==0 then self:Notice("Talent-key options are available for class utility bindings."); return end
    self:CloseMenu(); self:ClearInputFocus()
    local f=self.talentDialog
    if not f then
        f=box("Frame",self.frame,C.bg,"KeybindOptimizerTalentChoices")
        f:SetAllPoints(self.frame); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(self.frame:GetFrameLevel()+55); f:EnableMouse(true)
        f.title=label(f,"Talent keys",22); f.title:SetPoint("TOPLEFT",40,-40); f.title:SetWidth(770)
        f.modeButtons={}
        for index,entry in ipairs({{"separate","Own key"},{"shared","Shared key"}}) do
            local mode=entry[1]
            local control=button(f,entry[2],132,function() UI:SetTalentKeyMode(mode) end)
            control:SetPoint("TOPLEFT",40+(index-1)*140,-82); f.modeButtons[mode]=control
        end
        f.note=label(f,"",12,C.muted); f.note:SetPoint("TOPLEFT",40,-124); f.note:SetSize(765,40)
        f.add=button(f,"Add talent choice",180,function(self)
            if K.TalentBindings:GetMode(f.actionID)~="shared" then return end
            local used={}; for _,id in ipairs(K.TalentBindings:GetChoices(f.actionID)) do used[id]=true end
            local options={}
            for _,candidate in ipairs(f.candidates or {}) do if not used[candidate.id] then options[#options+1]={value=candidate.id,label=candidate.label or candidate.id} end end
            if #options==0 then UI:Notice("No more eligible talent choices for this binding."); return end
            UI:Menu(self,options,nil,function(id)
                local ids={}; for _,value in ipairs(K.TalentBindings:GetChoices(f.actionID)) do ids[#ids+1]=value end
                ids[#ids+1]=id; UI:SaveTalentChoices(ids)
            end)
        end); f.add:SetPoint("TOPLEFT",40,-174)
        f.list=scroll(f); f.list:SetPoint("TOPLEFT",40,-215); f.list:SetPoint("BOTTOMRIGHT",-40,105); f.rows={}
        f.ownInfo=box("Frame",f,C.field); f.ownInfo:SetPoint("TOPLEFT",40,-179); f.ownInfo:SetPoint("TOPRIGHT",-40,-179); f.ownInfo:SetHeight(161)
        f.ownInfo.name=label(f.ownInfo,"",17); f.ownInfo.name:SetPoint("TOPLEFT",18,-18); f.ownInfo.name:SetWidth(720)
        f.ownInfo.binding=label(f.ownInfo,"",12,C.muted); f.ownInfo.binding:SetPoint("TOPLEFT",18,-53); f.ownInfo.binding:SetWidth(720)
        f.ownInfo.rebind=button(f.ownInfo,"Change key",135,function() UI:RebindOwnTalentKey() end); f.ownInfo.rebind:SetPoint("TOPLEFT",18,-96)
        local help=label(f,"Key mode and edits are saved to this preset's draft. Apply & save installs them.",11,C.muted)
        help:SetPoint("BOTTOMLEFT",40,73); help:SetWidth(760)
        f.reset=button(f,"Reset to own key",160,function() UI:SetTalentKeyMode("separate") end); f.reset:SetPoint("BOTTOMLEFT",40,32)
        f.close=button(f,"Done",105,function() f:Hide() end,true); f.close:SetPoint("BOTTOMRIGHT",-40,32)
        f:SetScript("OnHide",function() UI:CloseMenu(); UI:EndModal(f) end)
        self.talentDialog=f
    end
    f.actionID=action.id; f.candidates=candidates
    self:BeginModal(f,"KeybindOptimizerTalentChoices"); f:Show(); self:RenderTalentChoices()
end

local targetNames={default="Default",target="Current target",mouseover="Mouseover",focus="Focus",self="Self",cursor="At cursor"}
function UI:TargetDescription(action)
    if not action or action.kind=="system" or action.presetName then return nil end
    local mode=action.targetMode or "default"
    local target=action.itemTargetInfo and action.itemTargetInfo.kind or action.targeting
    local selfCast=target=="help" and not action.noSelf and "; Alt casts on you" or ""
    if mode=="default" then
        if target=="help" then return "M","Mouseover, then friendly target"..selfCast end
        if target=="focus" then return "F","Focus target" end
        if target=="dead" then return "M","Mouseover, then dead friendly target" end
        if target=="self" or target=="form" then return "S","Self" end
        if target=="ground" then
            local cursor=action.kind~="item" and settings().groundAtCursor
            return cursor and "@" or "G",cursor and "At cursor" or "Ground targeting"
        end
        if target=="harm" then return "T","Current target" end
        if action.kind=="item" then return "I","Item default; target type unverified" end
        return nil
    end
    local detail=mode=="mouseover" and "Mouseover, then current target" or targetNames[mode] or mode
    return ({target="T",mouseover="M",focus="F",self="S",cursor="@"})[mode],detail..(mode~="self" and selfCast or "")
end
function UI:RenderCaptureTarget()
    if not self.capture or not self.capture.targetMode then return end
    local action=self.captureAction
    local modes=K.Library and K.Library.TargetModes and action and K.Library:TargetModes(action) or {}
    local shown=self.captureMode=="key" and #modes>1
    self.capture.targetMode:SetShown(shown); self.capture.targetLabel:SetShown(shown)
    if shown then self.capture.targetMode.text:SetText(targetNames[action.targetMode or "default"] or "Default") end
end
function UI:OpenTargetMenu(anchor)
    local action=self.captureAction
    if not action then return end
    local options={}
    for _,mode in ipairs(K.Library:TargetModes(action)) do options[#options+1]={value=mode,label=targetNames[mode] or mode} end
    self:Menu(anchor,options,action.targetMode or "default",function(mode) UI:SetActionTarget(mode) end)
end
function UI:SetActionTarget(mode)
    local action=self.captureAction or self.selectedAction
    if not action then return end
    local ok,why=self:Call(K.Library,"SetTargetMode",action.id,mode)
    if not ok then if why then self.captureHint:SetText(why) end; return end
    self:Refresh()
    for _,candidate in ipairs((self.plan or {}).actions or {}) do
        if candidate.id==action.id then self.captureAction=candidate; self.selectedAction=candidate; self:BindingDetail(candidate); break end
    end
    self:RenderCaptureTarget()
    self.captureHint:SetText("Targeting saved to the draft. Press a new key to rebind, or Escape to finish.")
end
function UI:FitWindows()
    if not self.frame then return end
    local wide=self.library and self.library:IsShown() and self.activePage=="Bindings"
    self:ApplyAppearance(wide)
    self.frame:ClearAllPoints(); self.frame:SetPoint("CENTER",UIParent,"CENTER",wide and -160 or 0,0)
end
function UI:CancelLibraryDrag()
    self.libraryDrag=nil; self.libraryEntry=nil; self.libraryTargetKey=nil
    if self.libraryGhost then self.libraryGhost:Hide() end
    if self.library then self.library.note:SetText("Drag an icon onto a key, or click an ability and then a key.") end
end
function UI:StartLibraryDrag(entry)
    if K.Engine and K.Engine.busy then return end
    self.libraryEntry=entry; self.libraryDrag=entry
    if not self.libraryGhost then
        local ghost=box("Frame",UIParent,C.field)
        ghost:SetSize(36,36); ghost:SetFrameStrata("TOOLTIP"); ghost:EnableMouse(false)
        ghost.icon=ghost:CreateTexture(nil,"ARTWORK"); ghost.icon:SetPoint("TOPLEFT",4,-4); ghost.icon:SetPoint("BOTTOMRIGHT",-4,4)
        ghost:SetScript("OnUpdate",function(owner)
            if not UI.libraryDrag then owner:Hide(); return end
            if GetCursorPosition then
                local x,y=GetCursorPosition(); local scale=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
                owner:ClearAllPoints(); owner:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/scale+12,y/scale+12)
            end
        end)
        self.libraryGhost=ghost
    end
    self.libraryGhost.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_Book_09")
    self.libraryGhost:Show()
    self.library.note:SetText("Drop "..entry.label.." onto a key. Release elsewhere to cancel.")
end
function UI:FinishLibraryDrag()
    if not self.libraryDrag then return end
    local board=self.pages and self.pages.Bindings and self.pages.Bindings.keyboard
    if MouseIsOver and board then
        for _,cap in pairs(board.keys) do
            if cap:IsVisible() and MouseIsOver(cap) then self:DropLibraryEntry(cap.fullKey); return end
        end
    end
    self:CancelLibraryDrag()
end
function UI:DropLibraryEntry(key)
    local entry=self.libraryDrag or self.libraryEntry
    if not entry or not key or not K.Library then return false end
    self:CancelLibraryDrag()
    if K.Engine and K.Engine.busy then return false end
    if self.bindingSource=="current" then
        local destination=K.CurrentBindings:EditingView().byKey[key]
        local function stage()
            local ok,why=self:Call(K.CurrentBindings,"StageEntry",entry,key)
            self.currentBindingPlan=nil; self:Refresh(); self:Notice(why,not ok)
            return ok
        end
        if destination then
            local scope=destination.liveSlot and "This replaces the live action-bar slot, including other keys that use that slot." or "This replaces this key's current command."
            self:Confirm("Replace "..keyName(key).."?",(entry.label or entry.name or "This action").." will replace "..destination.label..". "..scope.." Apply changes installs the edit.",stage)
            return false
        end
        return stage()
    end
    if self:IsProtectedKey(key) then self:Notice("This control is protected in Settings. Turn off its category before replacing it.",true); return false end
    local destinations=self.keyIndex and self.keyIndex[key] or {}
    -- Replacing a native slot changes its action on the inspected page only.
    -- Key reassignment is a separate operation, linked across all form pages.
    if #destinations>0 and K.Library.Place then
        local function replace(destination)
            if destination.selfKey==key and destination.key~=key then self:Notice("Self-cast follows the normal spell. Drop onto its normal key to replace it.",true); return end
            local scope=destination.form and destination.form~="all" and ("This changes the "..(actionPageNames[destination.form] or destination.form).." page only.") or "This shared action is used in every form."
            if (settings().talentAlternatives or {})[destination.id] then scope=scope.." This replaces the shared talent choices on this key." end
            UI:Confirm("Replace "..keyName(key).."?",(entry.label or entry.name).." will replace "..(destination.label or destination.id)..".\n\n"..scope.." Apply & save installs the change.",function()
                local ok,why=UI:Call(K.Library,"Place",entry,destination.id)
                if ok then UI.selectedAction=destination; UI:Refresh(); UI:Notice(why or "Action replaced in the preset. Apply & save installs it.") end
            end)
        end
        if #destinations>1 then
            local options={}; for _,destination in ipairs(destinations) do options[#options+1]={value=destination,label=(destination.label or destination.id).." · "..(actionPageNames[destination.form] or destination.form or "Shared")} end
            local base=key:gsub("ALT%-",""):gsub("CTRL%-",""):gsub("SHIFT%-","")
            self:Menu(self.pages.Bindings.keyboard.keys[base] or self.pages.Bindings.form,options,nil,replace)
        else replace(destinations[1]) end
        return false
    end
    -- Empty keys may need a new custom action. Keep an undo token until key
    -- validation and any collision review succeed, so cancellation leaves no
    -- orphan action or saved item choice in the preset.
    local called,ok,id,why,undo=pcall(K.Library.Stage,K.Library,entry)
    if not called or not ok then self:Notice(called and (why or id) or ok,true); return false end
    self:Refresh()
    local action
    for _,candidate in ipairs((self.plan or {}).actions or {}) do if candidate.id==id then action=candidate; break end end
    local function unstage()
        if undo and K.Library.Unstage then K.Library:Unstage(undo) end
        UI:Refresh()
    end
    if not action then unstage(); self:Notice("This action could not be prepared.",true); return false end
    local assigned=self:AssignBinding(action,key)
    if assigned then return true end
    if self.confirm and self.confirm:IsShown() then
        self.confirm.cancelCallback=unstage
    else unstage() end
    return false
end
function UI:ToggleLibrary()
    self.libraryOpen=not (self.library and self.library:IsShown())
    self:CancelLibraryDrag(); self:SyncLibrary()
end
function UI:SyncLibrary(refresh)
    if not self.pages or not self.pages.Bindings then return end
    local show=self.bindingSource~="recommendation" and self.activePage=="Bindings" and self.bindingView~="list" and self.libraryOpen~=false and not self.escapeModal and not (K.Engine and K.Engine.busy)
    if show and not self.library then self:BuildLibrary() end
    if self.library then
        local changed=self.library:IsShown()~=show
        self.library:SetShown(show)
        if show then if changed or refresh~=false then self:RenderLibrary() end else self:CancelLibraryDrag() end
        if changed then self:FitWindows() end
    end
end
function UI:BuildLibrary()
    local f=CreateFrame("Frame","KeybindOptimizerSpellbook",self.frame,"BasicFrameTemplateWithInset")
    f:SetPoint("TOPLEFT",self.frame,"TOPRIGHT",8,-47); f:SetSize(312,544); f:SetFrameLevel(self.frame:GetFrameLevel()+10)
    f.TitleText:SetText("Spellbook")
    self:AttachTestMouse(f)
    f.CloseButton:SetScript("OnClick",function() UI.libraryOpen=false; UI:CancelLibraryDrag(); f:Hide(); UI:FitWindows() end)
    f.tabs={}
    for i,tab in ipairs({{"spells","Spells"},{"items","Items"},{"game","Game"},{"chat","Chat"},{"emotes","Emotes"},{"macros","Macros"}}) do
        local name=tab[1]
        local b=button(f,tab[2],91,function()
            local target=UI.libraryTargetKey
            UI.libraryTab=name; UI.libraryCategory=nil; UI:CancelLibraryDrag(); UI.libraryTargetKey=target; f.search:SetText(""); UI:RenderLibrary()
        end)
        b:SetHeight(24); b:SetPoint("TOPLEFT",12+((i-1)%3)*97,i<=3 and -34 or -62)
        f.tabs[name]=b
    end
    f.category=button(f,"All categories",151,function(self)
        local opts={{value=false,label="All categories"}}
        for _,name in ipairs(K.Library and K.Library:Categories(UI.libraryTab or "spells",UI.bindingSource=="current") or {}) do opts[#opts+1]={value=name,label=name} end
        UI:Menu(self,opts,UI.libraryCategory,function(value) UI.libraryCategory=value or nil; UI:CancelLibraryDrag(); UI:RenderLibrary() end)
    end); f.category:SetPoint("TOPLEFT",12,-97)
    f.ranks=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); f.ranks:SetSize(24,24); f.ranks:SetPoint("TOPLEFT",167,-98)
    if f.ranks.text then f.ranks.text:Hide() end
    f.rankLabel=label(f.ranks,"Show ranks",10,C.text); f.rankLabel:SetPoint("LEFT",25,0)
    f.ranks:SetScript("OnClick",function(self) UI.libraryRanks=self:GetChecked(); UI:CancelLibraryDrag(); UI:RenderLibrary() end)
    tooltip(f.ranks,"Show spell ranks","List individual ranks so you can bind a lower rank separately.")
    f.addItem=button(f,"Add item ID",126,function()
        UI:PromptPresetName("Add an item by ID","",function(text)
            local id=tonumber(text)
            if not id or id<1 or id%1~=0 or id>2147483647 then return false,"Enter a positive item ID." end
            K.db.currentItems=K.db.currentItems or {}; K.db.currentItems[id]=true
            K.Items:Invalidate(); UI.libraryCategory=nil; UI.libraryOpen=true
            return true
        end)
    end); f.addItem:SetPoint("TOPLEFT",168,-97)
    local shell,search=edit(f,286,28); shell:SetPoint("TOPLEFT",12,-132); f.search=search
    search:SetScript("OnTextChanged",function(_,user) if user then UI:CancelLibraryDrag(); UI:RenderLibrary() end end)
    tooltip(shell,"Search the spellbook","Find an ability, command, emote or macro.")
    f.list=scroll(f); f.list:SetPoint("TOPLEFT",12,-169); f.list:SetPoint("BOTTOMRIGHT",-12,68)
    f.list.slider:HookScript("OnValueChanged",function() if not UI.libraryRendering then UI:RenderLibraryRows() end end)
    f.note=label(f,"Drag an icon onto a key, or click an ability and then a key.",10,C.muted)
    f.note:SetPoint("BOTTOMLEFT",12,14); f.note:SetWidth(285); f.note:SetHeight(42)
    f:SetScript("OnHide",function() search:ClearFocus(); UI:CancelLibraryDrag() end)
    f:Hide(); self.library=f
end
function UI:RenderLibrary()
    local f=self.library
    if not f or not f:IsShown() then return end
    self.libraryRendering=true
    local tab=self.libraryTab or "spells"
    for name,b in pairs(f.tabs) do color(b.text,name==tab and C.accent or C.muted) end
    f.category.text:SetText(self.libraryCategory or "All categories"); truncate(f.category.text,133)
    f.addItem:SetShown(tab=="items" and self.bindingSource=="current")
    f.ranks:SetShown(tab=="spells"); f.ranks:SetChecked(self.libraryRanks and true or false)
    f.entries=K.Library and K.Library:List({tab=tab,current=self.bindingSource=="current",category=self.libraryCategory,showRanks=self.libraryRanks and true or false,query=f.search:GetText()}) or {}
    if self.bindingSource~="current" and K.db.preferences and K.db.preferences.showUnavailableBindings==false then
        local visible={}; for _,entry in ipairs(f.entries) do if not self:IsEditorHidden(entry) then visible[#visible+1]=entry end end
        f.entries=visible
    end
    f.list:UpdateHeight(math.max(50,#f.entries*40))
    self.libraryRendering=nil; self:RenderLibraryRows()
end
function UI:RenderLibraryRows()
    local f=self.library
    if not f or not f:IsShown() then return end
    local list=f.list
    -- Reuse only a viewport's worth of native rows, including when ranks are
    -- shown. Scrolling never scans the spellbook or allocates the whole list.
    local first=math.floor((list.sf:GetVerticalScroll() or 0)/40)+1
    local count=math.ceil(list.sf:GetHeight()/40)+1
    for _,row in ipairs(list.rows) do row:Hide() end
    for n=1,count do
        local index=first+n-1; local entry=(f.entries or {})[index]
        if not entry then break end
        local row=list.rows[n]
        if not row then
            row=listRow(list.child); row:SetHeight(38)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("LEFT",4,0); row.icon:SetSize(28,28)
            row.name=label(row,"",11); row.name:SetPoint("TOPLEFT",39,-5); truncate(row.name,219)
            row.rank=label(row,"",9,C.muted); row.rank:SetPoint("TOPLEFT",39,-22); truncate(row.rank,219)
            row:RegisterForDrag("LeftButton")
            UI:AttachTestMouse(row,true)
            row:SetScript("OnDragStart",function(self) self.dragged=true; UI:StartLibraryDrag(self.entry) end)
            row:SetScript("OnDragStop",function(self)
                UI:FinishLibraryDrag()
                self:SetScript("OnUpdate",function(owner) owner:SetScript("OnUpdate",nil); owner.dragged=nil end)
            end)
            row:SetScript("OnClick",function(self)
                if self.dragged then return end
                UI.libraryEntry=self.entry
                if UI.libraryTargetKey then UI:DropLibraryEntry(UI.libraryTargetKey); return end
                f.note:SetText("Placing: "..self.entry.label..". Click a key, or press Escape to cancel.")
            end)
            list.rows[n]=row
        end
        row.entry=entry; row:SetPoint("TOPLEFT",0,-(index-1)*40); row:SetWidth(math.max(250,list.child:GetWidth()))
        local state,status,tone=self:SpellAvailability(entry); tone=tone or C.warning
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_Book_09")
        if row.icon.SetDesaturated then row.icon:SetDesaturated(entry.known==false) end
        row.name:SetText(entry.label or entry.name or "Action"); color(row.name,entry.known==false and tone or C.text)
        local item=entry.descriptor and entry.descriptor.kind=="item"
        status=item and entry.availability or (state and state~="ready" and status or nil)
        row.rank:SetText((entry.rank and tostring(entry.rank) or entry.category or "")..(entry.talent and " · Talent" or "")..(status and " · "..status or ""))
        tooltip(row,entry.label,entry.description or "Drag onto a key, or click then choose a key.",not item and entry.spellID or nil,state and state~="ready" and status,entry.itemID)
        row:Show()
    end
    if not list.empty then list.empty=label(list.child,"",11,C.muted); list.empty:SetPoint("TOPLEFT",5,-14); list.empty:SetWidth(255) end
    list.empty:SetText(#(f.entries or {})==0 and "No matching actions." or "")
end
