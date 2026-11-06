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
 return K.ActionBars:Slot(command,page,pageType)
end
function C:ReadRoute(key)
 local command=read(GetBindingAction,key)
 if type(command)~="string" then return {key=key,error="This binding cannot be read. Try again outside combat."} end
 local page,kind=self:ActionPage()
 return K.ActionBars:Route(command,key,page,kind,true)
end
local function routeStance(route)
 if not route then return end
 if route.stanceSlot~=nil then return route.stanceSlot end
 -- Older drafts recorded native stance commands before routes had a typed
 -- stance index. Their saved command proves the index without consulting a
 -- changed live button or guessing an addon CLICK mapping.
 if route.slot==nil and type(route.effectiveCommand)=="string" then
  local index=tonumber(route.effectiveCommand:match("^SHAPESHIFTBUTTON(%d+)$"))
  if index and index>=1 and index<=10 then return index end
 end
end
function C:ValidateRoutes(edits)
 for key,expected in pairs(edits.expectedRoutes or {}) do
  local actual=self:ReadRoute(key)
  if actual.error or actual.command~=expected.command or actual.effectiveCommand~=expected.effectiveCommand or actual.slot~=expected.slot or actual.stanceSlot~=routeStance(expected) then
   error("Current action-bar routing changed on "..key..". Discard pending edits and review the active bar again.")
  end
 end
end
function C:ReviewLegacyRoutes(edits)
 edits.expectedRoutes=edits.expectedRoutes or {}
 local function outdated()
  error("These pending edits predate action-bar routing checks. Discard pending edits and review the active bar again.")
 end
 for key in pairs(edits.expectedKeys) do
  if not edits.expectedRoutes[key] then
   local route=self:ReadRoute(key)
   -- Old slot edits are usable only when a key still proves that exact slot.
   -- An old rebind did not retain its addon button, so it needs fresh review.
   if route.error or route.effectiveCommand~=route.command and (edits.keys[key]~=nil or not edits.slots[route.slot]) then outdated() end
   edits.expectedRoutes[key]=route
  end
 end
 for at in pairs(edits.slots) do
  local found=false
  for _,route in pairs(edits.expectedRoutes) do if route.slot==at then found=true; break end end
  if not found then outdated() end
 end
end
function C:VerifyEditedRoutes(edits)
 for key,command in pairs(edits.keys) do
  local route=self:ReadRoute(key)
  local source=edits.keyRoutes and edits.keyRoutes[key]
  local stance=routeStance(source)
  local clear=not command and route.effectiveCommand~="" and route.effectiveCommand~="NONE"
  local moved=source and ((source.slot and route.slot~=source.slot) or (stance and route.stanceSlot~=stance))
  local direct=command and not (source and (source.slot or stance)) and route.effectiveCommand~=command
  if route.error or clear or moved or direct then
   error("The action-bar addon did not update its key routing on "..key..". Change this key in that addon's binding settings.")
  end
 end
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
 if not installed or installed.name~=name or not K.Macros:SameBody(name,installed.body,body) then installed=labels and labels.byName[name] end
 if installed and installed.name==name and K.Macros:SameBody(name,installed.body,body) and K.Macros:SameBody(name,(K.db.ownedMacros or {})[name],body) then
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
function C:Describe(command,key,page,pageType,labels,sourceRoute)
 -- Hex-escape separators so different physical key strings never collide.
 local identity=key:gsub("[^%w]",function(ch) return string.format("_%02x",string.byte(ch)) end)
 local a={id="live-"..identity,key=key,keys={key},command=command,liveCommand=command,
  current=true,readOnly=true,form="all",scope="all",kind="system",known=true,
  label=commandLabel(command),category="Game controls"}
 -- A staged rebind still previews the source button, even before the addon
 -- has installed its override for the new key. The saved command stays intact.
 local route
 if sourceRoute then route=K.ActionBars:Route(sourceRoute.command,sourceRoute.key,page,pageType,true)
 else route=K.ActionBars:Route(command,key,page,pageType,read(GetBindingAction,key)==command) end
 a.actionRoute=route; a.effectiveCommand=route.effectiveCommand; a.actionBarProvider=route.provider
 a.actionBarError=route.error
 local slot=route.slot
 if route.effectiveCommand~=command then a.label=commandLabel(route.effectiveCommand or command) end
 if route.error then a.category="Addon controls"; return a end
 if route.stanceSlot then stanceAction(a,route.stanceSlot); return a end
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
 self.edits.expectedRoutes=self.edits.expectedRoutes or {}; self.edits.keyRoutes=self.edits.keyRoutes or {}
 K.db.currentEditDraft=self.edits
 return self.edits
end
function C:Discard()
 self.edits=nil; K.db.currentEditDraft=nil; self:Invalidate()
