local _, K = ...
K.CurrentBindings={}
local C=K.CurrentBindings
local unpack=unpack or table.unpack
local function tuple(...) return {n=select("#",...),...} end

-- Display the client's active, possibly unsaved bindings. This module never
-- invokes Planner, loads a binding set, or writes game/preset state.
C.Events={UPDATE_BINDINGS=true,ACTIONBAR_SLOT_CHANGED=true,ACTIONBAR_PAGE_CHANGED=true,
 UPDATE_BONUS_ACTIONBAR=true,UPDATE_OVERRIDE_ACTIONBAR=true,UPDATE_VEHICLE_ACTIONBAR=true,
 UPDATE_SHAPESHIFT_FORM=true,UPDATE_SHAPESHIFT_FORMS=true,UPDATE_POSSESS_BAR=true,
 UPDATE_MACROS=true,PET_BAR_UPDATE=true,PET_BAR_UPDATE_USABLE=true,UNIT_PET=true,
 SPELLS_CHANGED=true,SPELL_UPDATE_ICON=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true,
 PLAYER_EQUIPMENT_CHANGED=true,BAG_UPDATE_DELAYED=true,
 GET_ITEM_INFO_RECEIVED=true,PLAYER_ENTERING_WORLD=true}
local bars={
 {page=6,button="MultiBarBottomLeftButton"},{page=5,button="MultiBarBottomRightButton"},
 {page=3,button="MultiBarRightButton"},{page=4,button="MultiBarLeftButton"},
 {page=13,button="MultiBar5Button"},{page=14,button="MultiBar6Button"},{page=15,button="MultiBar7Button"},
}
local function read(fn,...)
 if type(fn)~="function" then return end
 local values=tuple(pcall(fn,...))
 if values[1] then return unpack(values,2,values.n) end
end
local function positive(value)
 return type(value)=="number" and value>0 and value%1==0 and value<1000000000 and value or nil
end
local function actionAPI(name)
 return C_ActionBar and C_ActionBar[name] or _G[name]
end
local function buttonAction(button)
 if not button then return end
 return positive(button.action) or positive(read(button.GetAttribute,button,"action"))
end
function C:ActionPage()
 local page=positive(read(actionAPI("GetActionBarPage"))) or 1
 -- ActionBarController.lua uses this priority; bonus overrides only page 1.
 for _,kind in ipairs({"Vehicle","Override","TempShapeshift"}) do
  if read(actionAPI("Has"..kind.."ActionBar")) then
   local special=positive(read(actionAPI("Get"..kind.."BarIndex")))
   if special then return special,kind end
  end
 end
 if page==1 then
  local bonus=positive(read(actionAPI("GetBonusBarIndex")))
  if bonus and (not actionAPI("HasBonusActionBar") or read(actionAPI("HasBonusActionBar"))) then return bonus,"Bonus" end
  local offset=positive(read(GetBonusBarOffset))
  if offset then return offset+(NUM_ACTIONBAR_PAGES or 6),"Bonus" end
 end
 return page,"Main"
end
function C:ActionSlot(command,page,pageType)
 -- Resolve supported action-bar addon buttons through their live slot, never
 -- by assuming their visible button number equals Blizzard's action slot.
 local frameName,mouse=command:match("^CLICK ([%w_]+):([%w]+)$")
 if frameName and (frameName:match("^BT4Button%d+$") or frameName:match("^DominosActionButton%d+$")) and (mouse=="LeftButton" or mouse=="HOTKEY" or mouse=="Keybind") then
  local button=_G[frameName]
  if button then
   local kind=read(button.GetAttribute,button,"type")
   if kind==nil or kind=="action" then return buttonAction(button) end
  end
  return nil
 end
 local index=tonumber(command:match("^ACTIONBUTTON(%d+)$"))
 if index and index>=1 and index<=12 then
  if pageType=="Vehicle" or pageType=="Override" or pageType=="TempShapeshift" then
   -- An inactive ActionButton can retain its old slot while the override bar
   -- owns gameplay. Its cached action must not win over the controller page.
   local override=_G["OverrideActionBarButton"..index]
   if override and read(override.IsShown,override) then
    return buttonAction(override) or (page-1)*12+index
   end
   return (page-1)*12+index
  end
  return buttonAction(_G["ActionButton"..index]) or (page-1)*12+index
 end
 local bar,button=command:match("^MULTIACTIONBAR(%d+)BUTTON(%d+)$")
 bar,button=tonumber(bar),tonumber(button)
 if bars[bar] and button and button>=1 and button<=12 then
  return buttonAction(_G[bars[bar].button..button]) or (bars[bar].page-1)*12+button
 end
 local extra=tonumber(command:match("^EXTRAACTIONBUTTON(%d+)$"))
 if extra then return buttonAction(_G["ExtraActionButton"..extra]) end
