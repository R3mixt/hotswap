local _,K=...
K.AvailabilityEngine={}
local A=K.AvailabilityEngine
local function combat() return InCombatLockdown and InCombatLockdown() end
local function spell(a) return a and not a.kind and not a.builtin end
function A:Handles(plan)
 local settings=plan and plan.settings or {}
 return settings.hideUnavailableSpells==true or settings.adaptTalents==true or next(settings.talentAlternatives or {})~=nil
end
function A:HasUnboundLearnedSpells(plan,book)
 book=book or K.API:GetCachedSpellbook()
 local covered,definitions={},nil
 local function cover(def)
  for _,name in pairs({def.name,def.spellName,def.displayName}) do if name then covered[name]=true end end
  local learned=K.API:Resolve(def,book)
  if learned and not learned.passive then covered[learned.name]=true end
  if def.rankFamily then
   for _,id in ipairs(def.spellIDs or {}) do
    local entry=book.byID[id]; if entry and not entry.passive then covered[entry.name]=true end
   end
   for _,name in ipairs(def.spellNames or {}) do covered[name]=true end
  end
 end
 for _,action in ipairs(plan and plan.actions or {}) do if spell(action) and action.key then
  cover(action)
  -- An intentionally configured lower-priority talent remains covered by its
  -- shared key policy; learning it does not mean the player forgot to bind it.
  if action.talentChoices then
   if not definitions and K.TalentBindings then definitions=K.TalentBindings:Definitions(plan.settings) end
   for _,id in ipairs(action.talentChoices) do if definitions and definitions[id] then cover(definitions[id]) end end
  end
 end end
 local missing={}
 for _,entry in ipairs(book.list or {}) do
  if not entry.passive and not covered[entry.name] then missing[#missing+1]=entry.name end
 end
 table.sort(missing)
 return #missing>0,missing
end
local function same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b end
 for key,value in pairs(a) do if not same(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end
 return true
end
local function oldContent(action)
 if action.nativeHidden then return false end
 if action.body and action.macroName then return {kind="macro",name=action.macroName,body=action.body} end
 if action.known and action.spellID then return {kind="spell",id=action.spellID} end
 return false
end
local function ownedMacro(action)
 if not action.macroName or not action.body then return false end
 local index,name=K.Macros:FindExact(action.macroName,action.body)
 return index and K.db.ownedMacros[name]==action.body or false
end
local function copyInto(target,source)
 for key in pairs(target) do target[key]=nil end
 for key,value in pairs(source) do target[key]=K.Copy(value) end
end
local placementFields={"key","selfKey","form","barSlot","nativeSlot","nativeCommand","nativeOverflow","priority","targetMode","nativeBlockAlt"}
function A:Resolve(action,plan,book,forms)
 local updated=K.TalentBindings and K.TalentBindings:Resolve(action,plan.settings,book) or K.Copy(action)
 for _,field in ipairs(placementFields) do updated[field]=action[field] end
 if updated.talentHasHelpful then updated.nativeBlockAlt=not (updated.targeting=="help" and not updated.noSelf) or nil end
 updated.known=false; updated.spellID=nil; updated.spellName=nil
 updated.body=nil; updated.nativeMacro=nil; updated.nativePending=nil; updated.macroName=nil; updated.macroIndex=nil
 local exact=updated.selectedSpellID and K.API:ResolveExact(updated.selectedSpellID,book)
 local learned
 if updated.selectedSpellID then
  learned=exact and exact.known and not exact.passive and exact or nil
  updated.selectedRank=exact and exact.rank or updated.selectedRank
 else learned=K.API:Resolve(updated,book); if learned and learned.passive then learned=nil end end
 if updated.targeting=="form" then
  local form=forms[updated.formType or ""]
  learned=form and {id=form.spellID,name=form.name,icon=form.icon} or nil
 end
 if learned then
  updated.known=true; updated.spellID=learned.id; updated.spellName=learned.name
  updated.icon=learned.icon; updated.label=learned.name..(updated.targeting=="focus" and " · focus" or "")
 end
 local display=exact or learned or K.API:ResolveDisplay(updated)
 if display then
  updated.displayName=display.name; updated.displaySpellID=display.id; updated.displayIcon=display.icon
  updated.icon=updated.icon or display.icon
  if not learned and not updated.combo then updated.label=display.name end
 end
 if updated.combo then
  local names={}
  for _,id in ipairs(updated.combo) do
   local part=K.API:Resolve({spellIDs=type(id)=="number" and {id} or {},name=type(id)=="string" and id or nil},book)
   if not part or part.passive then updated.known=false else names[#names+1]=part.name end
  end
  updated.label=updated.known and table.concat(names," + ") or (updated.name.." · unavailable")
 end
 if updated.explicitRank and updated.selectedRank then updated.label=(updated.label or updated.name).." · "..updated.selectedRank end
 K.Availability:Annotate(updated,plan.class,plan.flavor)
 updated.nativeHidden=K.Availability:IsHidden(updated,plan.settings) or nil
 local body,why=K.Macros:Build(updated,plan.settings)
 if why then return nil,why end
 updated.body=body
 local ok,errorText=K.NativeBars:MakeMacro(updated,plan.settings,updated.nativeOverflow or updated.nativeBlockAlt)
 if not ok then return nil,errorText end
 -- Keep a still-valid generated identity when its body did not change.
 if updated.body==action.body then updated.macroName=action.macroName; updated.macroIndex=action.macroIndex end
 return updated
end
local function macroReferenced(name)
 local index=GetMacroIndexByName(name)
 if not index or index==0 then return false end
 if not GetBindingKey or GetBindingKey("MACRO "..name) then return true end
 -- Inspect every slot in the native page range, including currently hidden
 -- bars and possession pages that normal preset placement deliberately skips.
 for slot=1,180 do
  local kind,id=GetActionInfo(slot)
  if kind=="macro" and id==index then return true end
 end
 return false
end
function A:QueueCleanup(candidates)
 self.pendingCleanup=self.pendingCleanup or {}
 for name,body in pairs(candidates) do self.pendingCleanup[name]=body end
 if not next(self.pendingCleanup) then return end
 if not self.cleanupFrame then self.cleanupFrame=CreateFrame("Frame") end
 self.cleanupFrame:SetScript("OnUpdate",function(frame)
  if combat() or K.Engine.busy then return end
  local name,body=next(A.pendingCleanup)
  if not name then frame:SetScript("OnUpdate",nil); return end
  A.pendingCleanup[name]=nil
  -- This runs after a successful commit, one candidate per frame. Cleanup
  -- cannot invalidate rollback, race a new setup job, or delete personal edits.
  local ok,why=pcall(function()
   if K.db.ownedMacros[name]==body and K.Macros:FindExact(name,body) and not macroReferenced(name) then
    K.Engine:DeleteOwned({[name]=body})
   end
  end)
  if not ok and K.Diagnostics and K.Diagnostics.IsEnabled and K.Diagnostics:IsEnabled() then
   pcall(K.Diagnostics.Record,K.Diagnostics,"warning","macro-cleanup",tostring(why),{operation="availability-cleanup"})
  end
  if not next(A.pendingCleanup) then frame:SetScript("OnUpdate",nil) end
 end)
end
function A:Repair(plan)
 local E,N,R=K.Engine,K.NativeBars,K.Engine.AvailabilityRuntime
 if E.busy then return "pending","Ability availability maintenance is already queued." end
 if combat() then return false,"Ability availability updates wait until combat ends." end
 if not plan or not plan.nativeLayout then return true end
 local book,forms=K.API:GetCachedSpellbook(),K.API:GetForms()
 local layout=K.Copy(plan.nativeLayout); layout.detachedKeys=layout.detachedKeys or {}
 local placements={}
 for _,entry in ipairs(layout.placements or {}) do
  placements[entry.actionID]=placements[entry.actionID] or {}
  placements[entry.actionID][#placements[entry.actionID]+1]=entry
 end
 local changes={}
 for _,action in ipairs(plan.actions or {}) do if spell(action) and action.key then
  local updated,why=self:Resolve(action,plan,book,forms)
  if not updated then return false,why end
  if not same(action,updated) then
   local change={action=action,updated=updated,slots={},keys={}}
   local expected=oldContent(action)
   for _,entry in ipairs(placements[action.id] or {}) do
    if not entry.detached then
     if N:SameContent(N:ReadSlot(entry.slot),expected) then
      change.slots[#change.slots+1]={entry=entry,before=K.Copy(expected)}
     else entry.detached=true end
    end
   end
   for key,binding in pairs(layout.keys or {}) do if binding.macroAction==action.id and not layout.detachedKeys[key] then
    local owner=plan.bindingOwnership and plan.bindingOwnership[key]
    local expectedCommand=owner and owner.command or (action.macroName and "MACRO "..action.macroName)
    if expectedCommand and GetBindingAction(key)==expectedCommand and ownedMacro(action) then
     change.keys[#change.keys+1]={key=key,before=expectedCommand}
    else layout.detachedKeys[key]=true end
   end end
   changes[#changes+1]=change
  end
 end end
 if #changes==0 then plan.formSignature=K.API:FormSignature(); return true end
 local prospective={actions={}}
 for _,change in ipairs(changes) do if #change.slots>0 or #change.keys>0 then prospective.actions[#prospective.actions+1]=change.updated end end
 local required,available=K.Macros:Budget(prospective)
 if required>available then return false,"Not enough free macro slots to update newly learned abilities. Free a macro slot and try again." end
 local job={kind="maintenance",plan=plan,steps={},backupReady=true,created={},bindingSet=GetCurrentBindingSet and GetCurrentBindingSet() or 2}
 local touchedSlots,touchedKeys={},{}
 for _,step in ipairs(R.macroSteps(prospective,job.created)) do job.steps[#job.steps+1]=step end
 for _,change in ipairs(changes) do
  local current=change
  for _,slotChange in ipairs(change.slots) do
   local s=slotChange
   R.addStep(job.steps,function()
    -- Recheck after the asynchronous gap: a manually filled reserved slot is
    -- permanently detached until the user explicitly applies the preset again.
    if not N:SameContent(N:ReadSlot(s.entry.slot),s.before) then s.entry.detached=true; return end
    local target=N:ContentFor(current.updated)
    if N:SameContent(s.before,target) then return end
    s.after=K.Copy(target); s.inProgress=true; touchedSlots[#touchedSlots+1]=s
    N:WriteSlot(s.entry.slot,target)
    s.inProgress=nil
   end,"Updating available spells on original bars",false,true)
  end
  for _,keyChange in ipairs(change.keys) do
   local binding=keyChange
   R.addStep(job.steps,function()
    if GetCurrentBindingSet and GetCurrentBindingSet()~=job.bindingSet then error("The active binding set changed during ability maintenance.") end
    if GetBindingAction(binding.key)~=binding.before or not ownedMacro(current.action) then layout.detachedKeys[binding.key]=true; return end
    local target="MACRO "..assert(current.updated.macroName,"Newly learned shortcut has no macro")
    local index,name=K.Macros:FindExact(current.updated.macroName,current.updated.body)
    if not index or K.db.ownedMacros[name]~=current.updated.body then error("A learned ability macro changed before maintenance.") end
    if target==binding.before then return end
    binding.after=target; touchedKeys[#touchedKeys+1]=binding
    if not SetBinding(binding.key,target) then error("Could not update learned ability shortcut "..binding.key) end
    if GetBindingAction(binding.key)~=target then error("Learned ability shortcut verification failed: "..binding.key) end
   end,"Updating learned overflow shortcuts",false,true)
  end
 end
 R.addStep(job.steps,function()
  if #touchedKeys>0 then
   if GetCurrentBindingSet and GetCurrentBindingSet()~=job.bindingSet then error("The active binding set changed during ability maintenance.") end
   if SaveBindings(job.bindingSet)==false then error("Could not save learned ability shortcuts.") end
  end
 end,"Saving learned ability shortcuts",true,false)
 job.rollback=function()
  local steps={}
  for index=#touchedSlots,1,-1 do local s=touchedSlots[index]
   R.addStep(steps,function()
    local current=N:ReadSlot(s.entry.slot)
    if N:SameContent(current,s.after) or (s.inProgress and not current) then N:WriteSlot(s.entry.slot,s.before)
    elseif not N:SameContent(current,s.before) then s.entry.detached=true end
   end,"Restoring changed ability slots",false,true)
  end
  for index=#touchedKeys,1,-1 do local b=touchedKeys[index]
   R.addStep(steps,function()
    if GetCurrentBindingSet and GetCurrentBindingSet()~=job.bindingSet then error("Binding set changed; personal controls were preserved.") end
    if GetBindingAction(b.key)==b.after then
     if not SetBinding(b.key,b.before) then error("Could not restore learned ability shortcut "..b.key) end
    elseif GetBindingAction(b.key)~=b.before then layout.detachedKeys[b.key]=true end
   end,"Restoring changed ability shortcuts",false,true)
  end
  if #touchedKeys>0 then R.addStep(steps,function()
   if GetCurrentBindingSet and GetCurrentBindingSet()~=job.bindingSet then error("Binding set changed; personal controls were preserved.") end
   if SaveBindings(job.bindingSet)==false then error("Could not save restored ability shortcuts.") end
  end,"Saving restored ability shortcuts",true,true) end
  for name,body in pairs(job.created) do local macro,expected=name,body
   R.addStep(steps,function()
    if not macroReferenced(macro) then E:DeleteOwned({[macro]=expected}) end
   end,"Removing unused ability macros",true,true)
  end
  R.addStep(steps,function()
   -- Detachment is a record of a personal edit, not a failed installation.
   -- Preserve that protection even when the ability transaction rolls back.
   local detached={}; for _,entry in ipairs(layout.placements) do if entry.detached then detached[entry.slot]=true end end
   for _,entry in ipairs(plan.nativeLayout.placements) do if detached[entry.slot] then entry.detached=true end end
   plan.nativeLayout.detachedKeys=plan.nativeLayout.detachedKeys or {}
   for key,value in pairs(layout.detachedKeys) do if value then plan.nativeLayout.detachedKeys[key]=true end end
  end,"Preserving manual action-bar edits",true,false)
  return steps
 end
 job.commit=function()
  -- Never reclaim a control edited during the job, including after its last
  -- placement step. Mark it detached before persisting the refreshed metadata.
  for _,s in ipairs(touchedSlots) do if not N:SameContent(N:ReadSlot(s.entry.slot),s.after) then s.entry.detached=true end end
  for _,b in ipairs(touchedKeys) do
   if GetBindingAction(b.key)~=b.after then layout.detachedKeys[b.key]=true
   elseif plan.bindingOwnership and plan.bindingOwnership[b.key] then plan.bindingOwnership[b.key].command=b.after end
  end
  local cleanup={}
  for _,change in ipairs(changes) do
   if change.action.macroName and change.action.body and (change.action.macroName~=change.updated.macroName or change.action.body~=change.updated.body) then
    cleanup[change.action.macroName]=change.action.body
   end
   copyInto(change.action,change.updated)
  end
  plan.nativeLayout=layout; plan.formSignature=K.API:FormSignature()
  N:ApplyMacroTextPreference()
  A:QueueCleanup(cleanup)
  return "Available abilities updated on the original action bars."
 end
 return E:StartJob(job)
end