end
function C:HasEdits() local e=self.edits; return e and (next(e.keys) or next(e.slots) or e.nativeMouseover)~=nil or false end
function C:GetNativeMouseoverState()
 local state=K.API:GetNativeMouseoverState()
 local edit=self.edits and self.edits.nativeMouseover
 if edit then
  state.enabled=edit.enabled; state.pending=true
  local merged=self:MergeMouseoverRepairs(self.edits)
  state.repairCount=merged.nativeMouseover.repairCount or 0
 end
 return state
end
function C:SetNativeMouseover(enabled)
 if type(enabled)~="boolean" then return false,"Choose whether to enable mouseover casting." end
 if K.Engine.busy or (InCombatLockdown and InCombatLockdown()) then return false,"Leave combat and wait for the current operation." end
 local state=K.API:GetNativeMouseoverState()
 if not state.supported then return false,state.reason end
 local repairs=enabled and self:CollectMouseoverRepairs() or nil
 local hasRepairs=repairs and (next(repairs.slots) or next(repairs.keys))
 local unchanged=enabled and state.enabled and state.autoSelfCast or not enabled and state.enableMouseoverCast=="0"
 if unchanged and not hasRepairs then
  if self.edits then self.edits.nativeMouseover=nil end
 else
  self:Edits().nativeMouseover={enabled=enabled,expected=K.Copy(state),repairs=repairs}
 end
 local count=self:GetNativeMouseoverState().repairCount or 0
 return true,"Mouseover casting staged."..(count>0 and (" "..count.." older healing binding(s) will also be updated.") or "").." Apply changes installs it."
end
-- Only an explicit checkbox enable may re-adopt a detached, unchanged macro.
-- Capture exact ownership and a live bound route, never infer from macro text.
function C:CollectMouseoverRepairs()
 local repairs={slots={},keys={}}; local saved=K.db.currentLayout or {}; local draft=self.edits or {}
 local raw=self:Build(); local managed={}
 for _,at in ipairs(K.NativeBars:ManagedSlots()) do managed[at]=true end
 local function candidate(entry)
  local content=entry.content
  if not entry.spellID or entry.targetMode~="mouseover" or type(content)~="table" or content.kind~="macro"
      or not content.name or type(content.body)~="string" or not K.Macros:SameBody(content.name,entry.body,content.body)
      or not K.Macros:SameBody(content.name,(K.db.ownedMacros or {})[content.name],content.body) or not K.Macros:FindExact(content.name,content.body) then return end
  local target=self:TargetAction({kind="spell",spellID=entry.spellID,name=entry.name})
  if not target or target.targeting~="help" or target.noSelf then return end
  local ok,resolved=pcall(self.ResolveEntry,self,entry)
  if not ok or resolved.pending or not resolved.body or resolved.body==content.body then return end
  -- Reconstruct the previous generated helper, rather than interpreting an
  -- arbitrary owned macro as a spell merely because its saved label matches.
  local legacy=resolved.body:gsub("%[help,nodead%]%[@player%]","[help,nodead]",1)
  if not K.Macros:SameBody(content.name,content.body,legacy) then return end
  resolved.detached=nil
  return resolved
 end
 for at,entry in pairs(saved.slots or {}) do
  if managed[at] and not (draft.slots and draft.slots[at]) then
   local resolved=candidate(entry); local live=resolved and K.NativeBars:ReadSlot(at)
   if resolved and K.NativeBars:SameContent(live,entry.content) then
    for _,action in ipairs(raw.actions) do
     if action.liveSlot==at and not action.actionBarError and not (draft.keys and draft.keys[action.key]~=nil) then
      local route=self:ReadRoute(action.key)
      if not route.error and route.slot==at then
       repairs.slots[at]={entry=resolved,original=K.Copy(entry.content),key=action.key,route=route}; break
      end
     end
    end
   end
  end
 end
 for key,entry in pairs(saved.keys or {}) do
  if not (draft.keys and draft.keys[key]~=nil) then
   local resolved=candidate(entry); local route=resolved and self:ReadRoute(key)
   if resolved and not route.error and not route.slot and route.command==entry.command and route.effectiveCommand==entry.command then
    repairs.keys[key]={entry=resolved,original=K.Copy(entry.content),key=key,route=route}
   end
  end
 end
 return repairs
end
function C:MergeMouseoverRepairs(edits)
 local edit=edits and edits.nativeMouseover
 if not edit or not edit.repairs then return edits end
 local merged=K.Copy(edits); local active={slots={},keys={}}
 merged.expectedRoutes=merged.expectedRoutes or {}; merged.nativeMouseover.activeRepairs=active; merged.nativeMouseover.repairCount=0
 for kind,records in pairs(edit.repairs) do
  for id,record in pairs(records) do
   local free=merged.keys[record.key]==nil and (kind~="slots" or not merged.slots[id])
   if free then
    active[kind][id]=K.Copy(record); merged.nativeMouseover.repairCount=merged.nativeMouseover.repairCount+1
    if kind=="slots" then merged.slots[id]=K.Copy(record.entry); merged.expectedSlots[id]=K.Copy(record.original)
    else merged.keys[id]=record.entry.command; merged.entries[id]=K.Copy(record.entry) end
    if merged.expectedKeys[record.key]==nil then merged.expectedKeys[record.key]=record.route.command end
    if merged.expectedRoutes[record.key]==nil then merged.expectedRoutes[record.key]=K.Copy(record.route) end
   end
  end
 end
 return merged
