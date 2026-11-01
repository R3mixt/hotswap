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
function MultiActionBar_Update() Mock.barUpdates=(Mock.barUpdates or 0)+1 end
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
local originalDeleteMacro=DeleteMacro
function DeleteMacro(index)
  if type(index)=="string" then index=GetMacroIndexByName(index) end
  local last=index<=120 and 120 or 150
  originalDeleteMacro(index)
  for slot,action in pairs(Mock.actions) do
    if action[1]=="macro" then
      if action[2]==index then Mock.actions[slot]=nil
      elseif action[2]>index and action[2]<=last then action[2]=action[2]-1 end
    end
  end
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
