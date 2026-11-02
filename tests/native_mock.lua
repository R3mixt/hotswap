-- Native Blizzard bar surfaces and pending-job helpers. This models data flow,
-- not protected execution inside a real WoW client.
Mock.actionToggles={false,false,false,false,false,false,false}
Mock.actionPage=1
for _,name in ipairs({"MainActionBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarRight","MultiBarLeft","MultiBar5","MultiBar6","MultiBar7"}) do
  _G[name]=CreateFrame("Frame",name,UIParent)
end
function GetActionBarToggles() return unpack(Mock.actionToggles) end
function SetActionBarToggles(...)
  Mock:Write("actiontoggles",...); Mock.actionToggles={...}
end
function MultiActionBar_Update()
  Mock.barUpdates=(Mock.barUpdates or 0)+1
  -- Mirror Blizzard's visibility controller, including its normal-bar gate.
  -- Frame presence is a capability; a hidden bar is still available for use.
  for index,name in ipairs({"MultiBarBottomLeft","MultiBarBottomRight","MultiBarRight","MultiBarLeft","MultiBar5","MultiBar6","MultiBar7"}) do
    local frame=_G[name]
    if frame then frame:SetShown(MainActionBar:IsShown() and Mock.actionToggles[index] and true or false) end
  end
end
function GetActionBarPage() return Mock.actionPage end
function ChangeActionBarPage(page) Mock:Write("actionpage",page); Mock.actionPage=page end
C_ActionBar={GetActionBarPage=GetActionBarPage,SetActionBarPage=ChangeActionBarPage}
function PickupSpell(id) Mock.cursor={"spell",id,"spell"} end
C_Spell.PickupSpell=PickupSpell
function PickupItem(id) Mock.cursor={"item",id} end
C_Item.PickupItem=PickupItem
function PickupMacro(index) Mock.cursor={"macro",index} end
function PickupAction(slot)
  Mock:Write("pickupaction",slot); Mock.cursor=Mock.actions[slot]; Mock.actions[slot]=nil
end
function PlaceAction(slot)
  Mock:Write("action",slot)
  Mock.actions[slot]=Mock.cursor and {unpack(Mock.cursor)} or nil
  Mock.cursor=nil
end
-- Macro indices are positions in separate sorted banks, not stable IDs. The
-- client preserves action references when creation, renaming or deletion moves
-- a macro. Keep those references by object identity while rebuilding the banks.
local function macroReferences()
  local refs={}
  for slot,action in pairs(Mock.actions) do
    if action[1]=="macro" then refs[#refs+1]={slot=slot,macro=Mock.macros[action[2]]} end
  end
  if Mock.cursor and Mock.cursor[1]=="macro" then refs[#refs+1]={cursor=true,macro=Mock.macros[Mock.cursor[2]]} end
  return refs
end
local function sortMacroBanks(refs)
  local indices={}
  for _,bounds in ipairs({{1,MAX_ACCOUNT_MACROS},{MAX_ACCOUNT_MACROS+1,MAX_ACCOUNT_MACROS+MAX_CHARACTER_MACROS}}) do
    local entries={}
    for index=bounds[1],bounds[2] do
      if Mock.macros[index] then entries[#entries+1]={macro=Mock.macros[index],previous=index} end
      Mock.macros[index]=nil
    end
    table.sort(entries,function(a,b)
      local x,y=a.macro.name:lower(),b.macro.name:lower()
      return x==y and a.previous<b.previous or x<y
    end)
    for offset,entry in ipairs(entries) do
      local index=bounds[1]+offset-1
      Mock.macros[index]=entry.macro; indices[entry.macro]=index
    end
  end
  for _,ref in ipairs(refs) do
    local index=ref.macro and indices[ref.macro]
    if ref.cursor then Mock.cursor=index and {"macro",index} or nil
    elseif index then Mock.actions[ref.slot][2]=index
    else Mock.actions[ref.slot]=nil end
  end
  return indices
end
local originalCreateMacro,originalEditMacro,originalDeleteMacro=CreateMacro,EditMacro,DeleteMacro
function CreateMacro(...)
  local refs=macroReferences(); local index=originalCreateMacro(...)
  local macro=Mock.macros[index]; local indices=sortMacroBanks(refs)
  return indices[macro]
end
function EditMacro(index,...)
  if type(index)=="string" then index=GetMacroIndexByName(index) end
  local refs=macroReferences(); local macro=Mock.macros[index]
  originalEditMacro(index,...)
  return sortMacroBanks(refs)[macro]
end
function DeleteMacro(index)
  local refs=macroReferences(); originalDeleteMacro(index); sortMacroBanks(refs)
end
function Mock:Drain(limit)
  local frames=0
  while TestAddon.Engine.busy and frames<(limit or 4000) do self:Advance(0.016); frames=frames+1 end
  assert(not TestAddon.Engine.busy,"Setup job did not finish within its bounded test budget")
  local result=TestAddon.Engine.lastJob
  return result and result.ok,result and result.message,frames
end
function Mock:NativePage()
  if self.vehiclePage then return self.vehiclePage end
  if self.overridePage then return self.overridePage end
  if self.actionPage~=1 then return self.actionPage end
  local form=self.forms[self.formIndex or 0]
  local pages={[768]=7,[5487]=9,[9634]=9,[24858]=10}
  return form and pages[form.id] or 1
end
function Mock:NativeActionFor(key)
  local command=self.bindings[key] or ""
  local button=tonumber(command:match("^ACTIONBUTTON(%d+)$"))
  if button then return self.actions[(self:NativePage()-1)*12+button] end
  local bank,index=command:match("^MULTIACTIONBAR(%d+)BUTTON(%d+)$")
  if bank then
    local pages={6,5,3,4,13,14,15}
    return self.actions[(pages[tonumber(bank)]-1)*12+tonumber(index)]
  end
  local name=command:match("^MACRO (.+)$")
  if name then return {"macro",GetMacroIndexByName(name)} end
end