end
function C:ValidateMouseoverRepair(edits,kind,id)
 local active=edits.nativeMouseover and edits.nativeMouseover.activeRepairs
 local record=active and active[kind] and active[kind][id]; if not record then return end
 local original=record.original
 local route=self:ReadRoute(record.key)
 if not K.Macros:SameBody(original.name,(K.db.ownedMacros or {})[original.name],original.body) or not K.Macros:FindExact(original.name,original.body)
     or route.error or route.command~=record.route.command or route.effectiveCommand~=record.route.effectiveCommand or route.slot~=record.route.slot
     or (kind=="slots" and not K.NativeBars:SameContent(K.NativeBars:ReadSlot(id),original))
     or (kind=="keys" and GetBindingAction(id)~=record.route.command) then
  error("A mouseover spell selected for repair changed. Discard pending edits and review it again.")
 end
end
function C:ValidateMouseoverRepairs(edits)
 local active=edits.nativeMouseover and edits.nativeMouseover.activeRepairs
 for kind,records in pairs(active or {}) do for id in pairs(records) do self:ValidateMouseoverRepair(edits,kind,id) end end
end
function C:ValidateNativeMouseover(edits)
 local edit=edits.nativeMouseover; if not edit then return end
 if type(edit)~="table" or type(edit.enabled)~="boolean" or type(edit.expected)~="table" then error("Invalid pending mouseover casting change.") end
 local state=K.API:GetNativeMouseoverState()
 if not state.supported then error(state.reason) end
 local expected=edit.expected
 if state.enableMouseoverCast~=expected.enableMouseoverCast or (edit.enabled and
     (state.modifier~=expected.modifier or state.autoSelfCastValue~=expected.autoSelfCastValue)) then
  error("Mouseover casting settings changed. Discard the pending edit and choose the setting again.")
 end
end
function C:StageKey(key,command,entry,sourceRoute)
 local e=self:Edits()
 local route=self:ReadRoute(key)
 if route.error then return false,route.error end
 if e.expectedKeys[key]==nil then e.expectedKeys[key]=GetBindingAction(key) or "" end
 if e.expectedRoutes[key]==nil then e.expectedRoutes[key]=route end
 if sourceRoute and e.expectedRoutes[sourceRoute.key]==nil then e.expectedRoutes[sourceRoute.key]=K.Copy(sourceRoute) end
 e.keys[key]=command or false; e.entries[key]=entry and K.Copy(entry) or nil
 e.keyRoutes[key]=sourceRoute and K.Copy(sourceRoute) or nil
 return true
end
function C:Rebind(action,key)
 key=K.API:NormalizeKey(key)
 if not key or key=="ESCAPE" or key:match("BUTTON[12]$") then return false,"Choose a valid key other than Escape or the primary mouse buttons." end
 if not action or not action.key then return false,"Choose a current binding." end
 if action.key=="ESCAPE" or action.key:match("BUTTON[12]$") then return false,"Keep Escape and primary mouse controls on their current keys." end
 if action.key==key then return true end
 local source=self:ReadRoute(action.actionRoute and action.actionRoute.key or action.key)
 local destination=self:ReadRoute(key)
 local current=self:ReadRoute(action.key)
 if action.actionBarError or source.error or current.error or destination.error then return false,action.actionBarError or source.error or current.error or destination.error end
 local command=action.command
 if action.currentEntry and action.currentEntry.pending and not action.liveSlot then
  self:StageKey(key,false,action.currentEntry); self:StageKey(action.key,false)
  return true,"Reservation moved. Apply changes saves it."
 end
 if not command or command=="" then return false,"This binding changed. Review Current again." end
 local metadata; if not action.liveSlot then metadata=action.currentEntry end
 self:StageKey(key,command,metadata,(action.liveSlot or action.stanceSlot) and action.actionRoute); self:StageKey(action.key,false)
 return true,"Binding moved in your Current layout. Apply changes installs it."
end
function C:ClearKey(action)
 if not action or not action.key or action.key=="ESCAPE" or action.key:match("BUTTON[12]$") then return false,"Keep Escape and primary mouse controls." end
 local ok,why=self:StageKey(action.key,false); if not ok then return false,why end
 return true,"Key cleared in your Current layout. Apply changes installs it."
