local _, K = ...

-- Appearance only: no secure frames, bindings or preset settings are changed.
K.Themes = {}
local T = K.Themes
local unpack = unpack or table.unpack
local palettes = {
    classic = {
        bg={0.055,0.047,0.035,0.99}, panel={0.10,0.085,0.065,1}, field={0.08,0.07,0.055,1},
        edge={0.58,0.51,0.37,1}, text={0.95,0.91,0.82,1}, muted={0.68,0.65,0.58,1},
        accent={1,0.82,0,1}, warning={1,0.72,0.25,1}, error={1,0.43,0.43,1}, white={1,1,1,1},
        key={0.035,0.03,0.022,0.95}, pressed={1,0.82,0.1,0.32}, row={0.08,0.07,0.05,0.45},
        progress={0.72,0.53,0.16,1}, selection={1,0.82,0.35,0.35}, hover={1,1,1,1}, opaque={0.055,0.047,0.035,1},
    },
    modern = {
        bg={0.047,0.067,0.098,1}, panel={0.078,0.106,0.149,1}, field={0.035,0.051,0.078,1},
        edge={0.22,0.30,0.39,1}, text={0.90,0.94,0.98,1}, muted={0.64,0.72,0.81,1},
        accent={0.30,0.83,0.94,1}, warning={1,0.76,0.36,1}, error={1,0.47,0.49,1}, white={1,1,1,1},
        key={0.080,0.114,0.157,1}, pressed={0.30,0.83,0.94,0.30}, row={0.10,0.14,0.19,0.60},
        progress={0.20,0.68,0.79,1}, selection={0.30,0.83,0.94,0.18}, hover={0.30,0.83,0.94,0.12}, opaque={0.047,0.067,0.098,1},
    },
}
T.Colors = {}
for name, value in pairs(palettes.classic) do T.Colors[name]={unpack(value)} end
T.widgets=setmetatable({}, {__mode="k"})
T.fonts=setmetatable({}, {__mode="k"})
T.textures=setmetatable({}, {__mode="k"})

function T:GetID()
    local id=K.db and K.db.preferences and K.db.preferences.theme
    return palettes[id] and id or "classic"
end
function T:GetFont()
    -- ARIALN ships with the supported clients; keep Blizzard's locale font on
    -- CJK clients, where that Latin-only font would drop translated glyphs.
    local locale=GetLocale and GetLocale() or "enUS"
    if self:GetID()=="modern" and locale~="koKR" and locale~="zhCN" and locale~="zhTW" then return "Fonts\\ARIALN.TTF" end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
function T:UpdateColors()
    for name,value in pairs(palettes[self:GetID()]) do
        for i=1,4 do self.Colors[name][i]=value[i] end
    end
end
function T:TextColor(fs,tone)
    local record=self.fonts[fs]
    if record then record.tone=tone end
    local owner=fs.hotSwapButton
    fs:SetTextColor(unpack(self:GetID()=="modern" and owner and owner.IsEnabled and not owner:IsEnabled() and self.Colors.muted or tone or self.Colors.text))
end
function T:Font(fs,size,tone)
    local record=self.fonts[fs]
    if not record then
        local path,oldSize,flags
        if fs.GetFont then path,oldSize,flags=fs:GetFont() end
        record={path=path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size=oldSize or size or 12,flags=flags or ""}
        self.fonts[fs]=record
    end
    if size then record.size=size end
    if tone then record.tone=tone end
    fs:SetFont(self:GetID()=="modern" and self:GetFont() or record.path,record.size,record.flags)
    if record.tone then self:TextColor(fs,record.tone) end
end
function T:Texture(texture,tone,classicTexture,classicBlend)
    self.textures[texture]={tone=tone,classicTexture=classicTexture,classicBlend=classicBlend}
    if self:GetID()=="classic" and classicTexture then
        texture:SetTexture(classicTexture)
        if classicBlend then texture:SetBlendMode(classicBlend); texture:SetVertexColor(unpack(tone)) end
    else
        texture:SetColorTexture(unpack(tone))
        texture:SetVertexColor(1,1,1,1)
        if classicBlend then texture:SetBlendMode("BLEND") end
    end
end

local classicBackdrop={bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}
local modernBackdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",tile=false,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}}
local function isTexture(region)
    return region and ((region.IsObjectType and region:IsObjectType("Texture")) or region.kind=="Texture")
