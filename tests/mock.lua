-- Deterministic harness. Protected-action behavior is intentionally stricter
-- than permissive stubs, while combat-secure dispatch still needs client QA.
Mock = {
  combat=false, class="DRUID", locale="enUS", build="1.60.1", buildNumber="70707",
  frames={}, writes={}, messages={}, bindings={ F="ASSISTTARGET", T="ATTACKTARGET", ["MOUSEWHEELUP"]="CAMERAZOOMIN", ["MOUSEWHEELDOWN"]="CAMERAZOOMOUT" },
  cvars={ autoSelfCast="1", enableMouseoverCast="0", ActionButtonUseKeyDown="1" },
  modified={ SELFCAST="NONE", FOCUSCAST="NONE", MOUSEOVERCAST="NONE" },
  macros={ [1]={name="UserMacro", icon=1, body="/say preserved"} },
  spells={}, petSpells={}, forms={}, equipment={}, bagItems={}, itemInfo={}, actions={}, bindingSet=1,
  now=12345, timers={}, itemRequests={}, shift=false, ctrl=false, alt=false,
  catalog={}, downKeys={}, propagatedKeys={},
  settingsCategories={}, addonCategories={}, legacyCategories={},
}

function Mock:Write(kind, ...)
  if self.combat and not self.secureDispatch then error("PROTECTED WRITE DURING COMBAT: "..kind) end
  self.writes[#self.writes+1]={kind,...}
end
function Mock:ResetWrites() self.writes={} end
function Mock:Fire(event, ...)
  self.eventDepth=(self.eventDepth or 0)+1
  assert(self.eventDepth<40,"Reentrant event storm: "..event)
  for _,f in ipairs(self.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end
  end
  self.eventDepth=self.eventDepth-1
end
function Mock:Advance(elapsed,steps)
  -- One call is one rendered frame unless explicitly subdivided. OnUpdate
  -- scripts installed during this frame first run on the next frame.
  for step=1,(steps or 1) do
    local delta=elapsed/(steps or 1)
    self.now=self.now+delta
    local callbacks={}
    for _,frame in ipairs(self.frames) do
      if frame.scripts.OnUpdate and frame:IsVisible() then callbacks[#callbacks+1]={frame,frame.scripts.OnUpdate} end
    end
    for _,pair in ipairs(callbacks) do pair[2](pair[1],delta) end
    local pending=self.timers; self.timers={}
    for _,timer in ipairs(pending) do
      if timer.due<=self.now then timer.callback() else self.timers[#self.timers+1]=timer end
    end
  end
end
function Mock:SetModifiers(shift,ctrl,alt)
  local changes={{"LSHIFT","shift",shift},{"LCTRL","ctrl",ctrl},{"LALT","alt",alt}}
  for _,entry in ipairs(changes) do
    local down=entry[3] and true or false
    if self[entry[2]]~=down then self[entry[2]]=down; self:Fire("MODIFIER_STATE_CHANGED",entry[1],down and 1 or 0) end
  end
end
function Mock:Learn(id,name,rank)
  self.spells[#self.spells+1]={id=id,name=name,rank=rank or "",passive=false}
end
function Mock:Spell(id)
  for _,s in ipairs(self.spells) do if s.id==id or s.name==id then return s end end
  for _,s in ipairs(self.petSpells) do if s.id==id or s.name==id then return s end end
end
function Mock:SpellData(id)
  local known=self:Spell(id)
  if known then return known end
  for _,spell in pairs(self.catalog) do if spell.id==id or spell.name==id then return spell end end
end
function Mock:SetDefaultDruid()
  self.spells={}
  local rows={
    {5176,"Wrath","Rank 1"},{5177,"Wrath","Rank 2"},{2912,"Starfire"},
    {8921,"Moonfire"},{774,"Rejuvenation"},{1058,"Rejuvenation","Rank 2"},
    {8936,"Regrowth"},{5185,"Healing Touch"},{18562,"Swiftmend"},
    {740,"Tranquility"},{48438,"Wild Growth"},{22812,"Barkskin"},
    {19970,"Entangling Roots"},{339,"Entangling Roots","Rank 1"},
    {2637,"Hibernate"},{2782,"Remove Curse"},{2893,"Abolish Poison"},
    {8946,"Cure Poison"},{29166,"Innervate"},{20484,"Rebirth"},
    {50769,"Revive"},{22842,"Frenzied Regeneration"},{1066,"Aquatic Form"},
    {768,"Cat Form"},{5487,"Bear Form"},{783,"Travel Form"},
    {24858,"Moonkin Form"},{5215,"Prowl"},{5217,"Tiger's Fury"},
    {5221,"Shred"},{1082,"Claw"},{1822,"Rake"},{1079,"Rip"},
    {22568,"Ferocious Bite"},{5229,"Enrage"},{99,"Demoralizing Roar"},
    {6795,"Growl"},{779,"Swipe"},{6807,"Maul"},{5211,"Bash"},
    {1850,"Dash"},{16979,"Feral Charge"},{1126,"Mark of the Wild"},
    {467,"Thorns"},{16857,"Faerie Fire (Feral)"},{770,"Faerie Fire"},
    {9005,"Pounce"},{6785,"Ravage"},{16689,"Nature's Grasp"},
  }
  for _,r in ipairs(rows) do self:Learn(unpack(r)) end
  self.forms={ {id=5487,name="Bear Form"},{id=1066,name="Aquatic Form"},{id=768,name="Cat Form"},{id=783,name="Travel Form"},{id=24858,name="Moonkin Form"} }
end
Mock:SetDefaultDruid()

_G=_G or _ENV
SlashCmdList={}
UIParent={}
STANDARD_TEXT_FONT="Fonts\\FRIZQT__.TTF"
GameFontNormal={}
GameFontHighlight={}
GameFontNormalSmall={}
BackdropTemplateMixin={}
UISpecialFrames={}
Enum={ SpellBookSpellBank={Player=0,Pet=1}, SpellBookItemType={Spell=1,FutureSpell=2,PetAction=3,Flyout=4}, BindingSet={Account=1,Character=2,Current=3} }
BOOKTYPE_SPELL="spell"
WOW_PROJECT_MAINLINE=1
WOW_PROJECT_CLASSIC=2
WOW_PROJECT_CAMELOT=19
WOW_PROJECT_ID=19
NUM_BAG_SLOTS=4
MAX_ACCOUNT_MACROS=120
MAX_CHARACTER_MACROS=30
Constants={MacroConsts={MAX_ACCOUNT_MACROS=120,MAX_CHARACTER_MACROS=30}}

local FrameMethods={}
local FrameMeta={__index=function(t,k)
  if FrameMethods[k] then return FrameMethods[k] end
  if k:match("^Set") or k:match("^Get") or k:match("^Enable") or k:match("^Disable") or k:match("^Register") or k:match("^Unregister") or k:match("^Clear") or k:match("^Start") or k:match("^Stop") or k:match("^Add") or k:match("^Highlight") or k:match("^Lock") or k:match("^Unlock") then return function() end end
end}
function CreateFrame(kind,name,parent,template)
  local f=setmetatable({kind=kind,name=name,parent=parent,template=template,scripts={},events={},attributes={},shown=true,text="",checked=false},FrameMeta)
  Mock.frames[#Mock.frames+1]=f
  if name then _G[name]=f end
  if template and template:find("BasicFrameTemplateWithInset",1,true) then
    f.TitleText=CreateFrame("FontString",nil,f)
    f.CloseButton=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    f.CloseButton:SetScript("OnClick",function() f:Hide() end)
    f.Inset=CreateFrame("Frame",nil,f,"InsetFrameTemplate")
  end
  if template and template:find("UICheckButtonTemplate",1,true) then
    f.text=CreateFrame("FontString",nil,f)
  end
  return f
end
function FrameMethods:SetScript(k,v) self.scripts[k]=v end
function FrameMethods:GetScript(k) return self.scripts[k] end
function FrameMethods:HookScript(k,v) local old=self.scripts[k]; self.scripts[k]=function(...) if old then old(...) end; v(...) end end
function FrameMethods:RegisterEvent(k) self.events[k]=true end
function FrameMethods:UnregisterEvent(k) self.events[k]=nil end
function FrameMethods:UnregisterAllEvents() self.events={} end
function FrameMethods:SetAttribute(k,v)
  if self.template and self.template:find("Secure") then Mock:Write("attribute",self.name,k,v) end
  self.attributes[k]=v
  if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self,k,v) end
end
function FrameMethods:GetAttribute(k) return self.attributes[k] end
function FrameMethods:Show() local changed=not self.shown; self.shown=true; if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function FrameMethods:Hide() local changed=self.shown; self.shown=false; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function FrameMethods:SetShown(v) if v then self:Show() else self:Hide() end end
function FrameMethods:IsShown() return self.shown end
function FrameMethods:IsVisible() return self.shown and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible()) end
function FrameMethods:SetText(v)
  local changed=self._text~=(v or "")
  self._text=v or ""
  if type(self.text)~="table" then self.text=self._text end
  if self.fontString then self.fontString:SetText(self._text) end
  if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end
end
function FrameMethods:GetText() return self._text or (type(self.text)=="string" and self.text or "") end
function FrameMethods:SetChecked(v) self.checked=v end
function FrameMethods:GetChecked() return self.checked end
function FrameMethods:SetSize(w,h)
  local changed=self.width~=w or self.height~=h
  self.width,self.height=w,h
  if changed and self.scripts.OnSizeChanged then
    Mock.sizeDepth=(Mock.sizeDepth or 0)+1
    assert(Mock.sizeDepth<40,"Recursive OnSizeChanged: "..tostring(self.name or self.kind))
    Mock.sizeCallbacks=(Mock.sizeCallbacks or 0)+1
    self.scripts.OnSizeChanged(self,w,h)
    Mock.sizeDepth=Mock.sizeDepth-1
  end
end
function FrameMethods:SetWidth(w) self:SetSize(w,self.height or 600) end
function FrameMethods:SetHeight(h) self:SetSize(self.width or 860,h) end
function FrameMethods:GetWidth() return self.width or 860 end
function FrameMethods:GetHeight() return self.height or 600 end
function FrameMethods:GetName() return self.name end
function FrameMethods:SetID(v) self.id=v end
function FrameMethods:GetID() return self.id or 0 end
function FrameMethods:GetParent() return self.parent end
function FrameMethods:GetFontString() if not self.fontString then self.fontString=CreateFrame("FontString",nil,self); self.fontString:SetText(self:GetText()) end return self.fontString end
function FrameMethods:GetThumbTexture() if not self.thumb then self.thumb=CreateFrame("Texture") end return self.thumb end
local function buttonTexture(frame,field,value)
  local texture=rawget(frame,field)
  if not texture then texture=CreateFrame("Texture",nil,frame); frame[field]=texture end
  if value~=nil then texture:SetTexture(value) end
  return texture
end
function FrameMethods:SetTexture(value) self.texture=value end
function FrameMethods:GetTexture() return self.texture end
function FrameMethods:SetDesaturated(value) self.desaturated=value end
function FrameMethods:SetVertexColor(...) self.vertexColor={...} end
function FrameMethods:SetTextColor(...) self.textColor={...} end
function FrameMethods:SetColorTexture(...) self.colorTexture={...} end
function FrameMethods:SetBackdropBorderColor(...) self.borderColor={...} end
function FrameMethods:SetAllPoints(target) self.allPoints=target or self.parent end
function FrameMethods:ClearAllPoints() self.point=nil; self.allPoints=nil end
function FrameMethods:SetAtlas(value) self.atlas=value end
function FrameMethods:GetAtlas() return self.atlas end
function FrameMethods:SetNormalTexture(value) buttonTexture(self,"normalTexture",value) end
function FrameMethods:GetNormalTexture() return buttonTexture(self,"normalTexture") end
function FrameMethods:SetPushedTexture(value) buttonTexture(self,"pushedTexture",value) end
function FrameMethods:GetPushedTexture() return buttonTexture(self,"pushedTexture") end
function FrameMethods:SetHighlightTexture(value) buttonTexture(self,"highlightTexture",value) end
function FrameMethods:GetHighlightTexture() return buttonTexture(self,"highlightTexture") end
function FrameMethods:SetDisabledTexture(value) buttonTexture(self,"disabledTexture",value) end
function FrameMethods:GetDisabledTexture() return buttonTexture(self,"disabledTexture") end
function FrameMethods:SetCheckedTexture(value) buttonTexture(self,"checkedTexture",value) end
function FrameMethods:GetCheckedTexture() return buttonTexture(self,"checkedTexture") end
function FrameMethods:SetDisabledCheckedTexture(value) buttonTexture(self,"disabledCheckedTexture",value) end
function FrameMethods:GetDisabledCheckedTexture() return buttonTexture(self,"disabledCheckedTexture") end
function FrameMethods:SetNormalFontObject(value) self.normalFontObject=value end
function FrameMethods:SetHighlightFontObject(value) self.highlightFontObject=value end
function FrameMethods:SetDisabledFontObject(value) self.disabledFontObject=value end
function FrameMethods:SetBackdrop(value) self.backdrop=value end
function FrameMethods:SetFontObject(value) self.fontObject=value end
function FrameMethods:SetFont(path,size,flags) self.font={path,size,flags} end
function FrameMethods:GetFont() return unpack(self.font or {STANDARD_TEXT_FONT,12,""}) end
function FrameMethods:GetStringHeight() return 14*math.max(1,math.ceil(#tostring(self:GetText())/80)) end
function FrameMethods:GetStringWidth() return #tostring(self:GetText())*7 end
function FrameMethods:SetMinMaxValues(a,b) self.minimum=a; self.maximum=b end
function FrameMethods:GetMinMaxValues() return self.minimum or 0,self.maximum or 100 end
function FrameMethods:CreateFontString(name) return CreateFrame("FontString",name,self) end
function FrameMethods:CreateTexture(name) return CreateFrame("Texture",name,self) end
function FrameMethods:SetEnabled(v) self.enabled=v end
function FrameMethods:IsEnabled() return self.enabled~=false end
function FrameMethods:Enable() self.enabled=true end
function FrameMethods:Disable() self.enabled=false end
function FrameMethods:SetValue(v)
  local lo,hi=self:GetMinMaxValues(); v=math.max(lo,math.min(hi,v))
  local changed=self.value~=v; self.value=v
  if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v,false) end
end
function FrameMethods:GetValue() return self.value or 0 end
function FrameMethods:GetVerticalScroll() return self.scroll or 0 end
function FrameMethods:SetVerticalScroll(v) self.scroll=v end
function FrameMethods:GetVerticalScrollRange() return 1000 end
function FrameMethods:SetPoint(...) self.point={...} end
function FrameMethods:GetPoint() return unpack(self.point or {"CENTER",UIParent,"CENTER",0,0}) end
function FrameMethods:GetEffectiveScale() return 1 end
function FrameMethods:SetAlpha(v) self.alpha=v end
function FrameMethods:GetAlpha() return self.alpha or 1 end
function FrameMethods:GetFrameLevel() return self.frameLevel or 1 end
function FrameMethods:SetFrameLevel(v) self.frameLevel=v end
function FrameMethods:SetFrameStrata(v) self.strata=v end
function FrameMethods:GetFrameStrata() return self.strata or "MEDIUM" end
function FrameMethods:Execute(code,...)
  local chunk=assert(loadstring(code,"@secure-snippet"))
  local env=setmetatable({self=self},{__index=_G})
  setfenv(chunk,env)
  return chunk(...)
end
function FrameMethods:ClearBindings() self.overrideBindings={} end
function FrameMethods:SetBinding(priority,key,action) self.overrideBindings=self.overrideBindings or {}; self.overrideBindings[key]=action end
function FrameMethods:RunAttribute(name,newstate)
  local chunk=assert(loadstring(self:GetAttribute(name),"@"..name))
  local env=setmetatable({self=self,newstate=newstate},{__index=_G})
  setfenv(chunk,env)
  Mock.secureDispatch=true
  local ok,err=pcall(chunk)
  Mock.secureDispatch=false
  if not ok then error(err) end
end
function FrameMethods:EnableKeyboard(v)
  if Mock.strictInputRestrictions and Mock.combat then error("PROTECTED INPUT CHANGE DURING COMBAT: EnableKeyboard") end
  self.keyboard=v
end
function FrameMethods:EnableMouse(v) self.mouse=v end
function FrameMethods:SetPropagateKeyboardInput(v)
  if Mock.strictInputRestrictions and Mock.combat then error("PROTECTED INPUT CHANGE DURING COMBAT: SetPropagateKeyboardInput") end
  self.propagate=v
end
function FrameMethods:SetFocus()
  if Mock.focus==self then return end
  if Mock.focus then Mock.focus:ClearFocus() end
  Mock.focus=self
  if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function FrameMethods:ClearFocus()
  if Mock.focus~=self then return end
  Mock.focus=nil
  if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function FrameMethods:HasFocus() return Mock.focus==self end
function GetCurrentKeyBoardFocus() return Mock.focus end
function FrameMethods:Raise() self.raised=(self.raised or 0)+1 end
function FrameMethods:Click(button)
  if self.kind=="CheckButton" then self.checked=not self.checked end
  if self.scripts.OnClick then self.scripts.OnClick(self,button or "LeftButton") end
end
GameTooltip=CreateFrame("GameTooltip")
function GameTooltip:SetOwner(owner,anchor) self.owner,self.anchor=owner,anchor; self.lines={}; self.spellID=nil end
function GameTooltip:SetSpellByID(id) self.spellID=id; local spell=Mock:SpellData(id); self:SetText(spell and spell.name or ""); return spell~=nil end
function GameTooltip:SetHyperlink(link) self.hyperlink=link; self.spellID=tonumber(link:match("spell:(%d+)")) end
function GameTooltip:AddLine(text) self.lines=self.lines or {}; self.lines[#self.lines+1]=text end
UIParent=CreateFrame("Frame","UIParent")
UIParent:SetSize(1920,1080)
-- Model the live iteration used by Blizzard's CloseSpecialWindows, including
-- OnHide scripts that alter UISpecialFrames during this same Escape dispatch.
-- Source: Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua.
function CloseSpecialWindows()
  local closed
  for _,name in pairs(UISpecialFrames) do
    local target=_G[name]
    if target and target:IsShown() then target:Hide(); closed=1 end
  end
  return closed
end
function Mock:KeyDown(key)
  self.downKeys[key]=true
  local recipient
  for index=#self.frames,1,-1 do
    local frame=self.frames[index]
    if frame.keyboard and frame:IsVisible() and frame.scripts.OnKeyDown then recipient=frame; break end
  end
  if recipient then recipient.scripts.OnKeyDown(recipient,key) end
  if not recipient or recipient.propagate~=false then
    self.propagatedKeys[#self.propagatedKeys+1]=key
    if key=="ESCAPE" then
      if self.focus and self.focus:IsVisible() and self.focus.scripts.OnEscapePressed then
        self.focus.scripts.OnEscapePressed(self.focus)
      else CloseSpecialWindows() end
    end
  end
end
function Mock:KeyUp(key)
  self.downKeys[key]=nil
  for index=#self.frames,1,-1 do
    local frame=self.frames[index]
    if frame.keyboard and frame:IsVisible() and frame.scripts.OnKeyUp then
      frame.scripts.OnKeyUp(frame,key)
      if frame.propagate==false then break end
    end
  end
end
DEFAULT_CHAT_FRAME={AddMessage=function(_,msg) Mock.messages[#Mock.messages+1]=msg end}

function InCombatLockdown() return Mock.combat end
function GetBuildInfo() return Mock.build,Mock.buildNumber,"Oct 30 2026",16001 end
function GetLocale() return Mock.locale end
function UnitClass() return "Druid",Mock.class,11 end
function UnitName() return "Tester","Realm" end
function GetRealmName() return "Realm" end
function UnitGUID() return "Player-1-123" end
function UnitLevel() return 60 end
function UnitRace() return "Night Elf","NightElf",4 end
function UnitFactionGroup() return "Alliance" end
function UnitExists(unit) return unit=="player" or unit=="target" end
function GetTime() return Mock.now end
function date() return "2026-10-31" end
function time() return 1793462400 end
function GetCVar(k) return Mock.cvars[k] end
function GetCVarBool(k) return Mock.cvars[k]=="1" end
function SetCVar(k,v) Mock:Write("cvar",k,v); Mock.cvars[k]=tostring(v); return true end
C_CVar={GetCVar=GetCVar,GetCVarBool=GetCVarBool,SetCVar=SetCVar,GetCVarInfo=function(k) return Mock.cvars[k],"0",false,false,false,false,false end}
function GetModifiedClick(k) return Mock.modified[k] or "NONE" end
function SetModifiedClick(k,v) Mock:Write("modified",k,v); Mock.modified[k]=v end
function IsShiftKeyDown() return Mock.shift end
function IsControlKeyDown() return Mock.ctrl end
function IsAltKeyDown() return Mock.alt end
function IsModifierKeyDown() return Mock.shift or Mock.ctrl or Mock.alt end
function IsKeyDown(key)
  if key=="LSHIFT" or key=="RSHIFT" then return Mock.shift end
  if key=="LCTRL" or key=="RCTRL" then return Mock.ctrl end
  if key=="LALT" or key=="RALT" then return Mock.alt end
  return Mock.downKeys[key] or false
end
function IsMouseButtonDown(key) return Mock.downKeys[key] or Mock.downKeys[({LeftButton="BUTTON1",RightButton="BUTTON2",MiddleButton="BUTTON3",Button4="BUTTON4",Button5="BUTTON5"})[key]] or false end
function GetCurrentBindingSet() return Mock.bindingSet end
function SetBinding(key,action) Mock:Write("binding",key,action); Mock.bindings[key]=action; return true end
function SetBindingClick(key,button,mouse) return SetBinding(key,"CLICK "..button..":"..(mouse or "LeftButton")) end
function GetBindingAction(key) return Mock.bindings[key] or "" end
function GetBindingKey(action) local found={}; for k,v in pairs(Mock.bindings) do if v==action then found[#found+1]=k end end; return unpack(found) end
function GetNumBindings() local count=0; for _ in pairs(Mock.bindings) do count=count+1 end; return count end
function GetBinding(index) local keys={}; for k in pairs(Mock.bindings) do keys[#keys+1]=k end; table.sort(keys); local key=keys[index]; return key and Mock.bindings[key],"GENERAL",key end
local function cloneMap(t) local out={}; for k,v in pairs(t) do out[k]=v end; return out end
Mock.bindingSets={[1]=cloneMap(Mock.bindings),[2]={C="TOGGLECHARACTER0",I="OPENALLBAGS"}}
function SaveBindings(set) Mock:Write("savebindings",set); Mock.bindingSets[set]=cloneMap(Mock.bindings); Mock.bindingSet=set end
function LoadBindings(set) Mock:Write("loadbindings",set); Mock.bindings=cloneMap(Mock.bindingSets[set] or {}); Mock.bindingSet=set end
function GetBindingText(key) return key end
function SetOverrideBindingClick(owner,priority,key,button,mouse) return SetBindingClick(key,button,mouse) end
function ClearOverrideBindings(owner) Mock:Write("clearoverrides") end
function RegisterStateDriver(frame,state,condition) Mock:Write("statedriver",state,condition); frame.stateDrivers=frame.stateDrivers or {}; frame.stateDrivers[state]=condition end
function UnregisterStateDriver(frame,state) Mock:Write("unstatedriver",state); if frame.stateDrivers then frame.stateDrivers[state]=nil end end

function GetNumMacros() local a,c=0,0; for i in pairs(Mock.macros) do if i<=120 then a=a+1 else c=c+1 end end; return a,c end
function GetMacroInfo(index) local m=Mock.macros[index]; if type(index)=="string" then for _,x in pairs(Mock.macros) do if x.name==index then m=x end end end; if m then return m.name,m.icon,m.body end end
function GetMacroIndexByName(name) for i,m in pairs(Mock.macros) do if m.name==name then return i end end; return 0 end
function CreateMacro(name,icon,body,character)
  Mock:Write("createmacro",name)
  if #body>255 then error("Macro body exceeds 255 bytes") end
  local start,last=character and 121 or 1,character and 150 or 120
  for i=start,last do if not Mock.macros[i] then Mock.macros[i]={name=name,icon=icon,body=body}; return i end end
  error("Macro capacity exceeded")
end
function EditMacro(index,name,icon,body)
  Mock:Write("editmacro",index)
  if type(index)=="string" then index=GetMacroIndexByName(index) end
  local m=assert(Mock.macros[index],"Unknown macro")
  if body and #body>255 then error("Macro body exceeds 255 bytes") end
  m.name=name or m.name; m.icon=icon or m.icon; m.body=body or m.body; return index
end
function DeleteMacro(index)
  Mock:Write("deletemacro",index)
  if type(index)=="string" then index=GetMacroIndexByName(index) end
  Mock.macros[index]=nil
  -- Real client compacts each macro bank after deletion.
  local last=index<=120 and 120 or 150
  for i=index,last-1 do Mock.macros[i]=Mock.macros[i+1] end
  Mock.macros[last]=nil
end
C_Macro={GetMacroName=function(i) local m=Mock.macros[i]; return m and m.name end}

function GetSpellInfo(id) local s=Mock:SpellData(id); if s then return s.name,s.rank,s.icon or 123,0,0,40,s.id end end
function IsSpellKnown(id) return Mock:Spell(id)~=nil end
IsPlayerSpell=IsSpellKnown
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo(i) return "Druid",123,0,#Mock.spells,false,0 end
function GetSpellBookItemInfo(i) local s=Mock.spells[i]; if s then return "SPELL",s.id end end
function GetSpellBookItemName(i) local s=Mock.spells[i]; if s then return s.name,s.rank end end
function IsPassiveSpell(id,bank) local s=bank and Mock.spells[id] or Mock:Spell(id); return s and s.passive or false end
C_Spell={GetSpellInfo=function(id) local s=Mock:SpellData(id); if s then return {name=s.name,spellID=s.id,iconID=s.icon or 123,castTime=0,minRange=0,maxRange=40} end end,GetSpellName=function(id) local s=Mock:SpellData(id); return s and s.name end,IsSpellPassive=IsPassiveSpell}
C_SpellBook={
 GetNumSpellBookSkillLines=function() return 1 end,
 GetSpellBookSkillLineInfo=function() return {name="Druid",itemIndexOffset=0,numSpellBookItems=#Mock.spells,offSpecID=0} end,
 GetSpellBookItemInfo=function(index,bank) local s=(bank==Enum.SpellBookSpellBank.Pet and Mock.petSpells or Mock.spells)[index]; if s then return {itemType=Enum.SpellBookItemType.Spell,actionID=s.id,spellID=s.id,name=s.name,isPassive=s.passive} end end,
 GetSpellBookItemName=function(index) local s=Mock.spells[index]; if s then return s.name,s.rank end end,
 IsSpellKnown=IsSpellKnown,IsSpellInSpellBook=IsSpellKnown,IsSpellBookItemPassive=function(index) return Mock.spells[index] and Mock.spells[index].passive or false end,
 HasPetSpells=function() return #Mock.petSpells end,
}
function GetNumShapeshiftForms() return #Mock.forms end
function GetShapeshiftFormInfo(index) local f=Mock.forms[index]; if f then return 123,false,true,f.id end end
function GetShapeshiftForm() return Mock.formIndex or 0 end
function GetShapeshiftFormID() return Mock.formIndex or 0 end
function IsStealthed() return Mock.stealth or false end

function GetInventoryItemID(unit,slot) return Mock.equipment[slot] end
function GetInventoryItemTexture(unit,slot) return Mock.equipment[slot] and 123 end
function GetItemInfo(id) local x=Mock.itemInfo[id]; if x then return x.name,"item:"..id,1,60,1,x.kind or "Consumable",x.subkind or "Potion",20,x.equipLoc or "",123,1,0,0 end end
function GetItemSpell(id) local x=Mock.itemInfo[id]; if x and x.effect then return x.effect,x.spellID or id+100000 end end
function GetItemCount(id) local count=0; for _,bag in pairs(Mock.bagItems) do for _,x in pairs(bag) do if x.id==id then count=count+(x.count or 1) end end end; return count end
function IsEquippableItem(id) local x=Mock.itemInfo[id]; return x and x.equipLoc and x.equipLoc~="" or false end
function EquipItemByName(id,slot) Mock:Write("equip",id,slot); Mock.equipment[slot]=id end
C_Item={GetItemInfo=GetItemInfo,GetItemSpell=GetItemSpell,GetItemCount=GetItemCount,IsEquippableItem=IsEquippableItem,EquipItemByName=EquipItemByName,RequestLoadItemDataByID=function(id)
  Mock.itemRequests[id]=(Mock.itemRequests[id] or 0)+1
  if Mock.onItemRequest then Mock.onItemRequest(id) end
end,IsItemDataCachedByID=function(id) return Mock.itemInfo[id]~=nil end}
function GetContainerNumSlots(bag) local a=Mock.bagItems[bag] or {}; local max=0; for i in pairs(a) do max=math.max(max,i) end; return max end
function GetContainerItemID(bag,slot) local x=(Mock.bagItems[bag] or {})[slot]; return x and x.id end
function GetContainerItemInfo(bag,slot) local x=(Mock.bagItems[bag] or {})[slot]; if x then return 123,x.count or 1,false,1,false,false,"item:"..x.id,false,false,x.id end end
C_Container={GetContainerNumSlots=GetContainerNumSlots,GetContainerItemID=GetContainerItemID,GetContainerItemInfo=function(bag,slot) local x=(Mock.bagItems[bag] or {})[slot]; if x then return {itemID=x.id,stackCount=x.count or 1,iconFileID=123,isLocked=false,hyperlink="item:"..x.id} end end}
function GetActionInfo(slot) local a=Mock.actions[slot]; if a then return unpack(a) end end
function PickupMacro(index) Mock.cursor={"macro",index} end
function PickupSpell(id) Mock.cursor={"spell",id} end
function PickupAction(slot) Mock.cursor=Mock.actions[slot]; Mock.actions[slot]=nil end
function PlaceAction(slot) Mock:Write("action",slot); Mock.actions[slot]=Mock.cursor; Mock.cursor=nil end
function ClearCursor() Mock.cursor=nil end
function GetCursorInfo() if Mock.cursor then return unpack(Mock.cursor) end end
C_Spell.PickupSpell=PickupSpell
C_SpellBook.PickupSpellBookItem=function(i) PickupSpell(Mock.spells[i].id) end
C_Timer={After=function(seconds,callback) Mock.timers[#Mock.timers+1]={due=Mock.now+seconds,callback=callback} end}
Settings={RegisterCanvasLayoutCategory=function(frame,name)
  local category={frame=frame,name=name,id=#Mock.settingsCategories+1,GetID=function(self) return self.id end}
  Mock.settingsCategories[#Mock.settingsCategories+1]=category
  return category
end,RegisterAddOnCategory=function(category) Mock.addonCategories[#Mock.addonCategories+1]=category end,OpenToCategory=function(category) Mock.openSettingsCategory=category end}
function InterfaceOptions_AddCategory(panel) Mock.legacyCategories[#Mock.legacyCategories+1]=panel end
function InterfaceOptionsFrame_OpenToCategory() end
function HideUIPanel(panel) if panel then panel:Hide() end end
function strtrim(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
function wipe(t) for k in pairs(t) do t[k]=nil end; return t end
function tContains(t,value) for _,v in pairs(t) do if v==value then return true end end; return false end
function hooksecurefunc(owner,method,callback)
  if type(owner)=="string" then callback=method; method=owner; owner=_G end
  local original=assert(owner[method],"Cannot hook nonexistent method "..method)
  owner[method]=function(...)
    local results={original(...)}
    callback(...)
    return unpack(results)
  end
end
function Mock:CreateGameMenu(modern)
  local menu=CreateFrame("Frame","GameMenuFrame",UIParent)
  menu:Hide()
  if modern then
    menu.activeButtons={}
    menu.buttonPool={EnumerateActive=function()
      local index=0
      return function() index=index+1; return menu.activeButtons[index] end
    end}
    function menu:AddButton(text,callback)
      local button=CreateFrame("Button",nil,self,"UIPanelButtonTemplate")
      button:SetText(text); button:SetScript("OnClick",callback)
      button.layoutIndex=#self.activeButtons+1
      self.activeButtons[#self.activeButtons+1]=button
      return button
    end
    function menu:InitButtons()
      for _,button in ipairs(self.activeButtons) do button:Hide() end
      self.activeButtons={}
      self:AddButton("Options",function() end)
      self:AddButton(ADDONS or "AddOns",function() end)
      self:AddButton("Logout",function() end)
    end
    function menu:MarkDirty() self.layoutDirty=true end
    menu:SetScript("OnShow",function(self) self:InitButtons() end)
  end
  return menu
end
function PlaySound() end
function GetCursorPosition() return 0,0 end
function PanelTemplates_SelectTab(tab) tab.selected=true end
function PanelTemplates_DeselectTab(tab) tab.selected=false end
function PanelTemplates_SetNumTabs(frame,num) frame.numTabs=num end
function PanelTemplates_SetTab(frame,id) frame.selectedTab=id end
function PanelTemplates_TabResize() end
