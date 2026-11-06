local _, K = ...
K.ActionBars={}
local A=K.ActionBars

-- Read the button that actually owns a key. Never write another addon's
-- attributes, state drivers or override bindings, or infer slots from its IDs.
local bars={
 {page=6,button="MultiBarBottomLeftButton"},{page=5,button="MultiBarBottomRightButton"},
 {page=3,button="MultiBarRightButton"},{page=4,button="MultiBarLeftButton"},
 {page=13,button="MultiBar5Button"},{page=14,button="MultiBar6Button"},{page=15,button="MultiBar7Button"},
}
local function read(fn,...)
 if type(fn)~="function" then return end
 local ok,a,b=pcall(fn,...); if ok then return a,b end
end
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function slot(value)
 return public(value) and type(value)=="number" and value>0 and value%1==0 and value<1000000000 and value or nil
end
local function provider(name)
 if name:match("^BT4Button%d+$") then return "Bartender4" end
 if name:match("^ElvUI_Bar%d+Button%d+$") then return "ElvUI" end
 if name:match("^DominosActionButton%d+$") then return "Dominos" end
 if name:match("^ActionButton%d+$") or name:match("^MultiBarBottomLeftButton%d+$") or name:match("^MultiBarBottomRightButton%d+$")
  or name:match("^MultiBarRightButton%d+$") or name:match("^MultiBarLeftButton%d+$") or name:match("^MultiBar[567]Button%d+$")
  or name:match("^OverrideActionBarButton%d+$") or name:match("^ExtraActionButton%d+$") then return "Blizzard" end
end
local function attribute(button,name)
 if type(button.GetAttribute)~="function" then return nil,true end
 local ok,value=pcall(button.GetAttribute,button,name)
 return value,ok
end
local function buttonSlot(button)
 if not button then return end
 -- LibActionButton's current state can be a custom spell/macro. Its cached
 -- action field must not be consulted when GetAction reports another type.
 if type(button.GetAction)=="function" then
  local kind,value=read(button.GetAction,button)
  if public(kind) and kind=="action" then return slot(value),true end
  return nil,true
 end
 local kind,readable=attribute(button,"type")
 if not readable or not public(kind) or kind~=nil and kind~="action" then return nil,true end
 local value,known=attribute(button,"action")
 if not known or not public(value) then return nil,true end
 if value~=nil then return slot(value),true end
 local cached=button.action
 if not public(cached) or cached~=nil then return slot(cached),true end
 return nil,false
end
local function nativeSlot(button,fallback)
 if not button then return fallback end
 local at,explicit=buttonSlot(button)
 if at then return at end
 -- Empty/uninitialized native frames can use Blizzard's documented page
 -- mapping. An explicit custom type or unreadable LAB state cannot.
 if not explicit then return fallback end
end
function A:ButtonSlot(name,mouse)
 local parentName=name:match("^(.-)Hotkey$")
 local owner=provider(parentName or name)
 if not owner then return nil,nil,false end
 if mouse~="LeftButton" and mouse~="HOTKEY" and mouse~="Keybind" then return nil,owner,true end
 local button=_G[name]
 if parentName then
  -- Dominos routes hotkeys through a child inheriting its parent's live slot.
  local parent=_G[parentName]
  if not button or not parent or read(button.GetParent,button)~=parent
   or read(button.GetAttribute,button,"type")~="action" or read(button.GetAttribute,button,"useparent-action")~=true then return nil,owner,true end
  return buttonSlot(parent),"Dominos",true
 end
 return buttonSlot(button),owner,true
end
function A:StanceSlot(command)
 local index=tonumber(command:match("^SHAPESHIFTBUTTON(%d+)$"))
 if index and index>=1 and index<=10 then return index,"Blizzard",true end
 local name,mouse=command:match("^CLICK ([%w_]+):([%w]+)$")
 if not name then return end
 local owner
 index=tonumber(name:match("^StanceButton(%d+)$"))
 if index then owner="Blizzard"
 else
  index=tonumber(name:match("^BT4StanceButton(%d+)$"))
  if index then owner="Bartender4"
  else
   index=tonumber(name:match("^ElvUI_StanceBarButton(%d+)$"))
   if index then owner="ElvUI" end
  end
 end
 if not owner then return end
 -- These named buttons use Blizzard's StanceButtonTemplate and SetID(N).
 -- Their ID is a GetShapeshiftFormInfo index, never a native action slot.
 -- HotKey text and action-bar Hotkey children are not stance click targets.
 if mouse~="LeftButton" or index<1 or index>10 then return nil,owner,true end
 local button=_G[name]
 local live=slot(read(button and button.GetID,button))
 if live~=index then return nil,owner,true end
 return live,owner,true
end
function A:Slot(command,page,pageType)
 local name,mouse=command:match("^CLICK ([%w_]+):([%w]+)$")
 if name then return self:ButtonSlot(name,mouse) end
 local bar,index=command:match("^ELVUIBAR(%d+)BUTTON(%d+)$")
 bar,index=tonumber(bar),tonumber(index)
 if bar and (bar==2 or bar>=7 and bar<=10) and index and index>=1 and index<=12 then
  return buttonSlot(_G["ElvUI_Bar"..bar.."Button"..index]),"ElvUI",true
 end
 index=tonumber(command:match("^ACTIONBUTTON(%d+)$"))
 if index and index>=1 and index<=12 then
  if pageType=="Vehicle" or pageType=="Override" or pageType=="TempShapeshift" then
   local override=_G["OverrideActionBarButton"..index]
   if override and read(override.IsShown,override) then return nativeSlot(override,(page-1)*12+index),"Blizzard",true end
   return (page-1)*12+index,"Blizzard",true
  end
  return nativeSlot(_G["ActionButton"..index],(page-1)*12+index),"Blizzard",true
 end
 bar,index=command:match("^MULTIACTIONBAR(%d+)BUTTON(%d+)$")
 bar,index=tonumber(bar),tonumber(index)
 if bars[bar] and index and index>=1 and index<=12 then
  return nativeSlot(_G[bars[bar].button..index],(bars[bar].page-1)*12+index),"Blizzard",true
 end
 index=tonumber(command:match("^EXTRAACTIONBUTTON(%d+)$"))
 if index then return buttonSlot(_G["ExtraActionButton"..index]),"Blizzard",true end
end
function A:Route(command,key,page,pageType,useOverrides)
 local effective=command
 if useOverrides then
  local result=read(GetBindingAction,key,true)
  if not public(result) or type(result)~="string" then
   return {key=key,command=command,error="The active binding cannot be read. Try again outside combat."}
  end
  effective=result
 end
 local stance,owner,recognized=self:StanceSlot(effective)
 local stanceRoute=recognized
 local at
 if not recognized then at,owner,recognized=self:Slot(effective,page,pageType) end
 local route={key=key,command=command,effectiveCommand=effective,slot=at,stanceSlot=stance,provider=owner}
 if (recognized and not at and not stance) or (effective~=command and not at and not stance) or (command=="" and effective~="" and not stance) then
  route.error="This key is controlled by "..(owner or "another addon").." without a readable "..(stanceRoute and "stance" or "action").." slot. Edit it in that addon's binding settings."
 end
 return route
end
