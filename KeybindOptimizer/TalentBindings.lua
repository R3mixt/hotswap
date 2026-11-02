local _,K=...
K.TalentBindings={}
local T=K.TalentBindings

-- A shared key is an explicit ordered choice, never a guess based on the
-- character's largest talent tree. Classic hybrid builds can learn both.
function T:IsEligible(action)
 return action and not action.kind and not action.builtin and not action.combo
  and not action.focusOf and action.targeting~="focus" and (action.form or "all")=="all"
end
function T:Definitions(settings)
 local _,class=UnitClass("player")
 local flavor=K.API:GetFlavor(settings)
 local map={}
 for _,def in ipairs(K.Profiles:Get(class,flavor)) do map[def.id]=def end
 return map,class,flavor
end
function T:ListCandidates(action,settings)
 settings=settings or K:GetSettings()
 local definitions,class,flavor=self:Definitions(settings)
 local primary=type(action)=="table" and action.id or action
 if not self:IsEligible(definitions[primary]) then return {} end
 local result,book={},K.API:GetCachedSpellbook()
 for id,def in pairs(definitions) do
  local _,talent=K.LibraryData:Classify(class,def,flavor)
  if self:IsEligible(def) and (id==primary or talent) then
   local known=K.API:Resolve(def,book)
   local display=known or K.API:ResolveDisplay(def)
   result[#result+1]={id=id,label=display and display.name or def.name,known=known~=nil,icon=display and display.icon}
  end
 end
 table.sort(result,function(a,b) return a.label==b.label and a.id<b.id or a.label<b.label end)
 return result
end
function T:GetChoices(actionID,settings)
 settings=settings or K:GetSettings()
 return K.Copy((settings.talentAlternatives or {})[actionID] or {actionID})
end
function T:ValidateSettings(settings)
 if type(settings.talentAlternatives or {})~="table" then return false,"Talent choices must be a table." end
 local definitions,class,flavor=self:Definitions(settings)
 for id,choices in pairs(settings.talentAlternatives or {}) do
  if not self:IsEligible(definitions[id]) or type(choices)~="table" or #choices<1 or #choices>8 then return false,"Invalid talent choices for "..tostring(id).."." end
  local seen,count={},0
  local override=(settings.actionOverrides or {})[id]
  for index,source in pairs(choices) do
   count=count+1
   if type(index)~="number" or index%1~=0 or index<1 or index>#choices or type(source)~="string" then return false,"Talent choices must be an ordered list." end
   local def=definitions[source]
   local _,talent=K.LibraryData:Classify(class,def,flavor)
   if seen[source] or not self:IsEligible(def) or (source~=id and not talent) then return false,"Invalid or duplicate talent choice: "..tostring(source).."." end
   if override and override.targetMode and K.Library then
    local supported=false
    for _,mode in ipairs(K.Library:TargetModes(def)) do if mode==override.targetMode then supported=true end end
    if not supported then return false,"Target mode "..override.targetMode.." is not supported by every talent choice. Choose Default targeting first." end
   end
   seen[source]=true
  end
  if count~=#choices then return false,"Talent choices must be consecutive." end
  if override and (override.replacement or override.spellID) then return false,"Reset the replacement or fixed rank before adding talent choices." end
 end
 return true
end
function T:SetChoices(actionID,choices)
 if K.Engine and K.Engine.busy then return false,"Wait for the current operation to finish." end
 local settings=K.Copy(K:GetSettings())
 settings.talentAlternatives=settings.talentAlternatives or {}
 local resetTarget
 if type(choices)=="table" and #choices==0 then
  settings.talentAlternatives[actionID]=nil
  -- A removed primary may have a different target capability from the last
  -- selected alternative. Reset must not strand an invalid target override.
  local override=(settings.actionOverrides or {})[actionID]
  if override and override.targetMode and not override.replacement then
   local definitions=self:Definitions(settings)
   local primary=definitions[actionID]
   if primary and K.Library then
    local supported=false
    for _,mode in ipairs(K.Library:TargetModes(primary)) do if mode==override.targetMode then supported=true end end
    if not supported then override.targetMode=nil; resetTarget=true end
   end
  end
 else settings.talentAlternatives[actionID]=K.Copy(choices) end
 local ok,why=self:ValidateSettings(settings); if not ok then return false,why end
 K.db.settings.talentAlternatives=settings.talentAlternatives
 if resetTarget then K.db.settings.actionOverrides=settings.actionOverrides end
 K.dirty=true; K:InvalidatePreview()
 return true,resetTarget and "Talent choices reset with Default targeting. Apply & save to use them." or "Talent choices staged. Apply & save to use them."
end
function T:Resolve(def,settings,book)
 local choices=(settings.talentAlternatives or {})[def.id]
 if not choices then return K.Copy(def) end
 local definitions=self:Definitions(settings)
 local chosen,known,hasHelpful
 for _,id in ipairs(choices) do
  local candidate=definitions[id]
  if self:IsEligible(candidate) then
   if candidate.targeting=="help" and not candidate.noSelf then hasHelpful=true end
   local learned=K.API:Resolve(candidate,book)
   if not chosen or (not known and learned) then chosen,known=candidate,learned end
  end
 end
 if not chosen then return K.Copy(def) end -- Invalid input is rejected by plan preflight.
 local action=K.Copy(chosen)
 action.id,action.key,action.form,action.priority=def.id,def.key,def.form,def.priority
 action.librarySourceID=chosen.id
 action.talentPrimaryID=def.id
 action.talentSelectionID=known and chosen.id or nil
 action.talentChoices=K.Copy(choices)
 action.talentHasHelpful=hasHelpful and true or nil
 return action
end
