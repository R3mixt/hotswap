local _, K = ...
K.NativeBars={}
local N=K.NativeBars
local unpack=unpack or table.unpack
-- Blizzard MultiActionBars.lua: page numbers are not the visible bar labels.
local bars={
 {page=6,command="MULTIACTIONBAR1BUTTON",frame="MultiBarBottomLeft"},
 {page=5,command="MULTIACTIONBAR2BUTTON",frame="MultiBarBottomRight"},
 {page=3,command="MULTIACTIONBAR3BUTTON",frame="MultiBarRight"},
 {page=4,command="MULTIACTIONBAR4BUTTON",frame="MultiBarLeft"},
 {page=13,command="MULTIACTIONBAR5BUTTON",frame="MultiBar5"},
 {page=14,command="MULTIACTIONBAR6BUTTON",frame="MultiBar6"},
 {page=15,command="MULTIACTIONBAR7BUTTON",frame="MultiBar7"},
}
local formPages={caster=1,cat=7,bear=9,moonkin=10}
local function combat() return InCombatLockdown and InCombatLockdown() end
local function slot(page,index) return (page-1)*12+index end
local function sortedKeys(map) local t={}; for key in pairs(map) do t[#t+1]=key end; table.sort(t); return t end
function N:AvailableBars()
 local list={}
 for index,bar in ipairs(bars) do if index<=4 or _G[bar.frame] then bar.toggle=index; list[#list+1]=bar end end
 return list
end
local function toggleFlag(value) return value==true or value==1 or value=="1" end
local function tuple(...) return {...},select("#",...) end
function N:ReadToggles()
 -- Some older APIs return nil for disabled flags. Keep the ordinal positions
 -- explicit: Lua's length operator cannot measure a tuple containing holes.
 local values,count={},4
 if GetActionBarToggles then values,count=tuple(GetActionBarToggles()) end
 for _,bar in ipairs(self:AvailableBars()) do count=math.max(count,bar.toggle) end
 count=math.min(#bars,math.max(4,count))
 for index=1,count do values[index]=toggleFlag(values[index]) end
 return values
end
function N:GetBarOptions(plan,settings)
 local values=self:ReadToggles()
 local available={}; for _,bar in ipairs(self:AvailableBars()) do available[bar.toggle]=true end
 local used=plan and plan.nativeLayout and plan.nativeLayout.usedBars or {}
 local requested=(settings or (plan and plan.settings) or {}).nativeBars or {}
 local names={"bottom left","bottom right","right","left","extra","extra","extra"}
 local options={}
 for index,bar in ipairs(bars) do
  local label=OPTION_SHOW_ACTION_BAR and OPTION_SHOW_ACTION_BAR:format(index+1) or ("Action bar "..(index+1))
  options[index]={toggle=index,label=label.." ("..names[index]..")",available=available[index] or false,
   shown=values[index] or false,required=used[index] and true or false,requested=requested[index]}
 end
 return options
end
function N:ManagedSlots()
 local result={}
 for i=1,120 do result[#result+1]=i end
 for index=5,7 do if _G[bars[index].frame] then
  for i=slot(bars[index].page,1),slot(bars[index].page,12) do result[#result+1]=i end
 end end
 return result
end
local function noAlt(body)
 local lines={}
 for line in body:gmatch("[^\n]+") do
  if line:match("^/cast") or line:match("^/use") or line:match("^/cancelform") then
   if line:find("%[") then line=line:gsub("%[([^%]]*)%]",function(c) return "[nomod:alt"..(c~="" and ","..c or "").."]" end)
   else line=line:gsub("^(/%S+)%s*","%1 [nomod:alt] ") end
  end
  lines[#lines+1]=line
 end
 return table.concat(lines,"\n")
end
function N:PendingItemBody(action)
 -- Inert reservations can share a macro only when their eventual targeting
 -- agrees. Encode that distinction in the tooltip conditions, without any
 -- executable /use line while the item is missing or requires equipment.
 local clauses={}
 if action.nativeBlockAlt then clauses[#clauses+1]="nomod:alt" end
 local unit=({target="target",mouseover="mouseover",focus="focus",self="player",cursor="cursor"})[action.targetMode]
 if unit then clauses[#clauses+1]="@"..unit end
 local condition=#clauses>0 and ("["..table.concat(clauses,",").."] ") or ""
 local item=action.itemSlot or (action.itemID and "item:"..action.itemID) or action.mountSpell or ""
 return "#showtooltip "..condition..tostring(item)
end
function N:MakeMacro(action,settings,force)
 if action.nativeHidden then
  -- Native positions stay reserved but empty. Overflow has no native slot,
  -- so reserve its key with a harmless shared macro instead of exposing an
  -- unrelated previous binding while the intended ability is unavailable.
  action.body=action.nativeOverflow and "#showtooltip" or nil
  action.nativeMacro=action.nativeOverflow and true or nil
  action.nativePending=nil; action.macroName=nil; action.macroIndex=nil
  return true
 end
 if (action.talent or action.talentChoices) and not action.known then
  -- A choice list is resolved from learned spells outside combat. A partial
  -- or unknown choice must not execute a stale cast/cancelform fallback.
  action.nativeMacro=true; action.nativePending=true
  action.body="#showtooltip "..tostring(action.displayName or action.name or action.label or "")
  if #action.body>255 then return false,"Talent tooltip exceeds 255 bytes: "..tostring(action.label) end
  return true
 end
 -- Independent talent keys also need an owned macro from the first install.
 -- This lets learning and respec replace the inert body in place while keeping
 -- the user's native slot and personal binding unchanged.
 if action.talent then action.nativeMacro=true end
 if action.kind=="macroref" then
  if action.nativeBlockAlt then
   return false,"This macro shares a main-bar position with an Alt self-cast spell. Put the macro on a shared utility key to preserve its text and safe self-casting."
  end
  local index=GetMacroIndexByName(action.macroName or "")
  local name,icon,body=GetMacroInfo(index or 0)
  if not name or K.Macros:Name(body or "")~=action.macroFingerprint then
   return false,"The referenced macro is missing or changed: "..tostring(action.macroName or action.label)..". Select it again in the spellbook."
  end
  action.macroIndex=index; action.icon=icon; action.known=true
  action.body=nil; action.nativeMacro=nil
  return true
 end
 local emptyItem=action.kind=="item" and not action.itemID and not action.itemSlot and not action.mountSpell
 if emptyItem then
  if force then action.nativeMacro=true; action.body="#showtooltip" end
  return true
 end
 if action.kind=="item" and not action.known then
  action.nativeMacro=true
  action.body=self:PendingItemBody(action)
  return true
 end
 if not action.known or force or action.nativeBlockAlt or action.petSpell or action.pet then
  action.nativeMacro=true
  action.nativePending=not action.known and not action.kind and not action.builtin or nil
 end
 if action.nativeMacro then
  local body,why=K.Macros:Build(action,settings)
  if why then return false,why end
  local name=action.spellName or action.displayName or action.name
  body=body or (name and ("#showtooltip "..name.."\n/cast "..name))
  if not body then return false,"No native action can be prepared for "..tostring(action.label) end
  if action.nativeBlockAlt then body=noAlt(body) end
  if #body>255 then return false,"Native macro exceeds 255 bytes: "..tostring(action.label) end
  action.body=body
 end
 return true
end
function N:Prepare(plan)
 local layout={version=1,placements={},keys={},usedBars={},mainKeys={},overflow=0}
 plan.capacityDeferredCount=0
 local main,extra={},{}
 local druid=plan.class=="DRUID"
 for _,a in ipairs(plan.actions or {}) do
  a.nativeSlot=nil; a.nativeCommand=nil; a.nativeOverflow=nil
  a.nativeDeferred=plan.deferFutureMacros and not a.known and not a.kind and not a.builtin or nil
  if a.nativeDeferred then plan.capacityDeferredCount=plan.capacityDeferredCount+1 end
  if K.Availability then
   K.Availability:Annotate(a,plan.class,plan.flavor or (plan.settings and plan.settings.flavor))
   a.nativeHidden=K.Availability:IsHidden(a,plan.settings) or a.nativeDeferred or nil
  else a.nativeHidden=a.nativeDeferred end
  if a.kind=="system" then
   if a.key then layout.keys[a.key]={command=a.command} end
  elseif a.key and a.form~="prowl" then
   if a.barSlot and ((druid and formPages[a.form]) or not druid) then
    local index=a.barSlot
    main[index]=main[index] or {actions={},key=a.key}
    if main[index].key~=a.key then return nil,"Main-bar position "..index.." must use the same key in every form. Rebind its linked position or preview recommendations for a new preset." end
    main[index].actions[#main[index].actions+1]=a
   else extra[#extra+1]=a end
  end
 end
 local bySlot={}
 local function place(a,page,index,command)
  local at=slot(page,index)
  if bySlot[at] then return false,"Two actions need native slot "..at end
  local entry={slot=at,actionID=a.id}; bySlot[at]=entry; layout.placements[#layout.placements+1]=entry
  a.nativeSlot=at; a.nativeCommand=command
  return true
 end
 for index,group in pairs(main) do
  local command="ACTIONBUTTON"..index
  layout.mainKeys[index]=group.key; layout.keys[group.key]={command=command}
  local hasSelf=false
  for _,a in ipairs(group.actions) do if a.selfKey then hasSelf=true; layout.keys[a.selfKey]={command=command} end end
  for _,a in ipairs(group.actions) do
   a.nativeBlockAlt=(hasSelf and not a.selfKey) or (a.talentHasHelpful and not (a.targeting=="help" and not a.noSelf)) or nil
   local ok,why=self:MakeMacro(a,plan.settings,a.nativeBlockAlt); if not ok then return nil,why end
   local page=druid and formPages[a.form] or 1
   ok,why=place(a,page,index,command); if not ok then return nil,why end
   -- Native stance/stealth pages retain the same class-wide layout for classes
   -- without a dedicated form profile; the game owns the page transitions.
   if not druid then
    local copies=plan.class=="WARRIOR" and {7,8,9} or (plan.class=="ROGUE" or plan.class=="PRIEST") and {7} or {}
    for _,copyPage in ipairs(copies) do
     layout.placements[#layout.placements+1]={slot=slot(copyPage,index),actionID=a.id}
    end
   end
  end
 end
 table.sort(extra,function(a,b)
  if (a.priority or 40)~=(b.priority or 40) then return (a.priority or 40)<(b.priority or 40) end
  if #a.key~=#b.key then return #a.key<#b.key end
  return a.key<b.key
 end)
 local available=self:AvailableBars()
 for index,a in ipairs(extra) do
  local bank=math.floor((index-1)/12)+1; local button=(index-1)%12+1
  local bar=available[bank]
  a.nativeOverflow=not bar or nil
  a.nativeBlockAlt=(a.talentHasHelpful and not (a.targeting=="help" and not a.noSelf)) or nil
  local ok,why=self:MakeMacro(a,plan.settings,not bar); if not ok then return nil,why end
  local binding
  if bar then
   binding={command=bar.command..button}
   ok,why=place(a,bar.page,button,binding.command); if not ok then return nil,why end
   layout.usedBars[bar.toggle]=true
  else
   binding={macroAction=a.id}; layout.overflow=layout.overflow+1
  end
  layout.keys[a.key]=binding
  if a.selfKey then layout.keys[a.selfKey]=binding end
 end
 table.sort(layout.placements,function(a,b) return a.slot<b.slot end)
 plan.nativeLayout=layout
 return layout
end
local function actionIndex(plan) local map={}; for _,a in ipairs(plan.actions or {}) do map[a.id]=a end; return map end
function N:BindingMap(plan)
 local map,actions={},actionIndex(plan)
 for key,entry in pairs(plan.nativeLayout.keys) do
  if entry.command then map[key]=entry.command
  else
   local a=actions[entry.macroAction]
   if not a or not a.macroName then error("A native macro shortcut is not ready: "..key) end
   if a.kind=="macroref" then
    local index=GetMacroIndexByName(a.macroName)
    local name,_,body=GetMacroInfo(index or 0)
    if not name or K.Macros:Name(body or "")~=a.macroFingerprint then error("A referenced macro changed before binding: "..tostring(a.label)) end
   else
    local index,name=K.Macros:FindExact(a.macroName,a.body)
    if not index or K.db.ownedMacros[name]~=a.body then error("A generated action macro changed before binding: "..tostring(a.label)) end
    a.macroIndex=index
   end
   map[key]="MACRO "..a.macroName
  end
 end
 return map
end
local function getPage() return C_ActionBar and C_ActionBar.GetActionBarPage and C_ActionBar.GetActionBarPage() or (GetActionBarPage and GetActionBarPage()) or 1 end
local function setPage(page)
 local fn=C_ActionBar and C_ActionBar.SetActionBarPage or ChangeActionBarPage
 if fn then fn(page) elseif page~=getPage() then error("This client cannot select the native action-bar page.") end
end
local function readSlot(index)
 local kind,id,subtype=GetActionInfo(index)
 if not kind then return false end
 local data={kind=kind,id=id,subtype=subtype}
 if kind=="macro" then data.name,data.icon,data.body=GetMacroInfo(id); if not data.name then return false end end
 return data
end
local function flyoutLocation(id)
 if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
  local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  local flyout=Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
  for tab=1,C_SpellBook.GetNumSpellBookSkillLines() do
   local line=C_SpellBook.GetSpellBookSkillLineInfo(tab)
   for index=(line.itemIndexOffset or 0)+1,(line.itemIndexOffset or 0)+(line.numSpellBookItems or 0) do
    local item=C_SpellBook.GetSpellBookItemInfo(index,bank)
    if item and item.itemType==flyout and item.actionID==id then return index,bank,true end
   end
  end
 elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
  for tab=1,GetNumSpellTabs() do
   local _,_,offset,count=GetSpellTabInfo(tab)
   for index=(offset or 0)+1,(offset or 0)+(count or 0) do
    local kind,flyout=GetSpellBookItemInfo(index,BOOKTYPE_SPELL or "spell")
    if kind=="FLYOUT" and flyout==id then return index,BOOKTYPE_SPELL or "spell",false end
   end
  end
 end
end
local function canRestore(data)
 if not data then return true end
 if data.kind=="spell" then return (C_Spell and C_Spell.PickupSpell or PickupSpell)~=nil end
 if data.kind=="macro" then return PickupMacro~=nil end
 if data.kind=="item" then return (C_Item and C_Item.PickupItem or PickupItem)~=nil end
 if data.kind=="flyout" then
  local index,_,modern=flyoutLocation(data.id)
  return index and (modern and C_SpellBook.PickupSpellBookItem or PickupSpellBookItem)~=nil
 end
 if data.kind=="equipmentset" then return C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet~=nil end
 if data.kind=="summonmount" then return C_MountJournal and C_MountJournal.Pickup~=nil end
 if data.kind=="companion" then return PickupCompanion~=nil end
 return false
end
function N:SnapshotSteps(target)
 if not GetActionInfo then error("Native action-bar inspection is unavailable.") end
 target.actions={}; target.toggles=GetActionBarToggles and self:ReadToggles() or nil; target.page=getPage()
 local steps={}
 local all=self:ManagedSlots()
 for first=1,#all,12 do
  local start=first
  steps[#steps+1]=function()
   if GetCursorInfo and GetCursorInfo() then error("Put down the item or action on your cursor before using a preset.") end
   for j=start,math.min(start+11,#all) do
    local at=all[j]; local data=readSlot(at)
    if not canRestore(data) then error("Cannot safely back up action slot "..at.." ("..tostring(data.kind).."). Move that action off the bar before using a preset.") end
    target.actions[at]=data
   end
  end
 end
 return steps
end
function N:Snapshot()
 local target={}; for _,step in ipairs(self:SnapshotSteps(target)) do step() end; return target
end
local function sameContent(a,b)
 if not a or not b then return not a and not b end
 if a.kind~=b.kind then return false end
 if a.kind=="macro" then return a.name==b.name and a.body==b.body end
 return a.id==b.id and (a.kind~="companion" or a.subtype==b.subtype)
end
local function macroIndex(data)
 local index=GetMacroIndexByName(data.name or "")
 if index and index>0 then local _,_,body=GetMacroInfo(index); if body==data.body then return index end end
 if data.body then return K.Macros:FindOwned(K.Macros:Name(data.body),data.body) end
end
local function pickup(data)
 if data.kind=="spell" then
  local fn=C_Spell and C_Spell.PickupSpell or PickupSpell; if not fn then error("Native spell pickup is unavailable.") end; fn(data.id)
 elseif data.kind=="macro" then
  local index=macroIndex(data); if not index then error("The saved macro was changed or removed: "..tostring(data.name)) end; PickupMacro(index)
 elseif data.kind=="item" then (C_Item and C_Item.PickupItem or PickupItem)(data.id)
 elseif data.kind=="flyout" then
  local index,bank,modern=flyoutLocation(data.id)
  local fn=modern and C_SpellBook.PickupSpellBookItem or PickupSpellBookItem
  if not index or not fn then error("The saved spell flyout is no longer in the spellbook.") end
  fn(index,bank)
 elseif data.kind=="equipmentset" and C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet then C_EquipmentSet.PickupEquipmentSet(data.id)
 elseif data.kind=="summonmount" and C_MountJournal and C_MountJournal.Pickup then C_MountJournal.Pickup(data.id)
 elseif data.kind=="companion" and PickupCompanion then PickupCompanion(data.subtype,data.id)
 else error("Cannot safely restore native action type: "..tostring(data.kind)) end
end
function N:WriteSlot(index,data)
 if combat() then error("Leave combat before updating action bars.") end
 if GetCursorInfo and GetCursorInfo() then error("Your cursor is holding an item or action. Put it down before continuing.") end
 if data and data.kind=="macro" then
  local resolved=macroIndex(data)
  if not resolved then error("The saved macro was changed or removed: "..tostring(data.name)) end
  local name,icon,body=GetMacroInfo(resolved)
  -- A managed macro may have been safely recreated under a suffixed name
  -- because the old name now belongs to a personal edit. Verify that exact
  -- resolved macro, without accepting changed content.
  data={kind="macro",id=resolved,name=name,icon=icon,body=body}
 end
 local current=readSlot(index)
 if sameContent(current,data) and (data or not GetActionInfo(index)) then return end
 if not data then
  if GetActionInfo(index) then PickupAction(index); ClearCursor() end
 else
  local ok,why=pcall(function()
   pickup(data)
   if GetCursorInfo and not GetCursorInfo() then error("Could not pick up the action for slot "..index) end
   PlaceAction(index)
  end)
  ClearCursor()
  if not ok then error(why) end
 end
 if not sameContent(readSlot(index),data) then error("Action-bar verification failed at slot "..index) end
end
local function contentFor(a)
 if not a or a.nativeHidden then return false end
 if a.kind=="macroref" then
  local index=GetMacroIndexByName(a.macroName or "")
  local name,icon,body=GetMacroInfo(index or 0)
  if not name or K.Macros:Name(body or "")~=a.macroFingerprint then error("A referenced macro changed before placement: "..tostring(a.label)) end
  return {kind="macro",id=index,name=name,body=body,icon=icon}
 end
 if a.body then
  -- Creating another macro can reorder its bank. The saved numeric index is
  -- diagnostic only; resolve and verify the prepared identity at the use point.
  local index,name,icon=K.Macros:FindExact(a.macroName,a.body)
  if not index or K.db.ownedMacros[name]~=a.body then error("A generated action macro changed before placement.") end
  a.macroIndex=index
  return {kind="macro",id=index,name=name,body=a.body,icon=icon}
 end
 if a.known and a.spellID then return {kind="spell",id=a.spellID} end
 return false
end
-- These narrow helpers let bounded maintenance compare the installed slot to
-- its previous owned content before learning/respec changes replace anything.
function N:ContentFor(action) return contentFor(action) end
function N:ReadSlot(index) return readSlot(index) end
function N:SameContent(a,b) return sameContent(a,b) end
local macroButtonPrefixes={"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton","MultiBar5Button","MultiBar6Button","MultiBar7Button"}
local function indexMacroLabels()
 -- Build from the installed plan, never a different editing draft. Native
 -- Update hooks then do constant-time slot/name lookups without planning.
 N.macroLabelsBySlot={}; N.macroLabelsByName={}
 local plan=K.db and K.db.enabled and K.db.appliedPlan
 if not plan then return end
 local actions={}
 for _,a in ipairs(plan.actions or {}) do
  if a.kind~="macroref" and a.macroName and a.body then
   actions[a.id]=a
   N.macroLabelsByName[a.macroName]=N.macroLabelsByName[a.macroName] or a
  end
 end
 for _,entry in ipairs(plan.nativeLayout and plan.nativeLayout.placements or {}) do
  N.macroLabelsBySlot[entry.slot]=actions[entry.actionID]
 end
end
local function macroLabelAction(button)
 -- The main bar's effective action changes with paging/forms. Its fixed ID
 -- and original action attribute do not reliably identify the visible slot.
 local at=button and button.action
 if type(at)~="number" and button and button.GetAttribute then at=button:GetAttribute("action") end
 if type(at)~="number" or not GetActionInfo or not GetMacroInfo then return end
 local kind,index=GetActionInfo(at)
 if kind~="macro" then return nil,"" end
 local name,_,body=GetMacroInfo(index)
 if not K.db or not K.db.enabled or not name or not body or (K.db.ownedMacros or {})[name]~=body then return nil,name end
 local a=N.macroLabelsBySlot and N.macroLabelsBySlot[at]
 if not a or a.macroName~=name or a.body~=body then a=N.macroLabelsByName and N.macroLabelsByName[name] end
 if a and a.macroName==name and a.body==body then return a,name end
 return nil,name
end
local function friendlyMacroLabel(a)
 if a.itemSlot==13 then return "Trinket 1" end
 if a.itemSlot==14 then return "Trinket 2" end
 return a.label or a.displayName or a.spellName or a.name
end
local function setMacroTooltip(button)
 local tooltip=GameTooltip
 if not tooltip or not tooltip.IsOwned or not tooltip:IsOwned(button) then return end
 local a=macroLabelAction(button)
 if not a or (a.itemSlot~=13 and a.itemSlot~=14) then return end
 local item=GetInventoryItemID and GetInventoryItemID("player",a.itemSlot)
 local title=a.itemSlot==13 and "Upper trinket" or "Lower trinket"
 if not item then
  tooltip:SetText(title,1,0.82,0)
  tooltip:AddLine("No trinket equipped. This key uses an on-use trinket equipped in this slot.",1,1,1,true)
 else
  -- Keep Blizzard's item tooltip, including stats and cooldown information.
  -- A missing GetItemSpell result is not conclusive proof of a passive item.
  tooltip:AddLine(title.." (slot "..a.itemSlot.."). This key follows the equipped trinket.",1,0.82,0,true)
  local name=K.API:ItemInfo(item)
  if not name then tooltip:AddLine("Loading item details.",0.7,0.7,0.7,true)
  elseif not K.API:ItemSpell(item) then tooltip:AddLine("No usable item effect reported.",0.7,0.7,0.7,true) end
 end
 tooltip:Show()
end
local function setMacroText(button)
 if combat() then N.pendingMacroText=true; return end
 local name=button and button.Name
 if not name and button and button.GetName then
  local global=button:GetName(); name=global and _G[global.."Name"]
 end
 if not name or type(name.SetAlpha)~="function" then return end
 N.macroLabelText=N.macroLabelText or setmetatable({},{__mode="k"})
 local a,nativeName=macroLabelAction(button)
 local text=a and friendlyMacroLabel(a)
 if text then
  name:SetText(text); N.macroLabelText[name]=text
 elseif N.macroLabelText[name] then
  -- Restore only our own stale text; never replace a new personal/native label.
  if name:GetText()==N.macroLabelText[name] then name:SetText(nativeName or "") end
  N.macroLabelText[name]=nil
 end
 local shown=not K.db or not K.db.preferences or K.db.preferences.showMacroNames~=false
 N.macroNameAlpha=N.macroNameAlpha or setmetatable({},{__mode="k"})
 if not shown then
  if N.macroNameAlpha[name]==nil then N.macroNameAlpha[name]=name.GetAlpha and name:GetAlpha() or 1 end
  name:SetAlpha(0)
 elseif N.macroNameAlpha[name]~=nil then
  name:SetAlpha(N.macroNameAlpha[name]); N.macroNameAlpha[name]=nil
 end
end
function N:ApplyMacroTextPreference()
 -- Blizzard's original button.Name fontstring is cosmetic and separate from
 -- HotKey/Count. Never rename macros, replace button methods, or hide protected
 -- buttons. A secure post-hook reapplies the choice after native page updates.
 if not self.macroTextEvents and CreateFrame then
  self.macroTextEvents=CreateFrame("Frame")
  self.macroTextEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.macroTextEvents:RegisterEvent("ADDON_LOADED")
  self.macroTextEvents:SetScript("OnEvent",function() N:ApplyMacroTextPreference() end)
 end
 if combat() then self.pendingMacroText=true; return false end
 self.pendingMacroText=nil
 indexMacroLabels()
 self.macroTextHooks=self.macroTextHooks or setmetatable({},{__mode="k"})
 self.macroTooltipHooks=self.macroTooltipHooks or setmetatable({},{__mode="k"})
 for _,prefix in ipairs(macroButtonPrefixes) do for index=1,12 do
  local button=_G[prefix..index]
  if button then
   if not self.macroTextHooks[button] and hooksecurefunc then
    -- Mixins are copied onto existing instances, so hook the actual button's
    -- Update method rather than a mixin table that only affects future buttons.
    if type(button.Update)=="function" then hooksecurefunc(button,"Update",setMacroText)
    elseif button.HookScript then button:HookScript("OnShow",setMacroText) end
    self.macroTextHooks[button]=true
   end
   if not self.macroTooltipHooks[button] and hooksecurefunc and type(button.SetTooltip)=="function" then
    hooksecurefunc(button,"SetTooltip",setMacroTooltip); self.macroTooltipHooks[button]=true
   end
   setMacroText(button)
  end
 end end
 if not self.legacyMacroTextHook and type(ActionButton_Update)=="function" and hooksecurefunc then
  hooksecurefunc("ActionButton_Update",setMacroText); self.legacyMacroTextHook=true
 end
 if not self.legacyMacroTooltipHook and type(ActionButton_SetTooltip)=="function" and hooksecurefunc then
  hooksecurefunc("ActionButton_SetTooltip",setMacroTooltip); self.legacyMacroTooltipHook=true
 end
 return true
end
local function refreshBars()
 if combat() then return end
 if MultiActionBar_Update then MultiActionBar_Update() end
 if Settings and Settings.GetSetting and Settings.NotifyUpdate then
  for _,bar in ipairs(N:AvailableBars()) do
   local variable="PROXY_SHOW_ACTIONBAR_"..(bar.toggle+1)
   if Settings.GetSetting(variable) then Settings.NotifyUpdate(variable) end
  end
 end
end
function N:QueueVisibilityRefresh()
 -- GetActionBarToggles is server-mirrored. Re-read for a bounded period,
 -- including after Restore, instead of forcing stale desired frame states.
 -- A new request replaces the existing observer; it never queues old writes.
 if not self.visibilityObserver then self.visibilityObserver=CreateFrame("Frame") end
 local elapsed,tick,last=0,0,nil
 self.visibilityObserver:SetScript("OnUpdate",function(frame,delta)
  if combat() then return end
  elapsed=elapsed+delta; tick=tick+delta
  if tick<0.2 then return end
  tick=0
  local parts={}; for index,value in ipairs(N:ReadToggles()) do parts[index]=value and "1" or "0" end
  local signature=table.concat(parts)
  if signature~=last then
   last=signature; refreshBars()
   if K.QueueRefresh then K:QueueRefresh() end
  end
  if elapsed>=10 then frame:SetScript("OnUpdate",nil) end
 end)
 refreshBars()
end
local function setToggles(values)
 if not values then return end
 if combat() then error("Leave combat before updating action bars.") end
 if not SetActionBarToggles then error("This client cannot enable native extra action bars.") end
 -- Era/Forever's proxy setter has a private ten-second full-mask cache.
 -- SetValue skips equal native values, so it cannot clear stale cached bits.
 -- Capability-check the actual proxy setter and synchronize every bit before
 -- sending our complete mask. Older clients use the direct full-mask API.
 local proxies={}; local complete=Settings and Settings.GetSetting and true or false
 if complete then for index=1,#values do
  local setting=Settings.GetSetting("PROXY_SHOW_ACTIONBAR_"..(index+1))
  if not setting or type(setting.SetValueDerived)~="function" then complete=false; break end
  proxies[index]=setting
 end end
 if complete then for index,value in ipairs(values) do proxies[index]:SetValueDerived(value) end end
 SetActionBarToggles(unpack(values,1,#values))
 N:QueueVisibilityRefresh()
end
function N:ApplySteps(plan,layout)
 layout=layout or plan.nativeLayout
 local map,steps,desired=actionIndex(plan),{},{}
 for _,entry in ipairs(layout.placements) do desired[entry.slot]=entry.actionID end
 -- Clear only the native pages this layout owns. Never touch possession slots.
 local pages={[1]=true}
 for _,entry in ipairs(layout.placements) do pages[math.floor((entry.slot-1)/12)+1]=true end
 for _,page in ipairs(sortedKeys(pages)) do for index=1,12 do
  local at=slot(page,index); local id=desired[at]
  steps[#steps+1]=function() self:WriteSlot(at,id and contentFor(map[id]) or false) end
 end end
 steps[#steps+1]=function()
  local values=self:ReadToggles()
  local requested=plan.settings and plan.settings.nativeBars or {}
  for _,bar in ipairs(self:AvailableBars()) do
   if type(requested[bar.toggle])=="boolean" then values[bar.toggle]=requested[bar.toggle] end
  end
  -- A binding must never point to a bar the preset deliberately hides.
  -- Optional choices affect only unused bars; occupied bars always win.
  for bank in pairs(layout.usedBars) do values[bank]=true end
  setToggles(values); setPage(1)
 end
 return steps
end
function N:RestoreSteps(snapshot)
 if not snapshot or type(snapshot.actions)~="table" then return {} end
 local steps={}
 for _,at in ipairs(sortedKeys(snapshot.actions)) do
  local data=snapshot.actions[at]
  steps[#steps+1]=function() self:WriteSlot(at,data) end
 end
 steps[#steps+1]=function() setToggles(snapshot.toggles); setPage(snapshot.page or 1) end
 return steps
end
function N:Apply(plan,layout) for _,step in ipairs(self:ApplySteps(plan,layout)) do step() end; return true end
function N:Restore(snapshot) for _,step in ipairs(self:RestoreSteps(snapshot)) do step() end; return true end
