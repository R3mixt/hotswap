local addonName, K = ...
_G.KeybindOptimizer = K
K.name, K.version = addonName or "KeybindOptimizer", "0.4.9"
K.defaults = {
    wheel = true, middle = true, ctrl = true,
    mouseButtons = { BUTTON4 = true, BUTTON5 = true },
    selfFallback = false, cancelForUtility = true,
    flavor = "auto", primarySchool = "frost", groundAtCursor=false,
    preserveMovement=false, preserveCamera=false, preserveChat=false,
    preserveInterface=false, preserveTargeting=false, preserveGameSettings=false,
    hideUnavailableSpells=false, adaptTalents=false,
    allowAccountMacros=false,
    talentAlternatives={},
    bindingOverrides = {}, fallbackBindings = {}, actionOverrides = {}, customActions = {}, itemBindings = {}, nativeBars = {},
}
-- Read-only migration shim for exports made by the retired custom action dock.
-- These values are accepted and discarded, never applied to native bars.
K.legacySettings={showBars="boolean",prowlPage="boolean",barScale="number"}
function K:ValidLegacySetting(key,typ,value)
    if self.legacySettings[key]~=typ then return false end
    if typ=="boolean" then return value=="true" or value=="false" end
    local number=tonumber(value); return number and number>=0.65 and number<=1.5 or false
end
function K.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, v in pairs(value) do result[key] = K.Copy(v) end
    return result
end
local function defaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then target[key] = K.Copy(value)
        elseif type(value) == "table" and type(target[key]) ~= "table" then target[key] = K.Copy(value) end
    end
end
function K:Init()
    if type(KeybindOptimizerDB) ~= "table" then KeybindOptimizerDB = {} end
    self.db = KeybindOptimizerDB
    -- Device-local preferences never travel with a shared binding preset.
    self.db.preferences=type(self.db.preferences)=="table" and self.db.preferences or {}
    local preferences=self.db.preferences
    preferences.diagnostics=preferences.diagnostics==true
    for _,key in ipairs({"showMacroNames","showMacroCode","showUnavailableBindings"}) do
        if type(preferences[key])~="boolean" then preferences[key]=true end
    end
    for key,range in pairs({windowOpacity={0.4,1},windowScale={0.7,1.3}}) do
        local value=preferences[key]
        if type(value)~="number" or value~=value then value=1 end
        preferences[key]=math.max(range[1],math.min(range[2],value))
    end
    self.db.settings = type(self.db.settings)=="table" and self.db.settings or {}
    defaults(self.db.settings, self.defaults)
    self.Presets:Initialize()
    local _,class=UnitClass("player")
    if self.db.appliedPlan and self.db.appliedPlan.class and self.db.appliedPlan.class~=class then
        -- Preserve the old record for recovery, but never activate or maintain
        -- another class's installed layout on this character.
        self.db.enabled=false
        self.db.recoveryRequired=nil
        self.db.characterSetupNotice="A saved layout for another class was disabled. Your current controls are unchanged."
    end
    self.db.ownedMacros = self.db.ownedMacros or {}
    self.db.history = self.db.history or {}
    if self.CurrentBindings then self.CurrentBindings:Initialize() end
    self.dirty=self.Presets:HasUnappliedChanges()
    if self.Diagnostics then self.Diagnostics:Init() end
end
function K:GetSettings() if not self.db then self:Init() end return self.db.settings end
function K:Print(message)
    local text = "|cffffd100Hot Swap|r  " .. tostring(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text) elseif print then print(text) end
end
function K:ValidateNativeBars(value)
    if type(value)~="table" then return false,"Action-bar preferences must be a table." end
    for toggle,shown in pairs(value) do
        if type(toggle)~="number" or toggle<1 or toggle>7 or toggle%1~=0 or type(shown)~="boolean" then
            return false,"Action-bar preferences must use bar numbers 1 through 7 and true or false."
        end
    end
    return true
end
function K:UpdateSetting(key, value)
    if value==nil then
        if self.Engine and self.Engine.busy then return false,"Wait for the current operation to finish." end
        if key=="nativeBars" then return false,"Action-bar preferences must be a table." end
        self:GetSettings()[key]=nil; self.dirty=true; self:InvalidatePreview()
        return self:PreviewCached()
    end
    return self:UpdateSettings({[key]=value})
