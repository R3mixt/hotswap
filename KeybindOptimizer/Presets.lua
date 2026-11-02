local _, K = ...
K.Presets={buttons={}}
local P=K.Presets
local function busy() return K.Engine and K.Engine.busy end
local waitMessage="Wait for the current operation to finish."
local function sorted(map)
    local names={}; for name in pairs(map or {}) do names[#names+1]=name end
    table.sort(names,function(a,b) return a:lower()==b:lower() and a<b or a:lower()<b:lower() end)
    return names
end
local function fill(settings)
    for key in pairs(K.legacySettings or {}) do settings[key]=nil end
    for key,value in pairs(K.defaults) do
        if settings[key]==nil or (type(value)=="table" and type(settings[key])~="table") then settings[key]=K.Copy(value) end
    end
    return settings
end
local function validName(name)
    if type(name)~="string" then return nil,"Enter a preset name." end
    name=name:match("^%s*(.-)%s*$")
    if name=="" or #name>48 or name:find("[%c|]") then return nil,"Use a name of 1–48 characters without control characters or |." end
    return name
end
function P:NewID()
    K.db.nextPresetID=(tonumber(K.db.nextPresetID) or 0)+1
    return "p"..K.db.nextPresetID
end
function P:Initialize()
    local db=K.db
    local original=fill(type(db.settings)=="table" and db.settings or {})
    db.presets=type(db.presets)=="table" and db.presets or {}
    if (tonumber(db.schema) or 0)<2 or not next(db.presets) then
        for _,name in ipairs({"Leveling","Dungeon","PvP"}) do db.presets[name]=db.presets[name] or {items={},equipment={}} end
    end
    local active=db.presets[db.activePreset] and db.activePreset or (db.presets.Leveling and "Leveling" or sorted(db.presets)[1])
    local used={}
    for _,name in ipairs(sorted(db.presets)) do
        local preset=db.presets[name]
        if type(preset)~="table" then preset={}; db.presets[name]=preset end
        preset.items=type(preset.items)=="table" and preset.items or {}
        preset.equipment=type(preset.equipment)=="table" and preset.equipment or {}
        if type(preset.settings)~="table" then
            preset.settings=K.Copy(original)
            if name~=active then preset.settings.mount=preset.items.mount end
        end
        fill(preset.settings)
        if name==active and preset.items.mount==nil and preset.settings.mount then preset.items.mount=preset.settings.mount end
        local serial=type(preset.id)=="string" and tonumber(preset.id:match("^p(%d+)$"))
        if serial then db.nextPresetID=math.max(tonumber(db.nextPresetID) or 0,serial) end
    end
    for _,name in ipairs(sorted(db.presets)) do
        local preset=db.presets[name]
        if type(preset.id)~="string" or not preset.id:match("^p%d+$") or used[preset.id] then preset.id=self:NewID() end
        used[preset.id]=true
    end
    db.activePreset=active
    db.settings=db.presets[active].settings
    if db.enabled and not db.appliedPreset then db.appliedPreset=active end
    db.schema=2
end
function P:List() if not K.db then K:Init() end return sorted(K.db.presets) end
function P:FindID(id)
    for name,preset in pairs(K.db.presets) do if preset.id==id then return name,preset end end
end
function P:Changed()
    K.dirty=true; K:InvalidatePreview()
    if K.QueueRefresh then K:QueueRefresh() end
end
local function signature(value)
    if type(value)~="table" then local text=tostring(value); return type(value)..":"..#text..":"..text end
    local keys={}; for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local parts={"{"}; for _,key in ipairs(keys) do parts[#parts+1]=signature(key); parts[#parts+1]=signature(value[key]) end
    parts[#parts+1]="}"; return table.concat(parts)
end
function P:Signature(name)
    local preset=K.db.presets[name]; if not preset then return end
    local hotkeys={}; for _,entry in pairs(K.db.presets) do if entry.hotkey then hotkeys[entry.id]=entry.hotkey end end
    return signature({settings=preset.settings,items=preset.items,hotkeys=hotkeys})
end
function P:HasUnappliedChanges()
    local db=K.db
    if not db or not db.enabled or not db.appliedPlan then return true end
    if db.activePreset~=db.appliedPreset then return true end
    local current=self:Signature(db.activePreset)
    return not current or not db.appliedPresetSignature or current~=db.appliedPresetSignature
end
function P:Select(name)
    if busy() then return false,waitMessage end
    if not K.db then K:Init() end
    local preset=K.db.presets[name]
    if not preset then return false,"Unknown preset." end
    local previous=K.db.presets[K.db.activePreset]
    if previous then previous.settings=K.db.settings end
    K.db.activePreset=name; K.db.settings=preset.settings
    self:Changed()
    return true,"Editing draft: "..name..". Apply & save activates it."
end
function P:Create(name,copyCurrent)
    if busy() then return false,waitMessage end
    if not K.db then K:Init() end
    local clean,why=validName(name); if not clean then return false,why end
    if K.db.presets[clean] then return false,"A preset with that name already exists." end
    local source=K.db.presets[K.db.activePreset]
    local preset=copyCurrent~=false and K.Copy(source) or {settings=K.Copy(K.defaults),items={},equipment={}}
    preset.id=self:NewID(); preset.hotkey=nil
    K.db.presets[clean]=preset
    self:Select(clean)
    return true,"Created "..clean..". Changes are saved to this preset as you edit."
end
function P:Rename(old,new)
    if busy() then return false,waitMessage end
    local preset=K.db.presets[old]; if not preset then return false,"Unknown preset." end
    local clean,why=validName(new); if not clean then return false,why end
    if clean==old then return true,"Preset name is unchanged." end
    if K.db.presets[clean] then return false,"A preset with that name already exists." end
    K.db.presets[old]=nil; K.db.presets[clean]=preset
    if K.db.activePreset==old then K.db.activePreset=clean end
    if K.db.appliedPreset==old then K.db.appliedPreset=clean end
    self:Changed()
    return true,"Renamed preset to "..clean.."."
end
function P:Delete(name)
    if busy() then return false,waitMessage end
    if not K.db.presets[name] then return false,"Unknown preset." end
    if #self:List()==1 then return false,"Keep at least one preset." end
    if name==K.db.appliedPreset and K.db.enabled then return false,"Use another preset before deleting the active preset." end
    K.db.presets[name]=nil
    if K.db.activePreset==name then
        local nextName=self:List()[1]; K.db.activePreset=nextName; K.db.settings=K.db.presets[nextName].settings
    end
    self:Changed()
    return true,"Deleted "..name..". Use your current preset to update its hotkeys."
end
function P:Actions()
    local actions={}
    for _,name in ipairs(self:List()) do
        local preset=K.db.presets[name]
        if preset.hotkey then actions[#actions+1]={id="mode."..preset.id,presetID=preset.id,presetName=name,kind="system",category="Preset",label="Apply preset: "..name,command="CLICK KBO_Mode_"..preset.id..":LeftButton",key=preset.hotkey,known=true,form="all"} end
    end
    return actions
end
function P:ValidateHotkeys(currentPlan)
    local modes,keys={},{}
    for _,name in ipairs(self:List()) do
        local key=K.db.presets[name].hotkey
        if key then
            local normalized=K.API:NormalizeKey(key)
            if not normalized or normalized~=key or key:find("ALT%-") or key:match("BUTTON[12]$") then return false,"Invalid preset hotkey for "..name..". Alt stays reserved for self-cast." end
            if keys[key] then return false,key.." is already the hotkey for "..keys[key].."." end
            keys[key]=name; modes[#modes+1]={name=name,key=key}
        end
    end
    if #modes==0 then return true end
    -- Applying one preset validates its actual plan. Inactive drafts are
    -- checked when selected; rebuilding every saved class layout here makes
    -- installation time grow with the number of named presets.
    if currentPlan then
        for key in pairs(keys) do if (currentPlan.protectedKeys or {})[key] then return false,key.." is protected by this preset's control settings. Choose another preset hotkey." end end
        for _,action in ipairs(currentPlan.actions or {}) do
            if not tostring(action.id):match("^mode%.") then
                local key=keys[action.key] and action.key or (action.selfKey and keys[action.selfKey] and action.selfKey)
                if key then return false,key.." is used by "..(action.label or action.id).." and preset "..keys[key].."." end
            end
        end
        return true
    end
    local previousName,previousSettings=K.db.activePreset,K.db.settings
    local ok,why=pcall(function()
        for _,name in ipairs(self:List()) do
            K.db.activePreset=name; K.db.settings=K.db.presets[name].settings
            local plan=name==previousName and currentPlan or K.Planner:Build(true)
            if not plan then plan=K.Planner:Build(true) end
            for _,mode in ipairs(modes) do if (plan.protectedKeys or {})[mode.key] then error(mode.key.." is a protected control in "..name..". Choose another preset hotkey.",0) end end
            for _,action in ipairs(plan.actions or {}) do
                if not tostring(action.id):match("^mode%.") then
                    for _,mode in ipairs(modes) do
                        if action.key==mode.key or action.selfKey==mode.key then error(mode.key.." is used by "..(action.label or action.id).." in "..name..". Choose a free preset hotkey.",0) end
                    end
                end
            end
        end
    end)
    K.db.activePreset,K.db.settings=previousName,previousSettings
    if not ok then return false,tostring(why) end
    return true
end
function P:SetHotkey(name,key)
    if busy() then return false,waitMessage end
    local preset=K.db.presets[name]; if not preset then return false,"Unknown preset." end
    if key=="" then key=nil end
    if key then key=K.API:NormalizeKey(key); if not key then return false,"Choose a valid preset hotkey." end end
    if key and ({W=true,A=true,S=true,D=true,SPACE=true,TAB=true,ENTER=true,ESCAPE=true})[key] then return false,"That key is reserved for movement, chat, or targeting." end
    -- Check the existing plans before reserving a new mode key. Otherwise a
    -- fallback spell could silently be moved to make room for this hotkey.
    if key and key~=preset.hotkey then
        local previousName,previousSettings=K.db.activePreset,K.db.settings
        local checked,why=pcall(function()
            for _,otherName in ipairs(self:List()) do
                K.db.activePreset=otherName; K.db.settings=K.db.presets[otherName].settings
                local plan=K.Planner:Build(true)
                if (plan.protectedKeys or {})[key] then error(key.." is a protected control in "..otherName..". Choose another preset hotkey.",0) end
                for _,action in ipairs(plan.actions or {}) do
                    if action.id~="mode."..preset.id and (action.key==key or action.selfKey==key) then error(key.." is used by "..(action.label or action.id).." in "..otherName..".",0) end
                end
            end
        end)
        K.db.activePreset,K.db.settings=previousName,previousSettings
        if not checked then return false,tostring(why) end
    end
    local old=preset.hotkey; preset.hotkey=key
    local ok,why=self:ValidateHotkeys()
    if not ok then preset.hotkey=old; return false,why end
    self:Changed()
    return true,key and ("Preset hotkey saved. Apply & save enables "..key..".") or "Preset hotkey cleared. Apply & save updates game bindings."
end
function P:ClearHotkey(name) return self:SetHotkey(name,nil) end
function P:EnsureButtons()
    if InCombatLockdown and InCombatLockdown() then return false,"Preset switching is unavailable during combat." end
    for _,name in ipairs(self:List()) do
        local id=K.db.presets[name].id
        if not self.buttons[id] then
            local button=CreateFrame("Button","KBO_Mode_"..id,UIParent)
            button:SetSize(1,1); button:SetAlpha(0); button:EnableMouse(false)
            button:RegisterForClicks("LeftButtonUp")
            button:SetScript("OnClick",function(owner)
                local now=GetTime and GetTime() or 0
                if owner.lastClick and now-owner.lastClick<0.3 then return end
                owner.lastClick=now
                local ok,why=P:ActivateByID(id); if why then K:Print(why) end
            end)
            self.buttons[id]=button
        end
        self.buttons[id]:Show()
    end
    return true
end
function P:Activate(name)
    if busy() then return false,waitMessage end
    if InCombatLockdown and InCombatLockdown() then return false,"Leave combat before using a preset." end
    if self.activating then return false,"A preset switch is already in progress." end
    if not K.db.presets[name] then return false,"Unknown preset." end
    local _,class=UnitClass("player")
    if K.db.presets[name].sourceClass and K.db.presets[name].sourceClass~=class then return false,"This preset is for "..K.db.presets[name].sourceClass..", not "..class.."." end
    if K.db.enabled and K.db.appliedPreset==name and not K.dirty and K.db.appliedPresetSignature==self:Signature(name) then return true,name.." is already active." end
    self.pendingActivation={name=K.db.activePreset,settings=K.db.settings,dirty=K.dirty,plan=K.plan,valid=K.previewValid}
    self.activating=true
    self:Select(name)
    local called,ok,why=pcall(K.Apply,K)
    if not called then
        ok,why=false,ok
        if K.Diagnostics then pcall(K.Diagnostics.Record,K.Diagnostics,"error","preset-error",tostring(why),{operation="apply",stage="Preparing preset"}) end
    end
    if ok=="pending" then return ok,why end
    self:OnActivationComplete(ok,why)
    if not ok then return false,tostring(why or "Preset could not be activated.") end
    if K.QueueRefresh then K:QueueRefresh() end
    return true,"Using "..name.."."
end
function P:OnActivationComplete(ok)
    local previous=self.pendingActivation
    self.pendingActivation=nil; self.activating=nil
    if previous and not ok then
        K.db.activePreset,K.db.settings=previous.name,previous.settings
        -- The engine restores copied tables before reporting a failed install.
        -- Reattach the original editing draft to its preset after that rollback.
        if K.db.presets[previous.name] then K.db.presets[previous.name].settings=previous.settings end
        K.dirty,K.plan,K.previewValid=previous.dirty,previous.plan,previous.valid
    end
    if K.QueueRefresh then K:QueueRefresh() end
end
local function recommendation()
    local _,class=UnitClass("player")
    local source=K.db.presets[K.db.activePreset]
    local preset={settings=K.Copy(K:GetSettings()),items=K.Copy(source.items or {}),equipment=K.Copy(source.equipment or {}),sourceClass=class}
    for _,key in ipairs({"bindingOverrides","fallbackBindings","actionOverrides","customActions"}) do preset.settings[key]={} end
    return preset
end
function P:PreviewRecommendations()
    if busy() or self.activating then return false,waitMessage end
    if not K.db then K:Init() end
    local preset=recommendation()
    -- The planner's existing collaborators read the selected preset. Give
    -- them a detached view for this synchronous, read-only build, then restore
    -- it even on failure. Never insert a draft or consume a preset ID here.
    -- A shallow DB copy intentionally avoids copying potentially large backup
    -- history; only the preset map and selected configuration are substituted.
    local savedDB,savedPlan,savedValid,savedRevision,savedClass,savedDirty=K.db,K.plan,K.previewValid,K.previewRevision,K.playerClass,K.dirty
    local view={}; for key,value in pairs(savedDB) do view[key]=value end
    view.presets={}; for name,value in pairs(savedDB.presets) do view.presets[name]=value end
    local previewSelected=K.Copy(preset)
    local selected=savedDB.presets[savedDB.activePreset]
    previewSelected.id,previewSelected.hotkey=selected.id,selected.hotkey
    view.presets[view.activePreset]=previewSelected; view.settings=previewSelected.settings
    K.db=view
    local ok,plan=pcall(K.Planner.Build,K.Planner,true)
    K.db,K.plan,K.previewValid,K.previewRevision,K.playerClass,K.dirty=savedDB,savedPlan,savedValid,savedRevision,savedClass,savedDirty
    if not ok then return false,tostring(plan) end
    plan.recommendation=true; plan.presetName=nil; plan.presetID=nil
    return plan,preset
end
function P:CreateRecommended(name,snapshot)
    if busy() or self.activating then return false,waitMessage end
    if not K.db then K:Init() end
    local className,class=UnitClass("player")
    local base,why=validName(name or ("Recommended "..(className or class or "preset")))
    if not base then return false,why end
    if snapshot and (type(snapshot)~="table" or type(snapshot.settings)~="table" or snapshot.sourceClass~=class) then
        return false,"Preview recommendations for this character before saving them."
    end
    local target=base; local suffix=2
    while K.db.presets[target] do local tail=" ("..suffix..")"; target=base:sub(1,48-#tail)..tail; suffix=suffix+1 end
    local preset=K.Copy(snapshot or recommendation())
    preset.id=self:NewID(); preset.hotkey=nil; preset.sourceClass=class
    K.db.presets[target]=preset
    self:Select(target)
    return true,"Saved "..target.." as a draft. No game bindings changed. Apply & save installs it.",target
end
-- Compatibility entry point: recommendation generation no longer installs
-- anything. Every caller must explicitly activate a saved draft to apply it.
function P:Optimize(name) return self:CreateRecommended(name) end
function P:ActivateByID(id)
    local name=self:FindID(id)
    if not name then return false,"That preset no longer exists. Use your current preset to update its hotkeys." end
    return self:Activate(name)
end
function P:Apply(id) return self:ActivateByID(id) end
function P:SnapshotState()
    return {presets=K.Copy(K.db.presets),activePreset=K.db.activePreset,appliedPreset=K.db.appliedPreset,settings=K.Copy(K.db.settings),nextPresetID=K.db.nextPresetID,appliedPresetSignature=K.db.appliedPresetSignature}
end
function P:RestoreState(state)
    if type(state)~="table" then return end
    local renamed={}
    for _,name in ipairs(sorted(state.presets or {})) do
        local saved=state.presets[name]
        local existing=self:FindID(saved.id)
        if existing then K.db.presets[existing]=nil end
        local target=name; local suffix=1
        while K.db.presets[target] do
            local tail=" (restored "..suffix..")"; target=name:sub(1,48-#tail)..tail; suffix=suffix+1
        end
        K.db.presets[target]=K.Copy(saved); renamed[name]=target
    end
    K.db.nextPresetID=math.max(tonumber(K.db.nextPresetID) or 0,tonumber(state.nextPresetID) or 0)
    K.db.activePreset=renamed[state.activePreset] or (K.db.presets[state.activePreset] and state.activePreset) or self:List()[1]
    K.db.appliedPreset=renamed[state.appliedPreset] or state.appliedPreset
    K.db.appliedPresetSignature=state.appliedPresetSignature
    local selected=K.db.presets[K.db.activePreset]
    if state.settings then selected.settings=fill(K.Copy(state.settings)) end
    K.db.settings=selected.settings
    K:InvalidatePreview()
end
P.ValidName=validName

-- Preset interchange contains typed data only. No Lua parser or executable
-- action bodies are accepted; macros are rebuilt from the local catalog.
local function encode(value)
    return tostring(value):gsub("([^%w%._%-%s])",function(c) return string.format("%%%02X",string.byte(c)) end):gsub("\n","%%0A"):gsub("\r","%%0D"):gsub("\t","%%09")
end
local function decode(value) return (value:gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)) end
local function addLine(lines,...)
    local values={...}; for i,value in ipairs(values) do values[i]=encode(value) end
    lines[#lines+1]=table.concat(values,"\t")
end
function P:Export(name)
    if not K.db then K:Init() end
    if name and not K.db.presets[name] then return nil,"Unknown preset." end
    K.db.presets[K.db.activePreset].settings=K.db.settings
    local _,class=UnitClass("player")
    local lines={"KBO2"}; addLine(lines,"c",class)
    local names=name and {name} or self:List()
    for _,presetName in ipairs(names) do
        local preset=K.db.presets[presetName]
        addLine(lines,"n",presetName)
        local keys=sorted(K.defaults); keys[#keys+1]="mount"
        for _,key in ipairs(keys) do
            local value=preset.settings[key]
            if type(value)=="boolean" or type(value)=="string" or type(value)=="number" then addLine(lines,"s",presetName,key,type(value),value) end
        end
        for _,key in ipairs(sorted(preset.settings.mouseButtons)) do if preset.settings.mouseButtons[key] then addLine(lines,"m",presetName,key) end end
        local validBars,barError=K:ValidateNativeBars(preset.settings.nativeBars or {})
        if not validBars then return nil,barError end
        for toggle=1,7 do
            local shown=(preset.settings.nativeBars or {})[toggle]
            if shown~=nil then addLine(lines,"v",presetName,toggle,shown) end
        end
        for _,pair in ipairs({{"b","bindingOverrides"},{"f","fallbackBindings"}}) do
            for _,id in ipairs(sorted(preset.settings[pair[2]])) do addLine(lines,pair[1],presetName,id,preset.settings[pair[2]][id]) end
        end
        -- o = scalar rank/target override; r = replacement descriptor retaining
        -- the destination's identity/page/key; u = extra global action. These
        -- are typed data fields, never Lua or imported macro bodies.
        for _,id in ipairs(sorted(preset.settings.actionOverrides)) do
            for _,field in ipairs(sorted(preset.settings.actionOverrides[id])) do
                if field=="replacement" then
                    for _,part in ipairs(sorted(preset.settings.actionOverrides[id].replacement)) do addLine(lines,"r",presetName,id,part,preset.settings.actionOverrides[id].replacement[part]) end
                else addLine(lines,"o",presetName,id,field,preset.settings.actionOverrides[id][field]) end
            end
        end
        for _,id in ipairs(sorted(preset.settings.customActions)) do
            for _,field in ipairs(sorted(preset.settings.customActions[id])) do addLine(lines,"u",presetName,id,field,preset.settings.customActions[id][field]) end
        end
        local validChoices,choiceError=K.TalentBindings:ValidateSettings(preset.settings)
        if not validChoices then return nil,choiceError end
        for _,id in ipairs(sorted(preset.settings.talentAlternatives)) do
            for _,sourceID in ipairs(preset.settings.talentAlternatives[id]) do addLine(lines,"t",presetName,id,sourceID) end
        end
        for _,id in ipairs(sorted(preset.settings.itemBindings)) do
            local binding=preset.settings.itemBindings[id]
            if binding.selected then addLine(lines,"i",presetName,id,"selected",binding.selected) end
            if binding.targetMode then addLine(lines,"i",presetName,id,"targetMode",binding.targetMode) end
            if binding.empty then addLine(lines,"i",presetName,id,"empty","true") end
            for _,itemID in ipairs(binding.alternatives or {}) do addLine(lines,"i",presetName,id,"alternative",itemID) end
        end
        for _,slot in ipairs(sorted(preset.items)) do addLine(lines,"p",presetName,slot,preset.items[slot]) end
        for slot=1,19 do if preset.equipment[slot] then addLine(lines,"e",presetName,slot,preset.equipment[slot]) end end
        if preset.hotkey then addLine(lines,"h",presetName,preset.hotkey) end
    end
    addLine(lines,"a",name or K.db.activePreset)
    return table.concat(lines,"\n")
end
local function setSetting(settings,key,typ,value)
    if K.legacySettings[key] then return K:ValidLegacySetting(key,typ,value) end
    if K.defaults[key]==nil and key~="mount" then return false end
    if typ=="boolean" and type(K.defaults[key])=="boolean" and (value=="true" or value=="false") then settings[key]=value=="true"
    elseif typ=="number" and (type(K.defaults[key])=="number" or key=="mount") and tonumber(value) then
        local n=tonumber(value)
        if n~=n or n==math.huge or n==-math.huge or (key=="mount" and (n<1 or n%1~=0)) then return false end
        settings[key]=n
    elseif typ=="string" and key=="mount" and value:match("^spell:%d+$") and tonumber(value:sub(7))>0 then settings[key]=value
    elseif typ=="string" and type(K.defaults[key])=="string" and #value<=40 then settings[key]=value
    else return false end
    return true
end
local function validateSettings(settings)
    local validChoices,choiceError=K.TalentBindings:ValidateSettings(settings)
    if not validChoices then return false,choiceError end
    local validBars,barError=K:ValidateNativeBars(settings.nativeBars or {})
    if not validBars then return false,barError end
    if K.Library then local ok,why=K.Library:CheckLimits(settings); if not ok then return false,why end end
    if not ({auto=true,forever=true,era=true,retail=true})[settings.flavor] then return false,"Unknown game version." end
    if not ({frost=true,fire=true})[settings.primarySchool] then return false,"Unknown mage school." end
    for id,override in pairs(settings.actionOverrides or {}) do if not K.Library or not K.Library:ValidateOverride(override) then return false,"Invalid action override: "..id end end
    for id,descriptor in pairs(settings.customActions or {}) do local ok,why=K.Library and K.Library:ValidateDescriptor(descriptor); if not ok then return false,why or ("Invalid custom action: "..id) end end
    for id,binding in pairs(settings.itemBindings or {}) do
        local ok,why=K.Items.ValidateBinding and K.Items:ValidateBinding(binding); if not ok then return false,why or ("Invalid item binding: "..id) end
        if id~="item.mount" then
            if type(binding.selected)=="string" then return false,"Spell mounts belong on the mount binding." end
            for _,itemID in ipairs(binding.alternatives or {}) do if type(itemID)=="string" then return false,"Spell mounts belong on the mount binding." end end
        end
    end
    return true
end
function P:MergeImport(incoming,active,sourceClass)
    if busy() then return false,waitMessage end
    if not K.db then K:Init() end
    local _,class=UnitClass("player")
    if sourceClass and sourceClass~=class then return false,"This export is for "..sourceClass..". Import it on a "..sourceClass.." character; this character is "..class.."." end
    local names=sorted(incoming)
    if #names==0 then return false,"The export contains no presets." end
    local mapped={}; local hotkeys={}
    for _,preset in pairs(K.db.presets) do if preset.hotkey then hotkeys[preset.hotkey]=true end end
    local cleared=0
    for _,name in ipairs(names) do
        local target=name; local suffix=2
        while K.db.presets[target] do
            local tail=" ("..suffix..")"; target=name:sub(1,48-#tail)..tail; suffix=suffix+1
        end
        local preset=K.Copy(incoming[name])
        preset.id=self:NewID(); preset.sourceClass=sourceClass or class
        if preset.hotkey and hotkeys[preset.hotkey] then preset.hotkey=nil; cleared=cleared+1 end
        if preset.hotkey then hotkeys[preset.hotkey]=true end
        K.db.presets[target]=preset; mapped[name]=target
    end
    self:Select(mapped[active] or mapped[names[1]])
    return true,"Imported "..#names.." preset(s). Editing "..K.db.activePreset.."; your active setup is unchanged."..(cleared>0 and (" "..cleared.." duplicate preset hotkey(s) were left unassigned.") or "")
end
function P:Import(text)
    if busy() then return false,waitMessage end
    if type(text)~="string" or #text>2000000 then return false,"Invalid or oversized preset export (maximum 2 MB)." end
    text=text:gsub("\r","")
    if text:match("^([^\n]+)")~="KBO2" then return false,"This is not a Hot Swap preset export." end
    local presets,active,class={},nil,nil
    local count=0
    for line in text:gmatch("[^\n]+") do
        count=count+1
        if count>50000 then return false,"The export contains too many data entries." end
        if count>1 then
            local fields={}; for value in (line.."\t"):gmatch("(.-)\t") do fields[#fields+1]=decode(value) end
            local tag,name=fields[1],fields[2]
            local preset=presets[name]
            if tag=="c" and #fields==2 and name:match("^[A-Z]+$") and #name<=20 and not class then class=name
            elseif tag=="n" and #fields==2 and validName(name)==name and not preset then
                local settings=K.Copy(K.defaults); settings.mouseButtons={}
                presets[name]={settings=settings,items={},equipment={}}
            elseif tag=="s" and #fields==5 and preset then
                if not setSetting(preset.settings,fields[3],fields[4],fields[5]) then return false,"Invalid setting on line "..count.."." end
            elseif tag=="m" and #fields==3 and preset and fields[3]:match("^BUTTON%d+$") then
                local n=tonumber(fields[3]:match("%d+")); if n<4 or n>31 then return false,"Invalid mouse button." end
                preset.settings.mouseButtons[fields[3]]=true
            elseif tag=="v" and #fields==4 and preset then
                local toggle=fields[3]:match("^[1-7]$") and tonumber(fields[3])
                if not toggle or (fields[4]~="true" and fields[4]~="false") or preset.settings.nativeBars[toggle]~=nil then
                    return false,"Invalid or duplicate action-bar preference on line "..count.."."
                end
                preset.settings.nativeBars[toggle]=fields[4]=="true"
            elseif (tag=="b" or tag=="f") and #fields==4 and preset and #fields[3]<=100 and fields[3]:match("^[%w%._%-]+$") and not fields[3]:match("^mode%.") then
                local key=K.API:NormalizeKey(fields[4]); if not key then return false,"Invalid binding on line "..count.."." end
                preset.settings[tag=="b" and "bindingOverrides" or "fallbackBindings"][fields[3]]=key
            elseif (tag=="o" or tag=="u" or tag=="r") and #fields==5 and preset and #fields[3]<=100 and fields[3]:match("^[%w%._%-]+$") and not fields[3]:match("^mode%.") then
                local id,field,value=fields[3],fields[4],fields[5]
                if tag=="u" and not id:match("^custom%.") then return false,"Invalid custom action ID." end
                local map=tag=="u" and preset.settings.customActions or preset.settings.actionOverrides
                map[id]=map[id] or {}; local entry=map[id]
                if tag=="r" then entry.replacement=entry.replacement or {}; entry=entry.replacement end
                if entry[field]~=nil then return false,"Duplicate action field." end
                if field=="spellID" or field=="itemID" then value=tonumber(value); if not value then return false,"Invalid action ID." end end
                entry[field]=value
            elseif tag=="t" and #fields==4 and preset and #fields[3]<=100 and #fields[4]<=100 then
                local choices=preset.settings.talentAlternatives
                choices[fields[3]]=choices[fields[3]] or {}
                local list=choices[fields[3]]
                if #list>=8 then return false,"A shared key supports at most eight talent choices." end
                list[#list+1]=fields[4]
            elseif tag=="i" and #fields==5 and preset and #fields[3]<=100 and fields[3]:match("^[%w%._%-]+$") and not fields[3]:match("^mode%.") then
                local id,field,value=fields[3],fields[4],fields[5]
                local map=preset.settings.itemBindings; map[id]=map[id] or {alternatives={}}
                if field=="alternative" then local itemID=value:match("^spell:%d+$") and value or tonumber(value); if not itemID then return false,"Invalid alternative item ID." end; map[id].alternatives[#map[id].alternatives+1]=itemID
                elseif field=="empty" and value=="true" and map[id].empty==nil then map[id].empty=true
                elseif (field=="selected" or field=="targetMode") and map[id][field]==nil then
                    if field=="selected" then value=value:match("^spell:%d+$") and value or tonumber(value); if not value then return false,"Invalid selected item ID." end end
                    map[id][field]=value
                else return false,"Invalid item binding field." end
            elseif (tag=="p" or tag=="e") and #fields==4 and preset then
                local id=tonumber(fields[4])
                if tag=="p" and fields[3]=="mount" and fields[4]:match("^spell:%d+$") and tonumber(fields[4]:sub(7))>0 then id=fields[4]
                elseif not id or id<1 or id%1~=0 or id==math.huge then return false,"Invalid item ID." end
                if tag=="p" then
                    if not ({utility=true,potion=true,healthstone=true,mount=true})[fields[3]] then return false,"Invalid item slot." end
                    preset.items[fields[3]]=id
                else
                    local slot=tonumber(fields[3]); if not slot or slot<1 or slot>19 or slot%1~=0 then return false,"Invalid equipment slot." end
                    preset.equipment[slot]=id
                end
            elseif tag=="h" and #fields==3 and preset then
                local key=K.API:NormalizeKey(fields[3]); if not key or key:find("ALT%-") or key:match("BUTTON[12]$") then return false,"Invalid preset hotkey." end
                preset.hotkey=key
            elseif tag=="a" and #fields==2 and preset then active=name
            else return false,"Malformed preset entry on line "..count.."." end
        end
    end
    if not class then return false,"This export has no class information." end
    for _,preset in pairs(presets) do local ok,why=validateSettings(preset.settings); if not ok then return false,why end end
    return self:MergeImport(presets,active,class)
end