end
local function commandLabel(command)
 local localized=_G["BINDING_NAME_"..command]
 if type(localized)=="string" and localized~="" then return localized end
 local label=read(GetBindingText,command,"BINDING_NAME_")
 if type(label)=="string" and label~="" and label~=command then return label end
 return K.API:BindingLabel(command)
end
local function empty(action,label)
 action.kind="system"; action.known=false; action.liveEmpty=true
 action.label=label or "Empty action slot"; action.icon=nil
 action.availabilityLabel="Empty"; action.category="Empty action slots"
end
local function spell(action,id,texture,pet)
 local name,icon,resolved=K.API:SpellInfo(id)
 local spellID=positive(tonumber(resolved)) or positive(tonumber(id))
 action.kind="spell"; action.spellID=spellID; action.displaySpellID=spellID
 action.spellName=name; action.name=name; action.label=name or ("Spell "..tostring(id))
 action.icon=texture or icon; action.displayIcon=action.icon
 action.known=spellID and K.API:IsKnown(spellID,pet) or false
 action.petSpell=pet or nil; action.category=pet and "Pet actions" or "Spells"
 -- A native slot can hold a temporary vehicle/override spell that is not in
 -- the player's ordinary spellbook; the view reports the slot, not castability.
 action.availabilityState=nil
end
local function item(action,value,texture)
 local id=tonumber(value) or tonumber(tostring(value):match("item:(%d+)"))
 local name,link,_,_,_,_,_,_,_,icon=read(C_Item and C_Item.GetItemInfo or GetItemInfo,id or value)
 action.kind="item"; action.itemID=id; action.itemLink=link
 action.label=name or (id and "Item "..id or tostring(value)); action.icon=texture or icon
 action.displayIcon=action.icon; action.known=name~=nil; action.category="Items"
 action.itemAvailability=name and nil or "Item details unavailable"
end
local function installedMacroLabels()
 local labels={bySlot={},byName={}}
 local db=K.db
 if not db or not db.enabled or not db.appliedPlan then return labels end
 for _,a in ipairs(db.appliedPlan.actions or {}) do
  if a.macroName and a.body and (db.ownedMacros or {})[a.macroName]==a.body then
   local label=a.itemSlot==13 and "Trinket 1" or a.itemSlot==14 and "Trinket 2" or a.label
   if label then
    local entry={name=a.macroName,body=a.body,label=label,icon=a.displayIcon or a.icon,spellID=a.displaySpellID or a.spellID}
    if a.nativeSlot then labels.bySlot[a.nativeSlot]=entry end
    local previous=labels.byName[a.macroName]
    if previous==nil then labels.byName[a.macroName]=entry
    elseif previous==false or previous.label~=label then labels.byName[a.macroName]=false end
   end
  end
 end
 return labels