end
-- Only verified spell families and item types can be rewritten. In particular,
-- GetMacroSpell is display metadata, never permission to replace a user macro.
function C:TargetAction(action)
 if not action or action.builtin or action.petSpell or action.readError or action.actionBarError then return end
 if action.kind=="item" and action.itemID then
  local info=K.Items:GetTargetInfo(action)
  return {kind="item",itemID=action.itemID,itemTargeting=info.kind,itemTargetInfo=info,targeting=info.kind}
 end
 if action.kind~="spell" or not action.spellID then return end
 local _,class=UnitClass("player")
 local flavor=K.API:GetFlavor({flavor="auto"}); local book=K.API:GetCachedSpellbook()
 local catalog=self.targetCatalog
 if not catalog or catalog.class~=class or catalog.flavor~=flavor or catalog.book~=book then
  catalog={class=class,flavor=flavor,book=book,byID={},byName={}}
  local function addName(name,target) if name and not catalog.byName[name] then catalog.byName[name]=target end end
  for _,def in ipairs(K.Profiles:Get(class,flavor)) do
   if not def.kind and not def.builtin and not def.combo and not def.focusOf then
    local target={targeting=def.targeting,noSelf=def.noSelf}
    addName(def.name,target)
    for _,alias in ipairs(def.spellNames or {}) do addName(alias,target) end
    for _,id in ipairs(def.spellIDs or {}) do
     if not catalog.byID[id] then catalog.byID[id]=target end
     addName(K.API:SpellInfo(id),target)
    end
   end
  end
  self.targetCatalog=catalog
 end
 local name=K.API:SpellInfo(action.spellID) or action.spellName or action.name
 local target=catalog.byID[action.spellID] or name and catalog.byName[name]
 if target then local result=K.Copy(target); result.spellID=action.spellID; return result end
end
function C:TargetModes(action)
 local target=self:TargetAction(action)
 return target and K.Library:TargetModes(target) or {"default"}
end
function C:SetTargetMode(action,mode)
 if K.Engine.busy or (InCombatLockdown and InCombatLockdown()) then return false,"Leave combat and wait for the current operation." end
 if not action or not action.current or not action.key then return false,"Choose a current spell or item binding." end
 if action.key=="ESCAPE" or action.key:match("BUTTON[12]$") then return false,"Keep Escape and primary mouse controls on their current keys." end
 local modes=self:TargetModes(action)
 local allowed=false; for _,candidate in ipairs(modes) do if candidate==mode then allowed=true end end
 if not allowed then return false,"That target mode is not supported by this action on this client." end
 if #modes<2 then return false,"This action has no editable targeting behavior." end
 self:Build()
 local current=self:EditingView().byKey[action.key]
 if not current or current.command~=action.command or current.liveSlot~=action.liveSlot or current.spellID~=action.spellID or current.itemID~=action.itemID then
  return false,"This binding changed. Review Current again."
 end
 local data=K.Copy(current.currentEntry or {})
 data.label=current.label; data.icon=current.icon
 if current.kind=="spell" then
  local exact=K.API:ResolveExact(current.spellID,K.API:GetCachedSpellbook())
  if not exact then return false,"Spell details are not available yet. Refresh the spellbook and try again." end
  data.spellID=current.spellID; data.name=data.name or exact.name
  if not current.currentEntry then data.rank=exact.rank~="" and exact.rank or nil end
 else data.itemID=current.itemID end
 data.targetMode=mode~="default" and mode or nil
 local ok,resolved=pcall(self.ResolveEntry,self,data)
 if not ok then return false,tostring(resolved) end
 local staged,why=self:StageResolvedEntry(resolved,current.key)
 if not staged then return false,why end
 return true,"Targeting saved to your Current layout. Apply changes installs it."
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
 local ok,why=self:StageResolvedEntry(data,key)
 if not ok then return false,why end
 return true,"Action added to your Current layout. Apply changes installs it, including future ability reservations."
