local _, K = ...
K.Items={candidates={},pending={},requested={}}
local I=K.Items
local function validID(id)
    return type(id)=="number" and id>0 and id<2147483647 and id%1==0
end
local function mountID(id)
    return type(id)=="string" and id:match("^spell:%d+$") and tonumber(id:sub(7))>0
end
local function requestInfo(self,id)
    if not validID(id) or self.requested[id] then return end
    self.requested[id]=true; self.pending[id]=true
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end
function I:Invalidate()
    self.valid=false
    self.revision=(self.revision or 0)+1
    K:InvalidatePreview()
end
function I:OnItemInfoReceived(id)
    if not self.pending[id] then return false end
    self.pending[id]=nil
    self:Invalidate()
    return true
end
local function scan(self)
    local candidates={}
    local seen={}
    local function add(id,location,slot,count)
        if not id then return end
        local name,_,_,_,_,_,_,_,equipLoc,icon=K.API:ItemInfo(id)
        local effect,spellID=K.API:ItemSpell(id)
        if not name then
            -- The item-info event is global. Track only our outstanding IDs and
            -- request each once; failed replies must not start a request loop.
            requestInfo(self,id)
            return
        end
        if not effect then return end
        local key=tostring(id)..":"..tostring(slot or "bag")
        if seen[key] then seen[key].count=seen[key].count+(count or 1); return end
        local equippable=equipLoc and equipLoc~="" and equipLoc~="INVTYPE_BAG" and equipLoc~="INVTYPE_QUIVER"
        local item={id=id,name=name,icon=icon,location=location,slot=slot,count=count or 1,effect=effect,spellID=spellID,requiresEquip=not slot and equippable or false}
        seen[key]=item; candidates[#candidates+1]=item
    end
    for slot=1,19 do
        local id=GetInventoryItemID and GetInventoryItemID("player",slot)
        if id then add(id,"Equipped · slot "..slot,slot,1) end
    end
    local maxBag=NUM_BAG_SLOTS or 4
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then maxBag=math.max(maxBag,Enum.BagIndex.ReagentBag) end
    for bag=0,maxBag do
        local n=C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        for slot=1,n do
            if C_Container and C_Container.GetContainerItemInfo then
                local info=C_Container.GetContainerItemInfo(bag,slot)
                if info then add(info.itemID,"Bag "..bag,nil,info.stackCount) end
            elseif GetContainerItemID then
                local id=GetContainerItemID(bag,slot)
                local _,count=GetContainerItemInfo(bag,slot)
                add(id,"Bag "..bag,nil,count)
            end
        end
    end
    if C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID then
        for _,mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
            local name,spellID,icon,active,usable,source,favorite,factionSpecific,faction,hidden,collected=C_MountJournal.GetMountInfoByID(mountID)
            if collected and not hidden and spellID then
                candidates[#candidates+1]={id="spell:"..spellID,spellID=spellID,name=name,icon=icon,kind="mountspell",location="Mount collection",count=1,effect="Summon mount",requiresEquip=false}
            end
        end
    end
    table.sort(candidates,function(a,b) if (a.slot~=nil)~=(b.slot~=nil) then return a.slot~=nil end return a.name<b.name end)
    return candidates
end
function I:Scan(retryMissing)
    if self.scanning then return self.candidates end
    if retryMissing then self.pending={}; self.requested={} end
    local revision=self.revision
    self.scanning=true
    local ok,candidates=pcall(scan,self)
    self.scanning=false
    if not ok then self.valid=false; error(candidates) end
    self.candidates=candidates
    self.valid=revision==self.revision
    return candidates
end
function I:GetCached()
    if not self.valid then return self:Scan() end
    return self.candidates
end
function I:GetSelected(slotName)
    local preset=K.db.presets[K.db.activePreset]
    return preset and preset.items[slotName]
end
function I:Select(slotName,id)
    if K.Engine and K.Engine.busy then return false,"Wait for the current operation to finish." end
    if not ({utility=true,potion=true,healthstone=true,mount=true})[slotName] then return false,"Unknown item slot." end
    if id~=nil then
        if slotName=="mount" and type(id)=="string" and id:match("^spell:%d+$") and tonumber(id:sub(7))>0 then
            -- Keep spell mounts distinct from bag item IDs.
        else id=tonumber(id); if not id or id<1 or id%1~=0 then return false,"Enter a valid item ID, or spell:ID for a mount." end end
    end
    if id~=nil and self.SetBindingItem then return self:SetBindingItem("item."..slotName,id) end
    K.db.presets[K.db.activePreset].items[slotName]=id
    if K.db.settings.itemBindings and K.db.settings.itemBindings["item."..slotName] then K.db.settings.itemBindings["item."..slotName].selected=nil end
    if slotName=="mount" then K.db.settings.mount=id end
    K.dirty=true
    K:InvalidatePreview()
    return true,"Item staged. Apply to activate it."
end
function I:SetPreset(name)
    return K.Presets:Select(name)
end
function I:Resolve(id)
    if not id then return end
    for _,item in ipairs(self.candidates) do if item.id==id and item.slot then return item end end
    for _,item in ipairs(self.candidates) do if item.id==id then return item end end
    if type(id)=="string" and id:match("^spell:%d+$") then
        local spellID=tonumber(id:sub(7)); local name,icon=K.API:SpellInfo(spellID)
        return {id=id,name=name or ("Mount spell "..spellID),icon=icon,spellID=spellID,kind="mountspell",missing=not K.API:IsKnown(spellID),requiresEquip=false}
    end
    local name,_,_,_,_,_,_,_,equipLoc,icon=K.API:ItemInfo(id)
    local effect,spellID=K.API:ItemSpell(id)
    if not name then requestInfo(self,id) end
    local equippable=equipLoc and equipLoc~="" and equipLoc~="INVTYPE_BAG" and equipLoc~="INVTYPE_QUIVER"
    return {id=id,name=name or ("Item "..id),icon=icon,missing=true,loading=not name,requiresEquip=equippable or false,effect=effect,spellID=spellID,noUse=name and not effect or false}
end
-- Unit targeting is opt-in from verified item families, never inferred from
-- IsHelpfulItem/IsHarmfulItem (ground devices can also report those flags).
-- Classic First Aid bandages: the on-use spell heals a friendly unit.
local friendlyItems={ [1251]=true,[2581]=true,[3530]=true,[3531]=true,[6450]=true,[6451]=true,[8544]=true,[8545]=true,[14529]=true,[14530]=true }
-- Unit-target engineering devices. Classic effect handlers explicitly consume
-- unitTarget; do not generalize these to bombs, mortars, or arbitrary gadgets.
-- https://github.com/cmangos/mangos-classic/blob/master/src/game/Spells/SpellEffects.cpp
-- Era/Forever HarmItems corroborates all four IDs:
-- https://github.com/WeakAuras/LibRangeCheck-3.0/blob/main/LibRangeCheck-3.0/LibRangeCheck-3.0.lua
local hostileItems={ [10720]=true,[10645]=true,[10716]=true,[4388]=true }
local groundItems={ [10577]=true,[4378]=true,[4380]=true,[4390]=true,[10507]=true,[10514]=true,[15993]=true,[18641]=true }
local selfItems={ [117]=true,[159]=true,[1179]=true,[1205]=true,[1708]=true,[1645]=true,[8766]=true,[8952]=true,[8932]=true,[118]=true,[858]=true,[929]=true,[3928]=true,[13446]=true }
function I:GetTargetInfo(action)
    local id=action and (action.selectedID or action.itemSelectedID or action.itemID or action.id)
    if friendlyItems[id] then return {kind="help",verified=true,label="Friendly unit"} end
    if hostileItems[id] then return {kind="harm",verified=true,label="Enemy unit"} end
    if groundItems[id] then return {kind="ground",verified=true,label="Ground reticle"} end
    if selfItems[id] then return {kind="self",verified=true,label="Self use"} end
    return {kind="unknown",verified=false,label="Item default (target type unverified)"}
end
function I:GetTargetModes(action)
    local kind=self:GetTargetInfo(action).kind
    if kind=="help" or kind=="harm" then
        local values={"default","mouseover","target"}
        if K.API:SupportsFocus() then values[#values+1]="focus" end
        if kind=="help" then values[#values+1]="self" end
        return values
    end
    return {"default"}
end
function I:ValidateBinding(record)
    if type(record)~="table" then return false,"Invalid item binding." end
    for field in pairs(record) do if field~="selected" and field~="alternatives" and field~="targetMode" and field~="empty" then return false,"Unknown item-binding field." end end
    if record.empty~=nil and type(record.empty)~="boolean" then return false,"Invalid empty item choice." end
    if record.selected~=nil and not validID(record.selected) and not mountID(record.selected) then return false,"Invalid selected item." end
    if record.alternatives~=nil then
        if type(record.alternatives)~="table" or #record.alternatives>32 then return false,"Choose at most 32 saved items per key." end
        local seen={}; local count=0
        for index,id in pairs(record.alternatives) do
            if type(index)~="number" or index<1 or index>#record.alternatives or index%1~=0 or (not validID(id) and not mountID(id)) or seen[id] then return false,"Invalid saved item choices." end
            seen[id]=true
            count=count+1
        end
        if count~=#record.alternatives then return false,"Saved item choices must be a continuous list." end
    end
    if record.targetMode and record.targetMode~="default" then
        if record.targetMode=="focus" and not K.API:SupportsFocus() then return false,"Focus targeting is unavailable on this client. Choose another item target mode." end
        local allowed=false; for _,mode in ipairs(self:GetTargetModes({selectedID=record.selected})) do if mode==record.targetMode then allowed=true end end
        if not allowed then return false,"That item has no verified support for this target mode." end
    end
    return true
end
function I:ResolveBinding(actionID,fallbackID,record)
    self:GetCached()
    record=record or (K:GetSettings().itemBindings or {})[actionID] or {}
    if record.empty then return end
    local selected=record.selected or fallbackID
    if not selected then return nil end
    local item=K.Copy(self:Resolve(selected)); if not item then return end
    item.selectedID=selected; item.alternatives=K.Copy(record.alternatives or {})
    item.targetMode=record.targetMode or "default"
    item.known=not item.missing and not item.requiresEquip and (item.kind=="mountspell" or item.effect~=nil)
    item.availability=item.loading and "Loading item information" or item.requiresEquip and "Equip this item first" or item.noUse and "No on-use effect" or item.missing and "Not in bags or equipment" or "Available"
    item.itemBinding={selected=selected,alternatives=K.Copy(item.alternatives),targetMode=item.targetMode}
    return item
end
function I:ApplyToAction(action,fallbackID,record)
    local item=self:ResolveBinding(action.id,fallbackID,record)
    action.kind="item"; action.category="Items"; action.targeting="none"
    action.itemID=nil; action.itemSlot=nil; action.mountSpell=nil; action.spellID=nil; action.spellName=nil
    action.known=false; action.itemSelectedID=record and record.selected or fallbackID
    action.isMount=action.id=="item.mount" or action.isMount
    if record and record.empty then action.itemSelectedID=nil; action.itemBinding=K.Copy(record) end
    if item then
        action.itemSelectedID=item.selectedID; action.itemBinding=K.Copy(item.itemBinding)
        action.label=item.name; action.icon=item.icon; action.targetMode=item.targetMode~="default" and item.targetMode or nil
        action.itemAvailability=item.availability; action.itemMissing=item.missing; action.requiresEquip=item.requiresEquip; action.known=item.known
        if item.kind=="mountspell" then action.mountSpell=item.spellID; action.spellName=item.name; action.spellID=item.spellID; action.isMount=true
        elseif item.slot then action.itemSlot=item.slot else action.itemID=item.id end
        local targetInfo=self:GetTargetInfo(item)
        action.itemTargetInfo=targetInfo
        action.itemTargeting=(targetInfo.kind=="help" or targetInfo.kind=="harm") and targetInfo.kind or nil
    end
    return action,item
end
local function bindingRecord(self,id)
    K:GetSettings().itemBindings=K:GetSettings().itemBindings or {}
    local map=K:GetSettings().itemBindings
    local slot=id:match("^item%.(.+)$")
    local custom=(K:GetSettings().customActions or {})[id]
    map[id]=map[id] or {selected=slot and self:GetSelected(slot) or custom and custom.itemID,alternatives={},targetMode="default"}; map[id].alternatives=map[id].alternatives or {}
    return map[id]
end
local function mutable(id)
    if K.Engine and K.Engine.busy then return false,"Wait for the current operation to finish." end
    if type(id)~="string" or not id:match("^[%w%._%-]+$") then return false,"Choose an item binding." end
    if id=="item.trinket13" or id=="item.trinket14" then return false,"Trinket keys follow their equipped slots automatically." end
    local map=K:GetSettings().itemBindings or {}
    if not map[id] then
        local count=0; for _ in pairs(map) do count=count+1 end
        if count>=512 then return false,"This preset already has the maximum 512 item binding records." end
    end
    return true
end
local function changed() if K.Presets then K.Presets:Changed() else K.dirty=true; K:InvalidatePreview() end end
function I:AddAlternative(id,itemID)
    local ok,why=mutable(id); if not ok then return false,why end
    if type(itemID)=="string" and not mountID(itemID) then itemID=tonumber(itemID) end
    if not validID(itemID) and not (id=="item.mount" and mountID(itemID)) then return false,"Enter a valid item ID." end
    local record=bindingRecord(self,id)
    for _,existing in ipairs(record.alternatives) do if existing==itemID then return true,"Item is already saved for this key." end end
    if #record.alternatives>=32 then return false,"Choose at most 32 saved items per key." end
    record.alternatives[#record.alternatives+1]=itemID
    self:Resolve(itemID); changed(); return true,"Item saved as a choice for this key."
end
function I:SetBindingItem(id,itemID)
    if itemID==nil then return self:ClearBindingItem(id) end
    local ok,why=self:AddAlternative(id,itemID); if not ok then return false,why end
    if type(itemID)=="string" and not mountID(itemID) then itemID=tonumber(itemID) end
    local record=bindingRecord(self,id); record.selected=itemID; record.targetMode="default"; record.empty=nil
    if id:match("^item%.") then
        local slot=id:sub(6); if ({utility=true,potion=true,healthstone=true,mount=true})[slot] then
            K.db.presets[K.db.activePreset].items[slot]=itemID
            if slot=="mount" then K:GetSettings().mount=itemID end
        end
    end
    changed(); return true,"Selected item staged. Use the preset to activate it."
end
function I:ClearBindingItem(id)
    local ok,why=mutable(id); if not ok then return false,why end
    local record=bindingRecord(self,id); record.selected=nil; record.empty=true; record.targetMode="default"
    local slot=id:match("^item%.(.+)$")
    if slot and ({utility=true,potion=true,healthstone=true,mount=true})[slot] then
        K.db.presets[K.db.activePreset].items[slot]=nil
        if slot=="mount" then K:GetSettings().mount=nil end
    end
    changed(); return true,"This item position is empty. Its saved choices remain available."
end
function I:RemoveAlternative(id,itemID)
    local ok,why=mutable(id); if not ok then return false,why end
    local record=bindingRecord(self,id)
    if record.selected==itemID then return false,"Choose a different current item before removing this choice." end
    for index,existing in ipairs(record.alternatives) do if existing==itemID then table.remove(record.alternatives,index); changed(); return true,"Saved item choice removed." end end
    return false,"That item is not saved for this key."
end
function I:SetBindingTargetMode(id,mode)
    local ok,why=mutable(id); if not ok then return false,why end
    local record=bindingRecord(self,id); local proposed=K.Copy(record); proposed.targetMode=mode
    ok,why=self:ValidateBinding(proposed); if not ok then return false,why end
    record.targetMode=mode; changed(); return true,"Item target behavior staged."
end
function I:GetAvailableChoices() return self:GetCached() end
function I:LibraryEntries()
    local entries,seen={},{}
    local function add(item)
        if type(item.id)~="number" or seen[item.id] then return end
        seen[item.id]=true
        entries[#entries+1]={id="item."..item.id,itemID=item.id,label=item.name,icon=item.icon,count=item.count or 0,description=item.effect,known=not item.missing and not item.requiresEquip and not item.noUse,category=item.requiresEquip and "Equip first" or item.missing and "Saved items" or "Inventory",availability=item.availability or (item.missing and "Not in bags or equipment" or "Available"),descriptor={kind="item",itemID=item.id}}
    end
    for _,item in ipairs(self:GetCached()) do add(item) end
    for _,record in pairs(K:GetSettings().itemBindings or {}) do
        if record.selected then add(self:Resolve(record.selected)) end
        for _,id in ipairs(record.alternatives or {}) do add(self:Resolve(id)) end
    end
    for _,slot in ipairs({"utility","potion","healthstone","mount"}) do local id=self:GetSelected(slot); if id then add(self:Resolve(id)) end end
    table.sort(entries,function(a,b) return a.label<b.label end)
    return entries
end
function I:GetBindingRows(plan)
    local rows={}
    for _,action in ipairs((plan or K:PreviewCached()).actions or {}) do if action.kind=="item" then
        local fixed=action.id=="item.trinket13" and 13 or action.id=="item.trinket14" and 14 or nil
        local fallback=action.itemSelectedID or action.itemID
        local equipped=fixed and GetInventoryItemID and GetInventoryItemID("player",fixed)
        local current=fixed and equipped and self:ResolveBinding(action.id,equipped,{selected=equipped}) or (not fixed and self:ResolveBinding(action.id,fallback)) or nil
        local record=(K:GetSettings().itemBindings or {})[action.id] or action.itemBinding or {}
        local alternatives={}; for _,id in ipairs(record.alternatives or {}) do alternatives[#alternatives+1]=self:Resolve(id) end
        local selected=record.selected or fallback; if record.empty then selected=nil end
        rows[#rows+1]={id=action.id,key=action.key,label=action.label,action=action,selected=selected,current=current,alternatives=alternatives,fixedSlot=fixed,targetMode=record.targetMode or "default",modes=fixed and {"default"} or self:GetTargetModes(current)}
    end end
    table.sort(rows,function(a,b) return (a.key or "")<(b.key or "") end)
    return rows
end
function I:CaptureEquipment(name)
    if K.Engine and K.Engine.busy then return false,"Wait for the current operation to finish." end
    if InCombatLockdown and InCombatLockdown() then return false,"Leave combat before saving equipment." end
    local preset=K.db.presets[name or K.db.activePreset]
    if not preset then return false,"Unknown preset." end
    local equipment={}
    for slot=1,19 do
        if slot~=4 and slot~=19 then local id=GetInventoryItemID and GetInventoryItemID("player",slot); if id then equipment[slot]=id end end
    end
    preset.equipment=equipment
    K:InvalidatePreview()
    return true,"Current equipment saved to "..(name or K.db.activePreset).."."
end
function I:EquipPreset(name)
    if K.Engine and K.Engine.busy then return false,"Wait for the current operation to finish." end
    if InCombatLockdown and InCombatLockdown() then return false,"Equipment presets can only be equipped outside combat." end
    local preset=K.db.presets[name or K.db.activePreset]
    if not preset or not next(preset.equipment or {}) then return false,"Save equipment to this preset first." end
    local equip=C_Item and C_Item.EquipItemByName or EquipItemByName
    if not equip then return false,"This client does not expose equipment changes to addons." end
    local missing={}
    for slot,id in pairs(preset.equipment) do
        local current=GetInventoryItemID and GetInventoryItemID("player",slot)
        local count=C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or (GetItemCount and GetItemCount(id)) or 0
        if current~=id and count==0 then missing[#missing+1]=id end
    end
    if #missing>0 then return false,"Some saved equipment is missing. No gear was changed." end
    local success=true
    for slot=1,19 do
        local id=preset.equipment[slot]
        if id and GetInventoryItemID("player",slot)~=id then
            local ok=pcall(equip,id,slot); if not ok then success=false end
        end
    end
    self:Invalidate()
    self:Scan()
    if not success then return false,"The client blocked an equipment change. Check your equipped gear." end
    return true,"Equipment change requested. Check equipment and any equip cooldowns before combat."
end