end
local function macro(action,value,texture,labels)
 local index=positive(tonumber(value)) or positive(read(GetMacroIndexByName,value))
 local name,icon,body=read(GetMacroInfo,index or value)
 action.kind="macroref"; action.macroName=name or tostring(value); action.macroIndex=index
 action.label=name or "Missing macro"; action.icon=texture or icon; action.displayIcon=action.icon
 action.known=name~=nil; action.category="Macros"; action.liveEmpty=not name or nil
 if name and type(body)=="string" then action.macroFingerprint=K.Macros:Name(body) end
 -- Metadata is read from WoW, not parsed or executed from arbitrary macro text.
 local id=positive(read(GetMacroSpell,index or value))
 if id then action.displaySpellID=id end
 local installed=labels and labels.bySlot[action.liveSlot]
 if not installed or installed.name~=name or installed.body~=body then installed=labels and labels.byName[name] end
 if installed and installed.name==name and installed.body==body and (K.db.ownedMacros or {})[name]==body then
  action.label=installed.label
  if not texture then action.icon=installed.icon or icon; action.displayIcon=action.icon end
  action.displaySpellID=action.displaySpellID or installed.spellID
 end
end
local function petAction(action,index)
 -- Current Era/Forever use the seven-value tuple from Shared/PetActionBar.lua.
 local name,texture,isToken,active,autoAllowed,autoEnabled,id=read(GetPetActionInfo,index)
 action.petSlot=index; action.category="Pet actions"
 if not name then empty(action,"Empty pet action slot"); return end
 if isToken then
  name=type(name)=="string" and (_G[name] or name) or name
  texture=type(texture)=="string" and (_G[texture] or texture) or texture
 end
 if positive(id) then spell(action,id,texture,true) else action.kind="spell"; action.icon=texture end
 action.label=name; action.known=true; action.builtin="petaction"; action.petSpell=true
 action.active=active and true or false; action.autoCastAllowed=autoAllowed; action.autoCastEnabled=autoEnabled
 action.displayIcon=action.icon; action.category="Pet actions"
end
local function stanceAction(action,index)
 local icon,active,castable,id=read(GetShapeshiftFormInfo,index)
 action.stanceSlot=index
 if not icon and not id then empty(action,"Empty form action slot"); return end
 if positive(id) then spell(action,id,icon) else action.kind="spell"; action.icon=icon end
 action.label=action.spellName or ("Form "..index); action.known=true; action.builtin="stance"
 action.active=active and true or false; action.castable=castable; action.category="Forms"
end
function C:Describe(command,key,page,pageType,labels)
 -- Hex-escape separators so different physical key strings never collide.
 local identity=key:gsub("[^%w]",function(ch) return string.format("_%02x",string.byte(ch)) end)
 local a={id="live-"..identity,key=key,keys={key},command=command,liveCommand=command,
  current=true,readOnly=true,form="all",scope="all",kind="system",known=true,
  label=commandLabel(command),category="Game controls"}
 local slot=self:ActionSlot(command,page,pageType)
 if slot then
  a.nativeSlot=slot; a.liveSlot=slot
  local readable,typ,id,subtype=pcall(GetActionInfo,slot)
  if not readable then
   a.known=false; a.label="Action details unavailable"; a.category="Unreadable actions"
   a.readError="Could not read native action slot "..slot.." for "..key.."."
   return a
  end
  a.liveActionType=typ; a.liveActionID=id; a.liveActionSubtype=subtype
  local texture=read(GetActionTexture,slot)
  if not typ then empty(a)
  elseif typ=="spell" then spell(a,id,texture)
  elseif typ=="item" then item(a,id,texture)
  elseif typ=="macro" then
   local resolved,index,why=pcall(K.API.MacroForAction,K.API,slot,id,subtype)
   if resolved and index then macro(a,index,texture,labels)
   else
    a.kind="macroref"; a.known=false; a.label="Macro details unavailable"; a.category="Unreadable actions"
    a.readError=resolved and why or ("Could not read the macro in action slot "..slot..".")
   end
  elseif typ=="petaction" then
   -- GetActionInfo's petaction ID is not a pet-bar position.
   a.kind="spell"; a.builtin="petaction"; a.icon=texture; a.category="Pet actions"
   a.label=read(GetActionText,slot) or "Pet action"
  elseif typ=="flyout" then
   local name,_,_,known=read(GetFlyoutInfo,id)
   a.kind="spell"; a.builtin="flyout"; a.label=name or "Spell flyout"; a.icon=texture; a.known=known~=false
  elseif typ=="equipmentset" then a.kind="item"; a.label=tostring(id or "Equipment set"); a.icon=texture
  else a.kind="spell"; a.builtin=typ; a.label=read(GetActionText,slot) or commandLabel(command); a.icon=texture end
  return a
 end
 local pet=tonumber(command:match("^BONUSACTIONBUTTON(%d+)$"))
 if pet and pet>=1 and pet<=10 then petAction(a,pet); return a end
 local stance=tonumber(command:match("^SHAPESHIFTBUTTON(%d+)$"))
 if stance and stance>=1 and stance<=10 then stanceAction(a,stance); return a end
 local value=command:match("^MACRO (.+)$")
 if value then macro(a,value,nil,labels); return a end
 value=command:match("^SPELL (.+)$")
 if value then spell(a,value); return a end
 value=command:match("^ITEM (.+)$")
 if value then item(a,value); return a end
 return a
