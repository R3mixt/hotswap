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
 local main,extra={},{}
 local druid=plan.class=="DRUID"
 for _,a in ipairs(plan.actions or {}) do
  a.nativeSlot=nil; a.nativeCommand=nil
  if a.kind=="system" then
   if a.key then layout.keys[a.key]={command=a.command} end
  elseif a.key and a.form~="prowl" then
   if a.barSlot and ((druid and formPages[a.form]) or not druid) then
    local index=a.barSlot
    main[index]=main[index] or {actions={},key=a.key}
    if main[index].key~=a.key then return nil,"Main-bar position "..index.." must use the same key in every form. Rebind its linked position or Optimize a new preset." end
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
   a.nativeBlockAlt=hasSelf and not a.selfKey or nil
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
 target.actions={}; target.toggles=GetActionBarToggles and {GetActionBarToggles()} or nil; target.page=getPage()
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
 if not a then return false end
 if a.kind=="macroref" then
  local index=GetMacroIndexByName(a.macroName or "")
  local name,icon,body=GetMacroInfo(index or 0)
  if not name or K.Macros:Name(body or "")~=a.macroFingerprint then error("A referenced macro changed before placement: "..tostring(a.label)) end
  return {kind="macro",id=index,name=name,body=body,icon=icon}
 end
 if a.body then
  if not a.macroIndex then error("Macro not prepared: "..tostring(a.label)) end
  local name,icon,body=GetMacroInfo(a.macroIndex)
  if not name or body~=a.body then error("A generated action macro changed before placement.") end
  return {kind="macro",id=a.macroIndex,name=name,body=body,icon=icon}
 end
 if a.known and a.spellID then return {kind="spell",id=a.spellID} end
 return false
end
local function setToggles(values)
 if not values then return end
 if not SetActionBarToggles then error("This client cannot enable native extra action bars.") end
 SetActionBarToggles(unpack(values,1,#values))
 if MultiActionBar_Update then MultiActionBar_Update() end
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
  local values=GetActionBarToggles and {GetActionBarToggles()} or {false,false,false,false}
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