end
function K:UpdateSettings(values)
    if self.Engine and self.Engine.busy then return false,"Wait for the current operation to finish." end
    if values.nativeBars~=nil then local ok,why=self:ValidateNativeBars(values.nativeBars); if not ok then return false,why end end
    local settings=self:GetSettings()
    for key,value in pairs(values) do settings[key]=K.Copy(value) end
    self.dirty = true
    self:InvalidatePreview()
    return self:PreviewCached()
end
function K:InvalidatePreview()
    self.previewValid=false
    self.previewRevision=(self.previewRevision or 0)+1
end
function K:Preview()
    if not self.db then self:Init() end
    local revision=self.previewRevision
    self.plan = self.Planner:Build()
    self.previewValid=revision==self.previewRevision
    return self.plan
end
-- Rendering and keyboard modifiers reuse the reviewed plan. Explicit Preview
-- and Apply retain a fresh scan/preflight, even when a cached view is available.
function K:PreviewCached()
    if not self.db then self:Init() end
    if not self.previewValid or not self.plan then
        local revision=self.previewRevision
        self.plan=self.Planner:Build(true)
        self.previewValid=revision==self.previewRevision
    end
    return self.plan
end
function K:QueueRefresh()
    if not self.events or self.refreshQueued then return end
    self.refreshQueued=true
    local elapsed=0
    self.events:SetScript("OnUpdate",function(frame,delta)
        elapsed=elapsed+delta
        if elapsed<0.15 then return end
        frame:SetScript("OnUpdate",nil)
        K.refreshQueued=false
        if K.UI and K.UI.frame and K.UI.frame:IsShown() then K.UI:Refresh() end
    end)
end
function K:Apply()
    if self.Engine and self.Engine.busy then return false,"Wait for the current operation to finish." end
    if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before applying changes." end
    local plan=self:Preview()
    local valid,why=self.Presets:ValidateHotkeys(plan)
    if not valid then return self.Engine:Reject(why) end
    local ok, message = self.Engine:Apply(plan)
    if ok==true then self.dirty = false; self.db.appliedPreset=self.db.activePreset; self.db.appliedPresetSignature=self.Presets:Signature(self.db.activePreset) end
    self:InvalidatePreview()
    return ok, message
end
function K:OnApplyComplete(ok,message,plan,kind)
    kind=kind or "apply"
    if ok and (kind=="apply" or kind=="restore") then self.db.recoveryRequired=nil; self.recoveryQuarantined=nil end
    if kind=="apply" and ok then
        local name=plan and plan.presetID and self.Presets:FindID(plan.presetID) or (plan and plan.presetName) or self.db.activePreset
        self.db.appliedPreset=name
        self.db.presetSaveBases=self.db.presetSaveBases or {}
        local saved=self.db.presets[name]
        if saved then self.db.presetSaveBases[saved.id]=K.Copy(saved) end
        self.db.appliedPresetSignature=self.Presets:Signature(name)
        self.dirty=self.Presets:HasUnappliedChanges()
    end
    if kind=="apply" then self.Presets:OnActivationComplete(ok,message) end
    if kind=="maintenance" then
        if ok then self:RefreshAvailabilityStatus()
        else self.dirty=true; self.needsRefresh=true end
    end
    if ok and self.NativeBars.ApplyMacroTextPreference then self.NativeBars:ApplyMacroTextPreference() end
    self:InvalidatePreview()
    if self.UI and self.UI.OnOperationComplete then self.UI:OnOperationComplete(ok,message,kind)
    elseif message then self:Print(message) end
    self:QueueRefresh()
    if kind=="maintenance" and not ok and self.db.enabled and self.db.appliedPlan and self.db.appliedPlan.formSignature~=self.API:FormSignature() then
        self.pendingSpellMaintenance=nil
        self:RequireRecovery(message)
        return
    end
    if self.pendingSpellMaintenance then self:MaintainLearnedActions() end
    if self.pendingItemMaintenance then self:MaintainItemBindings() end
    if self.pendingMouseRepair then self:MaintainMouseControls() end
end
function K:MaintainMouseControls()
    if not self.db or not self.db.enabled or not self.db.appliedPlan then self.pendingMouseRepair=nil; return end
    if self.db.appliedPlan.mouseBindingsVersion==1 then self.pendingMouseRepair=nil; return end
    if self.Engine.busy or (InCombatLockdown and InCombatLockdown()) then self.pendingMouseRepair=true; return end
    self.pendingMouseRepair=nil
    local ok,why=self.Engine:RepairMouseControls()
    if not ok and why then self:Print(why) end
