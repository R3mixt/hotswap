local _, K = ...
K.Availability={}
local A=K.Availability

-- Availability is presentation/planning metadata. Only the live spellbook
-- grants knowledge; a catalog talent flag never makes an action executable.
local function spell(action)
 return action and (not action.kind or action.kind=="spell") and not action.builtin
end
function A:Annotate(action,class,flavor)
 if not action then return end
 if not spell(action) then
  action.talent=nil; action.availabilityState=nil; action.availabilityLabel=nil
  return action
 end
 local definition=action
 if action.librarySourceID then definition={id=action.librarySourceID,pet=action.pet,petSpell=action.petSpell} end
 local _,talent
 if K.LibraryData then _,talent=K.LibraryData:Classify(class,definition,flavor) end
 action.talent=talent and true or false
 action.availabilityState=action.known and "ready" or (action.talent and "talent" or "unlearned")
 -- Unknown talent abilities can also be awaiting training/data. Do not claim
 -- a talent was unselected unless a live talent-rank query proves it.
 action.availabilityLabel=action.known and "Ready" or (action.talent and "Talent not learned" or "Not learned")
 return action
end
function A:IsHidden(action,settings)
 if not spell(action) or action.known then return false end
 settings=settings or {}
 return settings.hideUnavailableSpells==true or (settings.adaptTalents==true and action.talent==true)
end
function A:Status(action)
 if not spell(action) then return end
 return action.availabilityState,action.availabilityLabel
end