end
function C:StageResolvedEntry(data,key)
 local e=self:Edits(); self:Build(); local live=self:EditingView().byKey[key]
 local route=self:ReadRoute(key)
 if route.error or live and live.actionBarError then return false,route.error or live.actionBarError end
 if (data.content or data.pending or data.body) and live and live.liveSlot then
  local at=live.liveSlot
  local supported=false; for _,slot in ipairs(K.NativeBars:ManagedSlots()) do if slot==at then supported=true; break end end
  if not supported then return false,"This temporary action slot cannot be edited safely. Choose a normal action-bar key or an empty key." end
  if e.expectedSlots[at]==nil then e.expectedSlots[at]=K.NativeBars:ReadSlot(at) or false end
  if e.expectedKeys[key]==nil then e.expectedKeys[key]=GetBindingAction(key) or "" end
  if e.expectedRoutes[key]==nil then e.expectedRoutes[key]=route end
  if live.actionRoute and e.expectedRoutes[live.actionRoute.key]==nil then e.expectedRoutes[live.actionRoute.key]=K.Copy(live.actionRoute) end
  if data.body then data.content={kind="macro",name=K.Macros:Name(data.body),body=data.body} end
  e.slots[at]=data
 else
  if data.body then data.command="MACRO "..K.Macros:Name(data.body) end
  local ok,why=self:StageKey(key,data.command,data); if not ok then return false,why end
 end
 return true
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
  data.body=nil; data.futureBody=nil; data.macroName=nil; data.macroIndex=nil; data.nativeMacro=nil; data.desiredBody=nil
 elseif data.itemID then
  K.Items:GetCached()
  local item=K.Items:Resolve(data.itemID)
  local available=item and not item.missing
  data.previewCommand="ITEM item:"..data.itemID
  data.command=available and data.previewCommand or false
  data.content=available and {kind="item",id=data.itemID} or false
  data.pending=not available or nil
  data.body=nil; data.futureBody=nil; data.macroName=nil; data.macroIndex=nil; data.nativeMacro=nil; data.desiredBody=nil
 elseif data.desiredBody then
  data.body=data.desiredBody; data.command="MACRO "..K.Macros:Name(data.body)
  data.content={kind="macro",name=K.Macros:Name(data.body),body=data.body}; data.pending=nil
 end
 if (data.spellID or data.itemID) and data.targetMode and data.targetMode~="default" then
  local action={kind=data.spellID and "spell" or "item",spellID=data.spellID,itemID=data.itemID,name=data.name}
  local target=self:TargetAction(action)
  local allowed=false; for _,mode in ipairs(target and K.Library:TargetModes(target) or {}) do if mode==data.targetMode then allowed=true end end
  if not target or not allowed then error("Saved targeting is unavailable for "..tostring(data.label or data.name).." on this client. Choose a supported target mode.") end
  data.targeting=target.targeting; data.noSelf=target.noSelf
  if not data.pending then
   target.known=true; target.spellName=data.name; target.label=data.label; target.targetMode=data.targetMode
   target.explicitRank=data.rank and data.rank~="" or false; target.selectedRank=data.rank
   local body,why=K.Macros:Build(target,{flavor=K.API:GetFlavor({flavor="auto"}),cancelForUtility=false,selfFallback=false})
   if not body then error(why or "Could not build this targeting behavior.") end
   data.body=body; data.command="MACRO "..K.Macros:Name(body)
   data.content={kind="macro",name=K.Macros:Name(body),body=body}
  end
 else data.targeting=nil; data.noSelf=nil end
 return data
end
function C:PrepareEdits(edits)
 edits=self:MergeMouseoverRepairs(edits)
 for at,entry in pairs(edits.slots) do edits.slots[at]=self:ResolveEntry(entry) end
 for key,entry in pairs(edits.entries or {}) do
  edits.entries[key]=self:ResolveEntry(entry); edits.keys[key]=edits.entries[key].command
 end
 return edits
end
-- The Current profile is the last successfully installed (or explicitly
-- synchronized) live setup. It never contains an editing draft or undo history.
local function profileContent(action)
 if action.nativeHidden then return false end
 if action.body and action.macroName then return {kind="macro",name=action.macroName,body=action.body} end
 if action.known and action.spellID then return {kind="spell",id=action.spellID} end
 return false
end
function C:CaptureProfile(snapshot,strictLive)
 local _,class=UnitClass("player")
 local profile={version=1,class=class,snapshot=K.Copy(snapshot),
  currentLayout=K.Copy(K.db.currentLayout or {keys={},slots={}}),
  appliedPlan=K.db.enabled and K.Copy(K.db.appliedPlan) or nil,
  enabled=K.db.enabled and true or false,appliedPreset=K.db.appliedPreset,
  appliedPresetSignature=K.db.appliedPresetSignature,ownedMacros=K.Copy(K.db.ownedMacros or {})}
 -- Reapplying Current restores its active binding set, not another scope's
 -- saved controls. Full operation backups still retain both sets for rollback.
 profile.snapshot.accountBindings=nil; profile.snapshot.characterBindings=nil
 local saved=profile.currentLayout
 saved.keys=saved.keys or {}; saved.slots=saved.slots or {}
 if strictLive then
  for name,body in pairs(profile.ownedMacros) do
   if not K.Macros:FindExact(name,body) then profile.ownedMacros[name]=nil end
  end
  for at,entry in pairs(saved.slots) do
   if K.NativeBars:SameContent(snapshot.native.actions[at],entry.content) then entry.detached=nil
   else saved.slots[at]=nil end
  end
  for key,entry in pairs(saved.keys) do
   local matches=(snapshot.bindings[key] or false)==(entry.command or false)
   if entry.body then matches=matches and K.Macros:FindExact(entry.macroName or tostring(entry.command):match("^MACRO (.+)$"),entry.body) end
   if matches then entry.detached=nil else saved.keys[key]=nil end
  end
 end
 local plan=profile.appliedPlan
 if not strictLive and plan and plan.nativeLayout then
  plan.nativeLayout.detachedKeys={}
  for _,placement in ipairs(plan.nativeLayout.placements or {}) do placement.detached=nil end
 end
 if strictLive and plan and plan.nativeLayout then
  local actions={}; for _,action in ipairs(plan.actions or {}) do actions[action.id]=action end
  local layout=plan.nativeLayout; layout.detachedKeys={}
  for _,placement in ipairs(layout.placements or {}) do
   local action=actions[placement.actionID]
   placement.detached=not action or action.kind=="macroref" or not K.NativeBars:SameContent(snapshot.native.actions[placement.slot],profileContent(action)) or nil
  end
  for key,binding in pairs(layout.keys or {}) do
   local action=actions[binding.macroAction]
   local command=binding.command or (action and action.macroName and "MACRO "..action.macroName)
   if snapshot.bindings[key]~=command or (action and action.body and not K.Macros:FindExact(action.macroName,action.body)) then layout.detachedKeys[key]=true end
  end
 end
 return profile