end
function K:OnRestoreComplete(ok,message,plan,kind) return self:OnApplyComplete(ok,message,plan,kind or "restore") end
function K:RefreshAvailabilityStatus()
    local plan=self.db and self.db.enabled and self.db.appliedPlan
    if not plan then return end
    local automatic=self.AvailabilityEngine:Handles(plan) or self.AvailabilityEngine:HasTalentActions(plan)
    if not automatic then return end
    self.needsRefresh=self.AvailabilityEngine:HasUnboundLearnedSpells(plan)
    self.dirty=self.Presets:HasUnappliedChanges() or self.needsRefresh
end
function K:RequireRecovery(reason)
    self.db.recoveryRequired=tostring(reason or "The installed layout needs review.")
    self.pendingSpellMaintenance=nil; self.pendingItemMaintenance=nil
    self.dirty=true; self.needsRefresh=true
    if InCombatLockdown and InCombatLockdown() then return end
    if self.recoveryQuarantined or self.Engine.busy then return end
    local ok,why=self.Engine:QuarantineForms()
    if not ok then self:Print(why) end

end
function K:MaintainLearnedActions()
    if self.db and self.db.recoveryRequired then self:RequireRecovery(self.db.recoveryRequired); return end
    if not self.db or not self.db.enabled or not self.db.appliedPlan then self.pendingSpellMaintenance=nil; return end
    if self.Engine.busy or (InCombatLockdown and InCombatLockdown()) then self.pendingSpellMaintenance=true; return end
    self.pendingSpellMaintenance=nil
    local plan=self.db.appliedPlan
    local formsChanged=plan.formSignature~=self.API:FormSignature()
    local ok,why
    if self.Engine.RepairLearnedActions then ok,why=self.Engine:RepairLearnedActions(plan)
    elseif formsChanged then ok,why=self.Engine:Activate(plan)
    else return end
    if not ok then
        self.dirty=true; self.needsRefresh=true
        self:Print(why or "Review your learned abilities in Hot Swap.")
        -- Stale form indices can select the wrong form. A combo-only repair
        -- failure leaves its original inert/owned macro intact for review.
        if formsChanged then self:RequireRecovery(why) end
    elseif ok==true then self:RefreshAvailabilityStatus()
    end
end
function K:MaintainItemBindings()
    if self.db and self.db.recoveryRequired then return end
    if not self.db or not self.db.enabled or not self.db.appliedPlan then self.pendingItemMaintenance=nil; return end
    if self.Engine.busy or (InCombatLockdown and InCombatLockdown()) then self.pendingItemMaintenance=true; return end
    self.pendingItemMaintenance=nil
    if self.Engine.RepairItemActions then
        local ok,why=self.Engine:RepairItemActions(self.db.appliedPlan)
        if not ok and why then self:Print(why) end
    end
end
function K:Restore()
    local ok,message=self.Engine:Restore()
    self:InvalidatePreview()
    return ok,message
end
function K:Disable() return self:Restore() end

