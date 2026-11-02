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
  elseif typ=="macro" then macro(a,id,texture,labels)
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