end
local function recoverProfileMetadata(result)
 -- Earlier Sync/Reapply versions discarded unchanged generated metadata when
 -- WoW appended a newline. Recover only a proved identity at its saved
 -- destination, never restore a backup's positions or infer spells from text.
 local ledger=K.db.ownedMacros or {}; local snapshot=result.snapshot
 local saved=result.currentLayout or {keys={},slots={}}; result.currentLayout=saved
 saved.keys=saved.keys or {}; saved.slots=saved.slots or {}
 local function registered(name,body,owned)
  return type(name)=="string" and type(owned[name])=="string" and K.Macros:SameBody(name,owned[name],body,owned)
 end
 local function matches(content,name,body)
  return content and content.kind=="macro" and content.name==name and registered(name,body,ledger)
   and K.Macros:SameBody(name,body,content.body,ledger)
 end
 local function keyMatches(key,name,body)
  if not registered(name,body,ledger) or snapshot.bindings[key]~="MACRO "..name then return false end
  local evidence=false
  for _,content in pairs(snapshot.native.actions) do
   if content and content.kind=="macro" and content.name==name then
    if not matches(content,name,body) then return false end
    evidence=true
   end
  end
  -- A direct binding records only the macro's name. Without saved body
  -- evidence, its live text must still prove the registered generated identity.
  return evidence or K.Macros:FindExact(name,ledger[name])~=nil
 end
 local function adopt(layout,owned)
  owned=owned or {}
  for _,kind in ipairs({"slots","keys"}) do
   for at,entry in pairs(layout and layout[kind] or {}) do
    local content=entry.content; local name=entry.macroName
    if not saved[kind][at] and (entry.spellID or entry.itemID) and content and content.kind=="macro"
     and content.name==name and entry.command=="MACRO "..tostring(name)
     and registered(name,entry.body,ledger) and registered(name,entry.body,owned)
     and K.Macros:SameBody(name,entry.body,content.body,ledger)
     and (kind=="slots" and matches(snapshot.native.actions[at],name,entry.body)
      or kind=="keys" and keyMatches(at,name,entry.body)) then
     saved[kind][at]=K.Copy(entry); saved[kind][at].detached=nil
     result.ownedMacros[name]=ledger[name]
    end
   end
  end
 end
 adopt(K.db.currentLayout,ledger)
 local order=K.db.bindingBackupOrder or {}; local history={}
 for index=#order,math.max(1,#order-31),-1 do
  local backup=(K.db.bindingBackups or {})[order[index]]
  if backup and backup.complete and backup.runtime then
   adopt(backup.runtime.currentLayout,backup.runtime.ownedMacros); history[#history+1]=backup.runtime
  end
 end
 local plan=result.appliedPlan
 if plan and plan.nativeLayout then
  local actions={}; for _,action in ipairs(plan.actions or {}) do actions[action.id]=action end
  -- A buggy reapply could also regenerate a detached action's body without
  -- installing it, losing its old macro name. Recover that identity only from
  -- the same historical action and destination; keep this plan's settings,
  -- semantic action fields, placements and key assignments.
  local recovered={}
  local function restoreIdentity(action,old,owned)
   if not action or action.kind=="macroref" or not old or old.kind=="macroref" or action.id~=old.id
    or not registered(old.macroName,old.body,ledger) or not registered(old.macroName,old.body,owned or {}) then return false end
   if recovered[action.id] and (action.macroName~=old.macroName or not K.Macros:SameBody(old.macroName,action.body,old.body,ledger)) then return false end
   action.macroName=old.macroName; action.body=old.body; action.macroIndex=nil
   recovered[action.id]=true; result.ownedMacros[old.macroName]=ledger[old.macroName]
   return true
  end
  for _,runtime in ipairs(history) do
   local previous=runtime.enabled and runtime.appliedPlan
   if previous and previous.nativeLayout then
    local priorActions={}; for _,action in ipairs(previous.actions or {}) do priorActions[action.id]=action end
    local priorSlots={}; for _,placement in ipairs(previous.nativeLayout.placements or {}) do priorSlots[placement.slot]=placement.actionID end
    for _,placement in ipairs(plan.nativeLayout.placements or {}) do
     local old=priorActions[placement.actionID]
     if placement.detached and priorSlots[placement.slot]==placement.actionID and old
      and matches(snapshot.native.actions[placement.slot],old.macroName,old.body)
      and restoreIdentity(actions[placement.actionID],old,runtime.ownedMacros) then placement.detached=nil end
    end
    for key in pairs(plan.nativeLayout.detachedKeys or {}) do
     local binding=(plan.nativeLayout.keys or {})[key]; local prior=(previous.nativeLayout.keys or {})[key]
     local id=binding and binding.macroAction; local old=id and priorActions[id]
     if old and prior and prior.macroAction==id and keyMatches(key,old.macroName,old.body)
      and restoreIdentity(actions[id],old,runtime.ownedMacros) then plan.nativeLayout.detachedKeys[key]=nil end
    end
   end
  end
  for _,placement in ipairs(plan.nativeLayout.placements or {}) do
   local action=actions[placement.actionID]
   if placement.detached and action and action.kind~="macroref" and matches(snapshot.native.actions[placement.slot],action.macroName,action.body) then
    placement.detached=nil; result.ownedMacros[action.macroName]=ledger[action.macroName]
   end
  end
  for key in pairs(plan.nativeLayout.detachedKeys or {}) do
   local binding=(plan.nativeLayout.keys or {})[key]; local action=binding and actions[binding.macroAction]
   if action and action.kind~="macroref" and keyMatches(key,action.macroName,action.body) then
    plan.nativeLayout.detachedKeys[key]=nil; result.ownedMacros[action.macroName]=ledger[action.macroName]
   end
  end
 end
end
function C:BuildProfileReapply(profile)
 local _,class=UnitClass("player")
 if type(profile)~="table" or profile.class~=class or type(profile.snapshot)~="table"
  or type(profile.snapshot.bindings)~="table" or type(profile.snapshot.native)~="table"
  or type(profile.snapshot.native.actions)~="table" then error("No saved Current setup is available for this character. Use Sync from game first.") end
 local result=K.Copy(profile)
 result.ownedMacros=result.ownedMacros or {}
 result.snapshot.accountBindings=nil; result.snapshot.characterBindings=nil
 result.slotSources={}; result.keySources={}
 result.macroPlan={actions={},settings={allowAccountMacros=false}}
 local snapshot=result.snapshot
 local supported={}; for _,at in ipairs(K.NativeBars:ManagedSlots()) do supported[at]=true end
 for at in pairs(snapshot.native.actions) do if not supported[at] then error("Saved action slot "..tostring(at).." is unavailable on this client.") end end
 recoverProfileMetadata(result)
 K.API:InvalidateSpellbook()
 local book=K.API:GetCachedSpellbook(); local forms=K.API:GetForms()
 local plan=result.appliedPlan
 if plan and plan.nativeLayout then
  local actions={}
  for index,action in ipairs(plan.actions or {}) do
   local updated=action
   if not action.kind and not action.builtin then
    local why; updated,why=K.AvailabilityEngine:Resolve(action,plan,book,forms)
    if not updated then error(why) end
   elseif action.kind~="macroref" and action.kind~="system" then
    updated=K.Copy(action)
    local body,why=K.Macros:Build(updated,plan.settings)
    if why then error(why) end
    updated.body=body
    local ok,problem=K.NativeBars:MakeMacro(updated,plan.settings,updated.nativeOverflow or updated.nativeBlockAlt)
    if not ok then error(problem) end
   end
   plan.actions[index]=updated; actions[updated.id]=updated
  end
  for _,placement in ipairs(plan.nativeLayout.placements or {}) do
   local action=actions[placement.actionID]
   if action and not placement.detached and action.kind~="macroref" then
    if not supported[placement.slot] then error("Saved action slot "..tostring(placement.slot).." is unavailable on this client.") end
    result.slotSources[placement.slot]={action=action}
   end
  end
  for key,binding in pairs(plan.nativeLayout.keys or {}) do
   if not (plan.nativeLayout.detachedKeys or {})[key] then
    local action=actions[binding.macroAction]
    if binding.command then snapshot.bindings[key]=binding.command
    elseif action and action.kind~="macroref" then result.keySources[key]={action=action} end
   end
  end
  plan.formSignature=K.API:FormSignature()
 end
 local saved=result.currentLayout or {keys={},slots={}}; result.currentLayout=saved
 saved.keys=saved.keys or {}; saved.slots=saved.slots or {}
 for at,entry in pairs(saved.slots) do
  if not supported[at] then error("Saved action slot "..tostring(at).." is unavailable on this client.") end
  local resolved=self:ResolveEntry(entry); resolved.detached=nil; saved.slots[at]=resolved
  result.slotSources[at]={action=resolved,entry=true}
 end
 for key,entry in pairs(saved.keys) do
  local resolved=self:ResolveEntry(entry); resolved.detached=nil; saved.keys[key]=resolved
  result.keySources[key]={action=resolved,entry=true}
 end
 -- Generated macros without spell metadata (for example saved emotes) can be
 -- recreated verbatim. Personal macro text remains an exact external reference.
 local rawMacros={}
 local function rawMacro(name,body,icon)
  if not name or type(body)~="string" or not K.Macros:SameBody(name,result.ownedMacros[name],body,result.ownedMacros) then return end
  body=result.ownedMacros[name]
  local token=name.."\n"..body
  if not rawMacros[token] then rawMacros[token]={body=body,macroName=name,label=name,icon=icon,known=true,nativeMacro=true} end
  return rawMacros[token]
 end
 for at,content in pairs(snapshot.native.actions) do
  if not result.slotSources[at] and content and content.kind=="macro" then
   local action=rawMacro(content.name,content.body,content.icon)
   if action then result.slotSources[at]={action=action} end
  end
 end
 for key,command in pairs(snapshot.bindings) do
  if not result.keySources[key] then
   local name=command:match("^MACRO (.+)$")
   local action=name and rawMacro(name,result.ownedMacros[name])
   if action then result.keySources[key]={action=action} end
  end
 end
 local seen={}
 for _,sources in ipairs({result.slotSources,result.keySources}) do
  for _,source in pairs(sources) do
   local action=source.action
   if action.body and not seen[action] then
    action.nativeMacro=true; seen[action]=true
    result.macroPlan.actions[#result.macroPlan.actions+1]=action
   end
  end
 end
 return result
end
function C:FinalizeProfileReapply(result)
 local function content(source)
  local action=source.action
  if action.body then
   local index,name,icon=K.Macros:FindExact(action.macroName,action.body)
   if not index or (K.db.ownedMacros or {})[name]~=action.body then error("A refreshed macro changed before reapplying the setup.") end
   local value={kind="macro",id=index,name=name,icon=icon,body=action.body}
   if source.entry then action.content=K.Copy(value); action.command="MACRO "..name end
   return value
  end
  return source.entry and action.content or profileContent(action)
 end
 for at,source in pairs(result.slotSources) do result.snapshot.native.actions[at]=content(source) or false end
 for key,source in pairs(result.keySources) do
  local action=source.action
  if action.body then content(source); result.snapshot.bindings[key]="MACRO "..action.macroName
  elseif source.entry then result.snapshot.bindings[key]=action.command or nil
  else error("A saved macro shortcut is unavailable: "..key) end
 end
 for key,owner in pairs(result.appliedPlan and result.appliedPlan.bindingOwnership or {}) do
  if not (result.appliedPlan.nativeLayout.detachedKeys or {})[key] then owner.command=result.snapshot.bindings[key] end
 end
 return result
end
local function sameEntry(a,b)
 return a.command==b.command and a.pending==b.pending and K.NativeBars:SameContent(a.content,b.content)
end
function C:RefreshEdits()
 local saved=K.db.currentLayout; if not saved then return end
 local edits={keys={},entries={},slots={},expectedKeys={},expectedSlots={}}
 local pending=self:MergeMouseoverRepairs(self.edits)
 for at,entry in pairs(saved.slots or {}) do
  if not (pending and pending.slots[at]) and not entry.detached then
   local current=K.NativeBars:ReadSlot(at)
   -- Macro metadata can be temporarily unavailable while the client loads it.
   -- An unreadable occupied slot is not proof that the user replaced our action.
   if not (current and current.readError) then
    if K.NativeBars:SameContent(current,entry.content) then
     local resolved=self:ResolveEntry(entry)
     if not sameEntry(entry,resolved) then edits.slots[at]=resolved; edits.expectedSlots[at]=entry.content or false end
    else entry.detached=true end
   end
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
 action.targetMode=entry.targetMode; action.targeting=entry.targeting; action.noSelf=entry.noSelf
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
 local raw=self:Get(); local plan=K.Copy(raw); local e=self:MergeMouseoverRepairs(self.edits)
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
  local a=self:Describe(command,key,plan.actionPage,plan.actionPageType,nil,e and e.keyRoutes and e.keyRoutes[key])
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
   preview.liveSlot=a.liveSlot; preview.nativeSlot=a.liveSlot; preview.command=command; preview.liveCommand=command
   preview.actionRoute=a.actionRoute; preview.effectiveCommand=a.effectiveCommand; preview.actionBarProvider=a.actionBarProvider
   preview.actionBarError=a.actionBarError; a=preview
  end
  self:Annotate(a,entry); if entry and entry.pending and not a.liveSlot then a.command=false end
  a.readOnly=a.actionBarError~=nil; a.current=true
  plan.actions[#plan.actions+1]=a; plan.byID[a.id]=a; plan.byKey[key]=a
 end
 table.sort(plan.actions,function(a,b) return a.key<b.key end)
 return plan
end