end
local function buttonText(f)
    local value=f.text
    if (type(value)=="table" or type(value)=="userdata") and value.SetTextColor then return value end
end
local function saveRegion(record,region)
    if not region or record.saved[region]~=nil then return end
    record.saved[region]=region.GetAlpha and region:GetAlpha() or 1
end
local function captureDecorations(f,record)
    -- Capture before our own textures exist. Only the widget's artwork is
    -- suppressed; labels, spell icons and child controls keep their visibility.
    if f.GetRegions then
        for _,region in ipairs({f:GetRegions()}) do if isTexture(region) then saveRegion(record,region) end end
    end
    for _,name in ipairs({"Left","Middle","Right","LeftDisabled","MiddleDisabled","RightDisabled","TopLeft","TopRight","BottomLeft","BottomRight","TopMiddle","BottomMiddle","LeftMiddle","RightMiddle","Bg","TitleBg","TitleBG","TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge","Center","NineSlice"}) do
        if f[name] and f[name].SetAlpha then saveRegion(record,f[name]) end
    end
    for _,getter in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture","GetHighlightTexture"}) do
        if f[getter] then saveRegion(record,f[getter](f)) end
    end
    if record.role=="frame" then
        for _,name in ipairs({"Inset","InsetBg"}) do if f[name] then saveRegion(record,f[name]) end end
    end
