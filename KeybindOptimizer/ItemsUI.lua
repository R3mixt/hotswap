local _,K=...
K.ItemsUI={}
local V=K.ItemsUI
local modes={default="Item default",target="Target",mouseover="Mouseover",focus="Focus",self="Self",cursor="Ground cursor"}
local function blocked() return K.Engine and K.Engine.busy end
local function canEdit(row) return row and not row.fixedSlot and not blocked() end
local function availability(item)
 if not item then return "No item selected" end
 if item.availability then return item.availability end
 if item.loading then return "Loading item details" end
 if item.missing then return "Not in inventory" end
 if item.requiresEquip then return "Must be equipped before use" end
 return item.location or "In inventory"
end
local function itemName(item) return item and (item.name or ("Item "..tostring(item.id))) or "No item selected" end
function V:ClearFocus()
 if self.page and self.page.idInput then self.page.idInput:ClearFocus() end
end
function V:Build(page,ui,w)
 self.page=page
 local c=w.colors
 w.label(page,"Items",18):SetPoint("TOPLEFT")
 page.context=w.label(page,"",11,c.muted); page.context:SetPoint("TOPLEFT",0,-28); page.context:SetWidth(620)
 page.openBook=w.button(page,"Open spellbook",132,function()
  ui:ShowPage("Bindings")
  ui.libraryTab="items"; ui.libraryCategory=nil; ui.libraryOpen=true
  if ui.library then ui.library.search:SetText("") end
  if ui.SyncLibrary then ui:SyncLibrary() end
 end)
 page.openBook:SetPoint("TOPRIGHT",0,3)
 w.tooltip(page.openBook,"Add an item binding","Open Items in the miniature spellbook, then drag an item onto the keyboard. You can also add an unavailable item by ID here.")
 w.label(page,"1. Choose a binding",12):SetPoint("TOPLEFT",0,-59)
 page.bindingList=w.scroll(page); page.bindingList:SetPoint("TOPLEFT",0,-83); page.bindingList:SetPoint("BOTTOMLEFT",0,94); page.bindingList:SetWidth(218)
 local current=w.box("Frame",page); page.currentPanel=current
 current:SetPoint("TOPLEFT",232,-54); current:SetPoint("TOPRIGHT",0,-54); current:SetHeight(99)
 current.icon=current:CreateTexture(nil,"ARTWORK"); current.icon:SetSize(38,38); current.icon:SetPoint("TOPLEFT",12,-15)
 current.name=w.label(current,"",13,c.accent); current.name:SetPoint("TOPLEFT",61,-12); w.truncate(current.name,335)
 current.state=w.label(current,"",11,c.muted); current.state:SetPoint("TOPLEFT",61,-34); w.truncate(current.state,335)
 current.active=w.label(current,"",10,c.muted); current.active:SetPoint("TOPLEFT",12,-76); current.active:SetWidth(510)
 page.rebind=w.button(current,"Edit key",84,function() if V.selected and V.selected.action then ui:BeginCapture("key",V.selected.action) end end)
 page.rebind:SetPoint("TOPRIGHT",-10,-10)
 page.target=w.button(current,"Item default",116,function(anchor)
  local row=V.selected; if not row then return end
  local options={}; for _,mode in ipairs(row.modes or {"default"}) do options[#options+1]={value=mode,label=modes[mode] or mode} end
  ui:Menu(anchor,options,row.targetMode or "default",function(mode)
   ui:Call(K.Items,"SetBindingTargetMode",row.id,mode); ui:Refresh()
  end)
 end)
 page.target:SetPoint("TOPRIGHT",-10,-41)
 w.label(page,"2. Choose an item",12):SetPoint("TOPLEFT",232,-166)
 page.savedTab=w.button(page,"Saved choices",115,function() V.source="saved"; V.candidateID=nil; ui:RenderItems() end)
 page.savedTab:SetPoint("TOPLEFT",365,-160)
 page.bagTab=w.button(page,"Inventory",98,function() V.source="bags"; V.candidateID=nil; ui:RenderItems() end)
 page.bagTab:SetPoint("LEFT",page.savedTab,"RIGHT",5,0)
 page.scan=w.button(page,"Refresh",84,function() K.Items:Invalidate(); ui:Call(K.Items,"Scan",true); ui:Refresh() end)
 page.scan:SetPoint("TOPRIGHT",0,-160)
 page.list=w.scroll(page); page.list:SetPoint("TOPLEFT",232,-193); page.list:SetPoint("BOTTOMRIGHT",0,148)
 page.empty=w.label(page.list,"",11,c.muted); page.empty:SetPoint("TOPLEFT",8,-14); page.empty:SetWidth(460)
 page.useChoice=w.button(page,"Use this item",116,function()
  if canEdit(V.selected) and V.candidateID then ui:Call(K.Items,"SetBindingItem",V.selected.id,V.candidateID); ui:Refresh() end
 end,true)
 page.useChoice:SetPoint("BOTTOMLEFT",232,113)
 page.removeChoice=w.button(page,"Remove choice",124,function()
  if canEdit(V.selected) and V.candidateID then ui:Call(K.Items,"RemoveAlternative",V.selected.id,V.candidateID); V.candidateID=nil; ui:Refresh() end
 end)
 page.removeChoice:SetPoint("LEFT",page.useChoice,"RIGHT",6,0)
 page.clear=w.button(page,"Clear binding item",146,function()
  if canEdit(V.selected) then ui:Call(K.Items,"ClearBindingItem",V.selected.id); V.candidateID=nil; ui:Refresh() end
 end)
 page.clear:SetPoint("BOTTOMRIGHT",0,113)
 local shell,input=w.edit(page,125,28); page.idInput=input; page.idShell=shell
 shell:SetPoint("BOTTOMLEFT",232,77)
 input:SetScript("OnEnterPressed",function() page.addID:Click() end)
 w.tooltip(shell,"Item ID or mount spell","An item can be saved even when it is not in your bags. For the mount binding, spell:ID selects a learned mount spell.")
 page.addID=w.button(page,"Add ID to choices",145,function()
  if not canEdit(V.selected) then return end
  local raw=(input:GetText() or ""):match("^%s*(.-)%s*$")
  local id=tonumber(raw)
  if V.selected.id=="item.mount" and raw:match("^spell:%d+$") then id=raw end
  if not id or (type(id)=="number" and (id<1 or id%1~=0)) then ui:Notice("Enter a positive item ID. Mount also accepts spell:ID.",true); return end
  local ok=ui:Call(K.Items,"AddAlternative",V.selected.id,id)
  if ok then V.source="saved"; V.candidateID=id; input:SetText(""); input:ClearFocus() end
  ui:Refresh()
 end)
 page.addID:SetPoint("LEFT",shell,"RIGHT",6,0)
 page.stageNote=w.label(page,"Use preset installs these choices.",10,c.muted); page.stageNote:SetPoint("BOTTOMLEFT",0,79); page.stageNote:SetWidth(216)
 local gear=w.box("Frame",page); gear:SetPoint("BOTTOMLEFT"); gear:SetPoint("BOTTOMRIGHT"); gear:SetHeight(62)
 w.label(gear,"Equipment",12):SetPoint("TOPLEFT",12,-10)
 w.label(gear,"Separate from item-use bindings. Equipping is explicit.",10,c.muted):SetPoint("TOPLEFT",12,-32)
 page.gearCapture=w.button(gear,"Capture worn",115,function() ui:Call(K.Items,"CaptureEquipment",K.db.activePreset); ui:Refresh() end)
 page.gearCapture:SetPoint("TOPRIGHT",-137,-17)
 page.gearEquip=w.button(gear,"Equip saved",115,function() ui:Call(K.Items,"EquipPreset",K.db.activePreset); ui:Refresh() end)
 page.gearEquip:SetPoint("TOPRIGHT",-12,-17)
end
function V:Render(page,ui,w)
 local c=w.colors
 page.context:SetText("Editing "..tostring(K.db.activePreset)..". Select a key, then its item. Changes are saved to this preset.")
 local rows=K.Items:GetBindingRows(ui.plan)
 local byID={}; for _,row in ipairs(rows) do byID[row.id]=row end
 self.selectedID=byID[self.selectedID] and self.selectedID or (byID["item.utility"] and "item.utility" or rows[1] and rows[1].id)
 self.selected=byID[self.selectedID]
 if self.lastSelectedID~=self.selectedID then self.candidateID=nil; page.idInput:SetText(""); self.lastSelectedID=self.selectedID end
 for _,row in ipairs(page.bindingList.rows) do row:Hide() end
 for i,entry in ipairs(rows) do
  local row=page.bindingList.rows[i]
  if not row then
   row=w.listRow(page.bindingList.child); row:SetHeight(46)
   row.name=w.label(row,"",11,c.text); row.name:SetPoint("TOPLEFT",7,-7); w.truncate(row.name,184)
   row.note=w.label(row,"",10,c.muted); row.note:SetPoint("TOPLEFT",7,-25); w.truncate(row.note,184)
   row:SetScript("OnClick",function(self) V.selectedID=self.entry.id; V.candidateID=nil; ui:RenderItems() end)
   page.bindingList.rows[i]=row
  end
  row.entry=entry; row:SetPoint("TOPLEFT",0,-(i-1)*48); row:SetWidth(math.max(184,page.bindingList.child:GetWidth())); row:Show()
  row.name:SetText(w.keyName(entry.key) .. "  |  "..tostring(entry.label or "Item"))
  row.note:SetText(itemName(entry.current)); w.color(row.note,entry.current and entry.current.missing and c.warning or c.muted)
  row.selection:SetShown(entry.id==self.selectedID)
  w.tooltip(row,tostring(entry.label),w.keyName(entry.key).."\n"..itemName(entry.current).."\n"..availability(entry.current))
 end
 page.bindingList:UpdateHeight(#rows*48)
 local selected=self.selected; local current=selected and selected.current
 page.currentPanel.icon:SetTexture(current and current.icon or "Interface\\Icons\\INV_Misc_Bag_08")
 page.currentPanel.name:SetText(itemName(current))
 page.currentPanel.state:SetText(availability(current)); w.color(page.currentPanel.state,current and (current.missing or current.requiresEquip) and c.warning or c.muted)
 page.currentPanel.active:SetText(selected and selected.fixedSlot and ("Follows equipped slot "..selected.fixedSlot.." automatically; change the equipped item to change this action.") or "Selected in this preset. Use preset installs it; choices never switch automatically.")
 page.rebind:SetEnabled(selected and selected.action and not blocked() or false)
 local targetInfo=current and K.Items:GetTargetInfo(current)
 local targetLabel=selected and selected.targetMode and selected.targetMode~="default" and modes[selected.targetMode] or targetInfo and targetInfo.label or "Item default"
 page.target.text:SetText(targetLabel); w.truncate(page.target.text,100)
 page.target:SetEnabled(canEdit(selected) and #(selected.modes or {})>1 or false)
 w.tooltip(page.target,targetLabel,"Only targeting modes verified for this item are offered. Food, self-use and ground-reticle items do not offer unit-target options.")
 w.color(page.savedTab.text,self.source~="bags" and c.accent or c.text); w.color(page.bagTab.text,self.source=="bags" and c.accent or c.text)
 local candidates={}
 if selected and not selected.fixedSlot then
  for _,item in ipairs(self.source=="bags" and K.Items:GetAvailableChoices() or selected.alternatives or {}) do
   if item.kind~="mountspell" or selected.id=="item.mount" then candidates[#candidates+1]=item end
  end
 end
 if not self.candidateID and selected then self.candidateID=selected.selected end
 local candidate,foundSaved
 for _,item in ipairs(candidates) do if item.id==self.candidateID then candidate=item end end
 for _,item in ipairs(selected and selected.alternatives or {}) do if item.id==self.candidateID then foundSaved=true end end
 for _,row in ipairs(page.list.rows) do row:Hide() end
 for i,item in ipairs(candidates) do
  local row=page.list.rows[i]
  if not row then
   row=w.listRow(page.list.child); row:SetHeight(37)
   row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",6,0)
   row.name=w.label(row,"",11,c.text); row.name:SetPoint("TOPLEFT",40,-5); w.truncate(row.name,340)
   row.note=w.label(row,"",10,c.muted); row.note:SetPoint("TOPLEFT",40,-20); w.truncate(row.note,380)
   row.state=w.label(row,"",10,c.accent); row.state:SetPoint("RIGHT",-8,0); row.state:SetWidth(70); row.state:SetJustifyH("RIGHT")
   row:SetScript("OnClick",function(self) V.candidateID=self.item.id; ui:RenderItems() end)
   page.list.rows[i]=row
  end
  row.item=item; row:SetPoint("TOPLEFT",0,-(i-1)*39); row:SetWidth(math.max(450,page.list.child:GetWidth())); row:Show()
  row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_Bag_08"); row.name:SetText(itemName(item)); row.note:SetText(availability(item))
  w.color(row.note,item.missing and c.warning or c.muted); row.selection:SetShown(item.id==self.candidateID)
  row.state:SetText(selected and item.id==selected.selected and "Selected" or "")
  w.tooltip(row,itemName(item),availability(item).."\nSelect this row, then choose Use this item.")
 end
 page.list:UpdateHeight(#candidates*39)
 page.empty:SetShown(#candidates==0)
 page.empty:SetText(selected and selected.fixedSlot and "This binding follows an equipment slot; it does not select a bag item." or self.source=="bags" and "No usable items found. Add an item ID to save it in advance." or "No saved choices yet. Browse Inventory or add an item ID below.")
 page.useChoice:SetEnabled(canEdit(selected) and candidate~=nil or false)
 page.removeChoice:SetEnabled(canEdit(selected) and foundSaved or false)
 page.clear:SetEnabled(canEdit(selected) and selected.selected~=nil or false)
 page.addID:SetEnabled(canEdit(selected) and true or false)
 page.idInput:SetEnabled(canEdit(selected) and true or false)
 local combat=InCombatLockdown and InCombatLockdown()
 page.gearCapture:SetEnabled(not combat and not blocked())
 local preset=K.db.presets[K.db.activePreset]
 page.gearEquip:SetEnabled(not combat and not blocked() and next(preset.equipment or {})~=nil)
end