-- Deliberately a small data format, never executable Lua.
local function encode(value) return tostring(value):gsub("([^%w%._%-%s])", function(c) return string.format("%%%02X", string.byte(c)) end):gsub("\n", "%%0A"):gsub("\r", "%%0D"):gsub("\t", "%%09") end
local function decode(value) return (value:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
function K:Export(name)
    return self.Presets:Export(name)
end
function K:ExportLegacy()
    self:GetSettings()
    local lines = {"KBO1"}
    local keys = {}
    for key in pairs(self.defaults) do keys[#keys+1] = key end
    keys[#keys+1] = "mount"
    table.sort(keys)
    for _, key in ipairs(keys) do
        local v = self.db.settings[key]
        if type(v) == "boolean" or type(v) == "string" or type(v) == "number" then
            lines[#lines+1] = "s\t" .. key .. "\t" .. type(v) .. "\t" .. encode(v)
        end
    end
    for key, value in pairs(self.db.settings.mouseButtons) do if value then lines[#lines+1] = "m\t"..encode(key) end end
    for id, key in pairs(self.db.settings.bindingOverrides) do lines[#lines+1] = "b\t"..encode(id).."\t"..encode(key) end
    for name, preset in pairs(self.db.presets) do
        for slot, id in pairs(preset.items or {}) do lines[#lines+1] = "p\t"..encode(name).."\t"..encode(slot).."\t"..encode(id) end
        for slot, id in pairs(preset.equipment or {}) do lines[#lines+1] = "e\t"..encode(name).."\t"..encode(slot).."\t"..encode(id) end
    end
    lines[#lines+1] = "a\t"..encode(self.db.activePreset)
    return table.concat(lines, "\n")
end
function K:Import(text)
    if self.Engine and self.Engine.busy then return false,"Wait for the current operation to finish." end
    if type(text)=="string" and text:gsub("\r",""):match("^([^\n]+)")=="KBO2" then return self.Presets:Import(text) end
    if type(text) ~= "string" or #text > 100000 then return false, "Invalid or oversized profile." end
    text = text:gsub("\r", "")
    if text:match("^([^\n]+)") ~= "KBO1" then return false, "This is not a Hot Swap profile." end
    local settings = self.Copy(self.defaults)
    settings.mouseButtons = {}
    local presets = {Leveling={items={},equipment={}}, Dungeon={items={},equipment={}}, PvP={items={},equipment={}}}
    local active = "Leveling"
    local count = 0
    for line in text:gmatch("[^\n]+") do
        count = count + 1
        if count > 1500 then return false, "Profile has too many entries." end
        if count > 1 then
            local fields = {}
            for v in (line.."\t"):gmatch("(.-)\t") do fields[#fields+1] = decode(v) end
            local tag, key = fields[1], fields[2]
            if tag == "s" and #fields == 4 then
                local typ, value = fields[3], fields[4]
                if self.legacySettings[key] then
                    if not self:ValidLegacySetting(key,typ,value) then return false,"Invalid legacy setting: "..key end
                elseif self.defaults[key] == nil and key ~= "mount" then return false, "Unknown setting: " .. tostring(key)
                elseif typ == "boolean" and type(self.defaults[key]) == "boolean" and (value=="true" or value=="false") then settings[key] = value=="true"
                elseif typ == "number" and (type(self.defaults[key])=="number" or key=="mount") and tonumber(value) then settings[key] = tonumber(value)
                elseif typ == "string" and key=="mount" and value:match("^spell:%d+$") then settings[key]=value
                elseif typ == "string" and type(self.defaults[key])=="string" and #value <= 40 then settings[key] = value
                else return false, "Invalid value for "..key end
            elseif tag == "m" and #fields==2 and key:match("^BUTTON%d+$") then
                local n=tonumber(key:match("%d+")); if n<4 or n>31 then return false,"Invalid mouse button." end
                settings.mouseButtons[key]=true
            elseif tag == "b" and #fields==3 and #key<=100 and #fields[3]<=40 and key:match("^[%w%._%-]+$") and not key:match("^mode%.") then
                settings.bindingOverrides[key]=fields[3]
            elseif (tag=="p" or tag=="e") and #fields==4 and presets[key] then
                local id=tonumber(fields[4])
                if tag=="p" and fields[3]=="mount" and fields[4]:match("^spell:%d+$") and tonumber(fields[4]:sub(7))>0 then id=fields[4]
                elseif not id or id<1 or id%1~=0 then return false,"Invalid item ID." end
                if tag=="p" then
                    local slot=fields[3]; if slot~="utility" and slot~="potion" and slot~="healthstone" and slot~="mount" then return false,"Invalid item slot." end
                    presets[key].items[slot]=id
                else
                    local slot=tonumber(fields[3]); if not slot or slot<1 or slot>19 or slot%1~=0 then return false,"Invalid equipment slot." end
                    presets[key].equipment[slot]=id
                end
            elseif tag=="a" and #fields==2 and presets[key] then active=key
            else return false,"Malformed profile entry on line "..count end
        end
    end
    if not ({auto=true,forever=true,era=true,retail=true})[settings.flavor] then return false,"Unknown game version." end
    if not ({frost=true,fire=true})[settings.primarySchool] then return false,"Unknown mage school." end
    for _,preset in pairs(presets) do preset.settings=self.Copy(settings); preset.settings.mount=preset.items.mount or preset.settings.mount end
    return self.Presets:MergeImport(presets,active)
end

if CreateFrame then
    local events=CreateFrame("Frame")
    K.events=events
    for _, event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_REGEN_ENABLED","SPELLS_CHANGED","LEARNED_SPELL_IN_TAB","LEARNED_SPELL_IN_SKILL_LINE","UPDATE_SHAPESHIFT_FORMS","PLAYER_TALENT_UPDATE","UNIT_PET","PET_BAR_UPDATE","PLAYER_EQUIPMENT_CHANGED","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","UPDATE_BINDINGS","UPDATE_MACROS","NEW_MOUNT_ADDED"}) do
        pcall(events.RegisterEvent,events,event)
    end
    events:SetScript("OnEvent",function(_,event,arg,success)
        if event=="ADDON_LOADED" and arg==K.name then K:Init()
        elseif event=="PLAYER_LOGIN" then
            K:Init()
            K.NativeBars:ApplyMacroTextPreference()
            K.Items:Invalidate()
            K.API:InvalidateSpellbook()
            K:InvalidatePreview()
            if K.db.recoveryRequired then K:RequireRecovery(K.db.recoveryRequired)
            elseif K.db.enabled and K.db.appliedPlan then
                local ok,err=K.Engine:Activate(K.db.appliedPlan)
                if not ok then
                    K:Print(err or "Could not activate the saved layout. Open /hotswap.")
                    K:RequireRecovery(err)
                end
                K:MaintainMouseControls()
            end
            if K.CurrentBindings then K.CurrentBindings:QueueRefresh() end
            if not K.db.welcomed then K:Print("Type /hotswap to review your layout. Nothing changes until you apply it."); K.db.welcomed=true end
        elseif K.db then
            if event=="UPDATE_BINDINGS" then
                if K.Library then K.Library.commandCache=nil end
                K.API:InvalidateBindingCommands()
            end
            if event=="GET_ITEM_INFO_RECEIVED" and not K.Items:OnItemInfoReceived(arg,success) then return end
            if event=="UNIT_PET" and arg and arg~="player" then return end
            local spellsChanged=event=="SPELLS_CHANGED" or event=="LEARNED_SPELL_IN_TAB" or event=="LEARNED_SPELL_IN_SKILL_LINE" or event=="PLAYER_TALENT_UPDATE" or event=="UPDATE_SHAPESHIFT_FORMS" or event=="UNIT_PET" or event=="PET_BAR_UPDATE"
            if event=="BAG_UPDATE_DELAYED" or event=="PLAYER_EQUIPMENT_CHANGED" or event=="NEW_MOUNT_ADDED" then K.Items:Invalidate() end
            if spellsChanged then
                K.API:InvalidateSpellbook()
                K.dirty=true
                K.needsRefresh=true
                K:RefreshAvailabilityStatus()
            end
            K:InvalidatePreview()
            if K.CurrentBindings and (spellsChanged or event=="BAG_UPDATE_DELAYED" or event=="PLAYER_EQUIPMENT_CHANGED" or event=="GET_ITEM_INFO_RECEIVED" or event=="PLAYER_REGEN_ENABLED" or event=="UPDATE_MACROS") then K.CurrentBindings:QueueRefresh() end
            if spellsChanged or event=="PLAYER_REGEN_ENABLED" then K:MaintainLearnedActions() end
            if event=="BAG_UPDATE_DELAYED" or event=="PLAYER_EQUIPMENT_CHANGED" or event=="GET_ITEM_INFO_RECEIVED" or event=="PLAYER_REGEN_ENABLED" then K:MaintainItemBindings() end
            if event=="PLAYER_REGEN_ENABLED" and K.needsRefresh then
                K:Print("Your spells or forms changed. Open /hotswap to review the updated layout.")
                K.needsRefresh=false
            end
            if event=="PLAYER_REGEN_ENABLED" and K.pendingMouseRepair then K:MaintainMouseControls() end
            K:QueueRefresh()
        end
    end)
    SLASH_KEYBINDOPTIMIZER1="/hotswap"
    SLASH_KEYBINDOPTIMIZER2="/kbo"
    SLASH_KEYBINDOPTIMIZER3="/keybindoptimizer"
    SlashCmdList=SlashCmdList or {}
    SlashCmdList.KEYBINDOPTIMIZER=function(command)
        command=(command or ""):lower()
        if command=="restore" or command=="disable" then local _,message=K:Restore(); K:Print(message)
        elseif command=="apply" then local _,message=K:Apply(); K:Print(message)
        elseif K.UI then K.UI:Toggle() end
    end
end