end
local function surface(f,record)
    if record.surface then return end
    local fill=f:CreateTexture(nil,"BACKGROUND",nil,-7); fill:SetAllPoints(f)
    record.surface=fill; record.lines={}
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local line=f:CreateTexture(nil,"BORDER")
        if side=="TOP" or side=="BOTTOM" then
            line:SetPoint(side.."LEFT",f,side.."LEFT",0,0); line:SetPoint(side.."RIGHT",f,side.."RIGHT",0,0); line:SetHeight(1)
        else
            line:SetPoint("TOP"..side,f,"TOP"..side,0,0); line:SetPoint("BOTTOM"..side,f,"BOTTOM"..side,0,0); line:SetWidth(1)
        end
        record.lines[#record.lines+1]=line
    end
end
function T:Style(f)
    local record=self.widgets[f]; if not record then return end
    local modern=self:GetID()=="modern"
    local C=self.Colors
    f.hotSwapTheme=self:GetID()
    if record.role=="box" then
        if f.SetBackdrop then
            f:SetBackdrop(modern and modernBackdrop or classicBackdrop)
            if modern then f:SetBackdropColor(unpack(record.fill or C.panel))
            else f:SetBackdropColor(1,1,1,(record.fill or C.panel)[4] or 1) end
            f:SetBackdropBorderColor(unpack(C.edge))
        elseif record.surface then record.surface:SetColorTexture(unpack(record.fill or C.panel)) end
        return
    end
    for region,alpha in pairs(record.saved) do region:SetAlpha(modern and 0 or alpha) end
    if record.surface then
        record.surface:SetShown(modern)
        for _,line in ipairs(record.lines) do line:SetShown(modern); line:SetColorTexture(unpack(C.edge)) end
    end
    if not modern then
        if record.closeLabel then record.closeLabel:Hide() end
        if record.checkMark then record.checkMark:Hide() end
        if record.thumb and record.thumbColor then record.thumb:SetVertexColor(unpack(record.thumbColor)) end
        return
    end
    local fill=record.fill or C.panel
    if record.role=="frame" then fill=C.bg
    elseif record.role=="edit" or record.role=="slider" then fill=C.field
    elseif record.role=="button" or record.role=="tab" or record.role=="close" then
        local disabled=f.IsEnabled and not f:IsEnabled()
        if record.selected or record.primary then fill={0.09,0.27,0.33,1} end
        if record.hovered and not disabled then fill={0.14,0.24,0.31,1} end
        if record.pressed and not disabled then fill={0.055,0.19,0.24,1} end
        if disabled then fill={0.075,0.09,0.115,1} end
        if record.selected or record.primary then for _,line in ipairs(record.lines) do line:SetColorTexture(unpack(disabled and C.edge or C.accent)) end end
        local text=buttonText(f)
        local fontRecord=text and self.fonts[text]
        if text then text:SetTextColor(unpack(disabled and C.muted or (fontRecord and fontRecord.tone) or C.text)) end
    end
    if record.surface then record.surface:SetColorTexture(unpack(fill)) end
    if record.closeLabel then record.closeLabel:Show() end
    if record.checkMark then
        record.checkMark:SetShown(f:GetChecked() and true or false)
        record.checkMark:SetColorTexture(unpack(f.IsEnabled and not f:IsEnabled() and C.muted or C.accent))
    end
    if record.thumb then record.thumb:SetVertexColor(unpack(C.accent)) end
    if record.role=="slider" then for _,line in ipairs(record.lines) do line:Hide() end end
end
function T:Skin(f,role,fill,primary)
    local record=self.widgets[f]
    if not record then
        record={role=role,fill=fill,primary=primary,saved={}}
        self.widgets[f]=record; f.hotSwapThemeRole=role
        local text=buttonText(f); if text then text.hotSwapButton=f end
        if role=="box" then
            if not f.SetBackdrop then
                record.surface=f:CreateTexture(nil,"BACKGROUND"); record.surface:SetAllPoints(f)
            end
        else
            captureDecorations(f,record)
            surface(f,record)
            if role=="close" then
                local text=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
                text:SetPoint("CENTER"); text:SetText("×"); self:Font(text,18,self.Colors.text); record.closeLabel=text
            elseif role=="check" then
                if f.GetCheckedTexture then saveRegion(record,f:GetCheckedTexture()) end
                if f.GetDisabledCheckedTexture then saveRegion(record,f:GetDisabledCheckedTexture()) end
                local mark=f:CreateTexture(nil,"ARTWORK"); mark:SetPoint("TOPLEFT",8,-8); mark:SetPoint("BOTTOMRIGHT",-8,8)
                self:Texture(mark,self.Colors.accent); record.checkMark=mark
                if f.HookScript then f:HookScript("OnClick",function() T:Style(f) end) end
                if f.HookScript then
                    f:HookScript("OnEnable",function() T:Style(f) end)
                    f:HookScript("OnDisable",function() T:Style(f) end)
                end
                -- Check state is also set by renders, without a click.
                if hooksecurefunc then hooksecurefunc(f,"SetChecked",function() T:Style(f) end) end
            elseif role=="slider" then
                record.surface:ClearAllPoints(); record.surface:SetPoint("LEFT",f,"LEFT",0,0); record.surface:SetPoint("RIGHT",f,"RIGHT",0,0); record.surface:SetHeight(4)
                record.thumb=f.GetThumbTexture and f:GetThumbTexture()
                if record.thumb then
                    record.saved[record.thumb]=nil
                    record.thumbColor={record.thumb:GetVertexColor()}; if #record.thumbColor==0 then record.thumbColor={1,1,1,1} end
                end
            end
            if f.HookScript and (role=="button" or role=="tab" or role=="close") then
                f:HookScript("OnEnter",function() record.hovered=true; T:Style(f) end)
                f:HookScript("OnLeave",function() record.hovered=false; record.pressed=false; T:Style(f) end)
                f:HookScript("OnMouseDown",function() record.pressed=true; T:Style(f) end)
                f:HookScript("OnMouseUp",function() record.pressed=false; T:Style(f) end)
                f:HookScript("OnEnable",function() T:Style(f) end)
                f:HookScript("OnDisable",function() record.hovered=false; record.pressed=false; T:Style(f) end)
                f:HookScript("OnHide",function() record.hovered=false; record.pressed=false; T:Style(f) end)
            end
        end
    end
    self:Style(f)
    return f
end
function T:SelectTab(f,selected)
    local record=self.widgets[f]
    if record then record.selected=selected and true or false; self:Style(f) end
end
function T:Apply()
    self:UpdateColors()
    for fs,record in pairs(self.fonts) do self:Font(fs,nil,record.tone) end
    for texture,record in pairs(self.textures) do self:Texture(texture,record.tone,record.classicTexture,record.classicBlend) end
    for f in pairs(self.widgets) do self:Style(f) end
end
function T:Set(id)
    if not palettes[id] then return false,"Choose Classic or Modern." end
    if not K.db then return false,"Character settings are not ready." end
    if K.Engine and K.Engine.busy then return false,"Wait for the current update to finish." end
    K.db.preferences=K.db.preferences or {}
    K.db.preferences.theme=id
    self:Apply()
    if K.UI and K.UI.frame then K.UI:Refresh() end
    return true
end