end
function C:Build()
 local _,class=read(UnitClass,"player")
 local page,pageType=self:ActionPage()
 local plan={actions={},byID={},byKey={},errors={},warnings={},conflicts={},coverage={},
  class=class,flavor=K.API:GetFlavor({flavor="auto"}),settings={},isCurrent=true,readOnly=true,
  actionPage=page,actionPageType=pageType,actionPageName=pageType.." (page "..page..")"}
 local bindings={}
 local ok,count=pcall(GetNumBindings)
 if not ok or type(count)~="number" or count<0 or count>10000 or count%1~=0 then
  plan.errors[1]="Current bindings are not readable from the client. No recommended layout is substituted."
 else
  for index=1,count do
   local readable,row=pcall(function() return tuple(GetBinding(index)) end)
   if not readable or type(row[1])~="string" or row.n>10000 then
    plan.errors[#plan.errors+1]="Could not read current binding row "..index.."."; break
   end
   for n=3,row.n do if type(row[n])=="string" and row[n]~="" then bindings[row[n]]=row[1] end end
  end
  local hidden,why=K.API:ReadHiddenMouseBindings(bindings)
  if not hidden then plan.errors[#plan.errors+1]=why end
 end
 local keys={}; for key in pairs(bindings) do keys[#keys+1]=key end; table.sort(keys)
 local labels=installedMacroLabels()
 local known=0
 for _,key in ipairs(keys) do
  -- Enumeration supplies candidate keys, not saved-account state. Probe each
  -- active key so unsaved edits or an intentionally removed binding win.
  local readable,command=pcall(GetBindingAction,key)
  if not readable or type(command)~="string" then plan.errors[#plan.errors+1]="Could not read current key "..key.."."
  elseif command~="" and command~="NONE" then
   local normalized=K.API:NormalizeKey(key) or key
   local a=self:Describe(command,normalized,page,pageType,labels)
   plan.actions[#plan.actions+1]=a; plan.byID[a.id]=a; plan.byKey[normalized]=a
   if a.readError then plan.errors[#plan.errors+1]=a.readError end
   if a.known then known=known+1 end
  end
 end
 plan.coverage.total=#plan.actions; plan.coverage.known=known
 self.cache=plan
 return plan
end
function C:Get() return self.cache or self:Build() end
function C:Invalidate() self.cache=nil end

-- Start with live controls and persist only deliberate edits. Catalog entries
-- are choices in the editor, never an implicitly installed recommendation.
function C:Initialize()
 local _,class=UnitClass("player")
 if K.db.currentEditClass and K.db.currentEditClass~=class then
  K.db.currentEditDraft=nil; K.db.currentLayout=nil
 end
 K.db.currentEditClass=class; self.edits=K.db.currentEditDraft; self:Invalidate()
end
function C:Edits()
 self.edits=self.edits or {keys={},slots={},expectedKeys={},expectedSlots={},entries={}}
 self.edits.entries=self.edits.entries or {}
 K.db.currentEditDraft=self.edits
 return self.edits
end
function C:Discard()
 self.edits=nil; K.db.currentEditDraft=nil; self:Invalidate()
end
function C:HasEdits() local e=self.edits; return e and (next(e.keys) or next(e.slots))~=nil or false end
function C:StageKey(key,command,entry)
 local e=self:Edits()
 if e.expectedKeys[key]==nil then e.expectedKeys[key]=GetBindingAction(key) or "" end
 e.keys[key]=command or false; e.entries[key]=entry and K.Copy(entry) or nil
end
function C:Rebind(action,key)
 key=K.API:NormalizeKey(key)
 if not key or key=="ESCAPE" or key:match("BUTTON[12]$") then return false,"Choose a valid key other than Escape or the primary mouse buttons." end
 if not action or not action.key then return false,"Choose a current binding." end
 if action.key=="ESCAPE" or action.key:match("BUTTON[12]$") then return false,"Keep Escape and primary mouse controls on their current keys." end
 if action.key==key then return true end
 local command=action.command
 if action.currentEntry and action.currentEntry.pending and not action.liveSlot then
  self:StageKey(key,false,action.currentEntry); self:StageKey(action.key,false)
  return true,"Reservation moved. Apply changes saves it."
 end
 if not command or command=="" then return false,"This binding changed. Review Current again." end
 local metadata; if not action.liveSlot then metadata=action.currentEntry end
 self:StageKey(key,command,metadata); self:StageKey(action.key,false)
 return true,"Binding moved in your Current layout. Apply changes installs it."
end
function C:ClearKey(action)
 if not action or not action.key or action.key=="ESCAPE" or action.key:match("BUTTON[12]$") then return false,"Keep Escape and primary mouse controls." end
 self:StageKey(action.key,false)
 return true,"Key cleared in your Current layout. Apply changes installs it."
end
function C:StageEntry(entry,key)
 key=K.API:NormalizeKey(key)
 if not key or key=="ESCAPE" or key:match("BUTTON[12]$") then return false,"Choose a valid destination key." end
 local d=entry and entry.descriptor
 local data={label=entry and (entry.label or entry.name),icon=entry and entry.icon,sourceID=entry and (entry.actionID or entry.id)}
 local spellID=entry and entry.spellID or d and d.spellID
 if spellID then
  local exact=K.API:ResolveExact(spellID,K.API:GetCachedSpellbook())
  if not exact or not exact.name then return false,"Spell details are not available yet. Refresh the spellbook and try again." end
  local rank=entry.rank or d and d.rank
  local name=exact.name
  if rank and rank~="" then name=name.."("..rank..")" end
  if name:find("[\r\n;%[%]/]") then return false,"Invalid spell name." end
  data.name=exact.name; data.spellID=spellID; data.rank=rank
  data.icon=data.icon or exact.icon; data.label=data.label or name
  data.command="SPELL "..name

 elseif d and d.kind=="item" then
  local valid,why=K.Library:ValidateDescriptor(d); if not valid then return false,why end
  data.itemID=d.itemID; data.command="ITEM item:"..d.itemID

 elseif d and d.kind=="macroref" then
  local name,_,body=GetMacroInfo(GetMacroIndexByName(d.macroName))
  if name~=d.macroName or K.Macros:Name(body or "")~=d.macroFingerprint then return false,"This local macro changed. Select it again." end
  data.content={kind="macro",name=name,body=body}; data.command="MACRO "..name
 elseif d and d.kind=="system" and K.API:IsBindingCommandSupported(d.command) then data.command=d.command
 elseif d and d.kind=="emote" and K.Library:Emotes()[d.emote] then
  data.body=K.Library:Emotes()[d.emote]; data.command="MACRO "..K.Macros:Name(data.body)
 else return false,"Choose a spell, item, local macro or supported game command." end
 data=self:ResolveEntry(data)
 local e=self:Edits(); self:Build(); local live=self:EditingView().byKey[key]
 if (data.content or data.pending or data.body) and live and live.liveSlot then
  local at=live.liveSlot
  local supported=false; for _,slot in ipairs(K.NativeBars:ManagedSlots()) do if slot==at then supported=true; break end end
  if not supported then return false,"This temporary action slot cannot be edited safely. Choose a normal action-bar key or an empty key." end
  if e.expectedSlots[at]==nil then e.expectedSlots[at]=K.NativeBars:ReadSlot(at) or false end
  if e.expectedKeys[key]==nil then e.expectedKeys[key]=GetBindingAction(key) or "" end
  if data.body then data.content={kind="macro",name=K.Macros:Name(data.body),body=data.body} end
  e.slots[at]=data
 else
  if data.body then data.command="MACRO "..K.Macros:Name(data.body) end
  self:StageKey(key,data.command,data)
 end
 return true,"Action added to your Current layout. Apply changes installs it, including future ability reservations."
end
-- Normalize both new entries and drafts saved by earlier macro-heavy versions.
-- Only primitive spell/item entries are converted; local/custom macro bodies
-- are never interpreted or rewritten.
function C:ResolveEntry(entry)
 local data=K.Copy(entry)
 if data.spellID then
  local book=K.API:GetCachedSpellbook()
  local exact=K.API:ResolveExact(data.spellID,book)
  data.name=data.name or (exact and exact.name)
  local learned=data.rank and exact and exact.known and exact or not data.rank and book.byName[data.name]
  local cast=data.name or data.label
  if data.rank and data.rank~="" then cast=cast.."("..data.rank..")" end
  data.previewCommand="SPELL "..cast
  data.command=learned and data.previewCommand or false
  data.content=learned and {kind="spell",id=learned.id} or false
  data.pending=not learned or nil
  data.body=nil; data.futureBody=nil; data.macroName=nil; data.macroIndex=nil; data.nativeMacro=nil
 elseif data.itemID then
  K.Items:GetCached()
  local item=K.Items:Resolve(data.itemID)
  local available=item and not item.missing
  data.previewCommand="ITEM item:"..data.itemID
  data.command=available and data.previewCommand or false
  data.content=available and {kind="item",id=data.itemID} or false
  data.pending=not available or nil
  data.body=nil; data.futureBody=nil; data.macroName=nil; data.macroIndex=nil; data.nativeMacro=nil
 elseif data.desiredBody then
  data.body=data.desiredBody; data.command="MACRO "..K.Macros:Name(data.body)
  data.content={kind="macro",name=K.Macros:Name(data.body),body=data.body}; data.pending=nil
 end
 return data
end
function C:PrepareEdits(edits)
 for at,entry in pairs(edits.slots) do edits.slots[at]=self:ResolveEntry(entry) end
 for key,entry in pairs(edits.entries or {}) do
  edits.entries[key]=self:ResolveEntry(entry); edits.keys[key]=edits.entries[key].command
 end
 return edits
end
local function sameEntry(a,b)
 return a.command==b.command and a.pending==b.pending and K.NativeBars:SameContent(a.content,b.content)
end
function C:RefreshEdits()
 local saved=K.db.currentLayout; if not saved then return end
 local edits={keys={},entries={},slots={},expectedKeys={},expectedSlots={}}
 local pending=self.edits
 for at,entry in pairs(saved.slots or {}) do
  if not (pending and pending.slots[at]) and not entry.detached then
   if K.NativeBars:SameContent(K.NativeBars:ReadSlot(at),entry.content) then
    local resolved=self:ResolveEntry(entry)
    if not sameEntry(entry,resolved) then edits.slots[at]=resolved; edits.expectedSlots[at]=entry.content or false end
   else entry.detached=true end
  end
 end
 for key,entry in pairs(saved.keys or {}) do
  if not (pending and pending.expectedKeys[key]~=nil) and not entry.detached then
   if GetBindingAction(key)==(entry.command or "") and (not entry.body or K.Macros:FindExact(entry.macroName or tostring(entry.command):match("^MACRO (.+)$"),entry.body)) then
    local resolved=self:ResolveEntry(entry)
    if not sameEntry(entry,resolved) then edits.keys[key]=resolved.command; edits.entries[key]=resolved; edits.expectedKeys[key]=entry.command or "" end
   else entry.detached=true end
  end
 end
 if next(edits.keys) or next(edits.slots) then return edits end
end
function C:QueueRefresh()
 if not K.db or not K.db.currentLayout then return end
 if not self.refreshFrame then self.refreshFrame=CreateFrame("Frame") end
 self.refreshFrame:SetScript("OnUpdate",function(frame)
  if K.Engine.busy or (InCombatLockdown and InCombatLockdown()) then return end
  frame:SetScript("OnUpdate",nil)
  local ok,edits=pcall(C.RefreshEdits,C)
  if ok and edits then K.Engine:ApplyCurrentEdits(edits) end
 end)
end
function C:Annotate(action,entry)
 if not entry then return action end
 action.currentEntry=K.Copy(entry); action.label=entry.label or action.label
 action.icon=entry.icon or action.icon; action.displayIcon=action.icon
 if entry.spellID then
  action.kind="spell"; action.spellID=entry.spellID; action.displaySpellID=entry.spellID; action.spellName=entry.name
  local book=K.API:GetCachedSpellbook()
  local known=entry.rank and K.API:IsKnown(entry.spellID) or not entry.rank and book.byName[entry.name]
  action.known=known and true or false; action.availabilityState=action.known and "ready" or "unlearned"
  action.liveEmpty=nil; action.category="Spells"
 elseif entry.itemID then action.kind="item"; action.itemID=entry.itemID; action.liveEmpty=nil; action.category="Items"; action.known=not entry.pending end
 if entry.pending then
  action.liveEmpty=nil; action.known=false
  action.availabilityState="reserved"
  action.availabilityLabel=entry.desiredBody and "Reserved: waiting for character macro space" or "Reserved: activates when available, outside combat"
 end
 return action
end
function C:EditingView()
 local raw=self:Get(); local plan=K.Copy(raw); local e=self.edits
 local saved=K.db and K.db.currentLayout or {keys={},slots={}}
 plan.readOnly=false; plan.byID={}; plan.byKey={}; plan.actions={}
 local commands={}
 for _,a in ipairs(raw.actions) do commands[a.key]=a.command end
 for key,entry in pairs(saved.keys or {}) do
  if entry.pending and not entry.detached and GetBindingAction(key)=="" then commands[key]=entry.previewCommand or "Reserved action" end
 end
 for key,command in pairs(e and e.keys or {}) do
  local entry=e.entries and e.entries[key]
  commands[key]=command or entry and entry.pending and (entry.previewCommand or "Reserved action") or nil
 end
 for key,command in pairs(commands) do
  local a=self:Describe(command,key,plan.actionPage,plan.actionPageType)
  local staged=e and a.liveSlot and e.slots[a.liveSlot]
  local prior=a.liveSlot and saved.slots[a.liveSlot]
  local entry=staged or e and e.entries and e.entries[key]
  if not entry and prior and not prior.detached and K.NativeBars:SameContent(K.NativeBars:ReadSlot(a.liveSlot),prior.content) then entry=prior end
  if not entry and saved.keys[key] and not saved.keys[key].detached and (saved.keys[key].command==command or saved.keys[key].pending and GetBindingAction(key)=="") then
   local candidate=saved.keys[key]
   if not candidate.body or K.Macros:FindExact(command:match("^MACRO (.+)$"),candidate.body) then entry=candidate end
  end
  if staged then
   local preview=self:Describe(staged.previewCommand or staged.command or "Reserved action",key,plan.actionPage,plan.actionPageType)
   preview.liveSlot=a.liveSlot; preview.nativeSlot=a.liveSlot; preview.command=command; a=preview
  end
  self:Annotate(a,entry); if entry and entry.pending and not a.liveSlot then a.command=false end
  a.readOnly=false; a.current=true
  plan.actions[#plan.actions+1]=a; plan.byID[a.id]=a; plan.byKey[key]=a
 end
 table.sort(plan.actions,function(a,b) return a.key<b.key end)
 return plan
end
