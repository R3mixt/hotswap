local _, K = ...
K.Launcher = {}
local L = K.Launcher

local function closePanel(panel)
    if panel and panel:IsShown() then
        if HideUIPanel then HideUIPanel(panel) else panel:Hide() end
    end
end

function L:Open()
    closePanel(GameMenuFrame)
    closePanel(SettingsPanel)
    closePanel(InterfaceOptionsFrame)
    if not K.UI then return end
    if K.UI.Open then K.UI:Open()
    else
        K.UI:Create()
        if not K.UI.frame:IsShown() then K.UI:Toggle()
        else K.UI.frame:Raise() end
    end
end

function L:RegisterSettings()
    if self.settingsRegistered then return true end
    local modern = Settings and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function"
    local legacy = type(InterfaceOptions_AddCategory) == "function"
    if not modern and not legacy then return false end
    local panel = self.panel
    if not panel then
        panel = CreateFrame("Frame", "HotSwapSettingsPanel", UIParent)
        panel.name = "Hot Swap"
        panel:Hide()
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Hot Swap")
        local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        description:SetPoint("TOPLEFT", 16, -48)
        description:SetPoint("TOPRIGHT", -20, -48)
        description:SetJustifyH("LEFT")
        description:SetText("Configure your keyboard and mouse bindings, Druid form pages, and item presets.")
        local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        open:SetSize(180, 28)
        open:SetPoint("TOPLEFT", 16, -94)
        open:SetText("Open Hot Swap")
        open:SetScript("OnClick", function() L:Open() end)
        local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", 16, -139)
        note:SetText("Review changes before applying. Existing controls stay active until Apply.")
        panel.openButton = open
        self.panel = panel
    end
    if modern then
        self.category = Settings.RegisterCanvasLayoutCategory(panel, "Hot Swap")
        Settings.RegisterAddOnCategory(self.category)
    else
        InterfaceOptions_AddCategory(panel)
    end
    self.settingsRegistered = true
    return true
end

function L:AppendMenuButton(menu)
    if not menu or type(menu.AddButton) ~= "function" then return end
    local insertAfter
    -- Modern Era and Forever rebuild their pooled menu on every opening.
    -- Add one native button per rebuild and let their layout place it.
    if menu.buttonPool and type(menu.buttonPool.EnumerateActive) == "function" then
        for existing in menu.buttonPool:EnumerateActive() do
            if existing:GetScript("OnClick") == self.menuCallback then return end
            if existing:GetText() == (ADDONS or "AddOns") then insertAfter = existing.layoutIndex end
        end
    end
    local button = menu:AddButton("Hot Swap", self.menuCallback)
    if button and type(insertAfter) == "number" then button.layoutIndex = insertAfter + 0.5 end
    self.menuButton = button
end

function L:RegisterMenu()
    local menu = GameMenuFrame
    if not menu or self.hookedMenu == menu then return self.hookedMenu ~= nil end
    self.menuCallback = self.menuCallback or function() L:Open() end
    if type(menu.InitButtons) == "function" and type(menu.AddButton) == "function" and hooksecurefunc then
        hooksecurefunc(menu, "InitButtons", function(frame)
            if L.hookedMenu == frame then L:AppendMenuButton(frame) end
        end)
        self.hookedMenu = menu
        if menu:IsShown() then self:AppendMenuButton(menu) end
        return true
    end
    -- Older clients without the pooled menu API use an independent shortcut.
    -- Do not attach it to their layout or change their native menu geometry.
    local button = self.menuButton
    if not button then
        button = CreateFrame("Button", "HotSwapGameMenuButton", UIParent, "UIPanelButtonTemplate")
        button:SetSize(180, 26)
        button:SetFrameStrata("DIALOG")
        button:SetText("Hot Swap")
        button:SetScript("OnClick", self.menuCallback)
        self.menuButton = button
    end
    button:ClearAllPoints()
    button:SetPoint("TOP", menu, "BOTTOM", 0, -4)
    menu:HookScript("OnShow", function() if L.hookedMenu == menu then button:Show() end end)
    menu:HookScript("OnHide", function() if L.hookedMenu == menu then button:Hide() end end)
    self.hookedMenu = menu
    button:SetShown(menu:IsShown())
    return true
end

function L:Register()
    self:RegisterSettings()
    self:RegisterMenu()
end

local events = CreateFrame("Frame")
L.events = events
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == K.name or name == "Blizzard_GameMenu"
        or name == "Blizzard_Settings" or name == "Blizzard_Settings_Shared" then L:Register() end
end)
