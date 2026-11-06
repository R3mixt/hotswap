-- In-place maintenance verifies new bodies before committing their ownership.
-- Model the terminal newline the client can return throughout that operation.
local function ready()
 local k=TestAddon; k:Init(); k.OnApplyComplete=function() end
 local plan={class="DRUID",flavor="era",settings={flavor="era"},actions={}}
 local forms=k.API:GetForms()
 for slot,kind in ipairs({"cat","bear"}) do
  local form=forms[kind]
  local action={id="druid.form_"..kind,known=true,targeting="form",formType=kind,
   spellID=form.spellID,spellName=form.name,name=form.name,label=form.name,icon=form.icon}
  action.body=assert(k.Macros:Build(action,plan.settings)); action.macroName=k.Macros:Name(action.body)
  CreateMacro(action.macroName,action.icon,action.body,true)
  k.db.ownedMacros[action.macroName]=action.body; plan.actions[#plan.actions+1]=action
  Mock.actions[slot]={"macro",GetMacroIndexByName(action.macroName)}
 end
 plan.formSignature=k.API:FormSignature(); k.db.enabled=true; k.db.appliedPlan=plan
 local original=GetMacroInfo
 GetMacroInfo=function(...)
  local name,icon,body=original(...)
  if type(body)=="string" then body=body:gsub("[\r\n]+$","").."\r\n" end
  return name,icon,body
 end
 Mock:ResetWrites()
 return k,plan
end
local function swapForms(k)
 local forms=k.API:GetForms()
 Mock.forms[forms.cat.index],Mock.forms[forms.bear.index]=Mock.forms[forms.bear.index],Mock.forms[forms.cat.index]
end
local function body(name) return select(3,GetMacroInfo(GetMacroIndexByName(name))) end
local function canonical(text) return text:gsub("[\r\n]+$","") end
local function finish(ok,why)
 if ok=="pending" then return Mock:Drain() end
 return ok,why
end

function Tests.owned_macro_quarantine_accepts_terminal_newlines_and_preserves_personal_edits()
 local k,plan=ready()
 local personal=k.Copy(plan.actions[1]); personal.macroName="KBO_personal_form_edit"
 CreateMacro(personal.macroName,1,"/say my personal form helper",true)
 k.db.ownedMacros[personal.macroName]=personal.body; plan.actions[#plan.actions+1]=personal
 local ok,why=finish(k.Engine:QuarantineForms()); assert(ok,tostring(why))
 for index=1,2 do
  local name=plan.actions[index].macroName
  assert(canonical(body(name))=="#showtooltip","Quarantine left an owned stale form macro active")
  assert(k.db.ownedMacros[name]=="#showtooltip","Quarantine did not commit its verified canonical body")
 end
 assert(canonical(body(personal.macroName))=="/say my personal form helper","Quarantine overwrote personal text")
 assert(k.db.ownedMacros[personal.macroName]==personal.body,"Quarantine claimed the personal body")
 assert(k.recoveryQuarantined,"Successful quarantine did not report recovery state")
end

function Tests.owned_macro_maintenance_accepts_newline_reads_before_ownership_commit()
 local k,plan=ready(); local previous=k.Copy(k.db.ownedMacros); local oldSignature=plan.formSignature
 local edit=EditMacro; local calls=0
 EditMacro=function(index,...)
  local name=GetMacroInfo(index); calls=calls+1
  assert(k.db.ownedMacros[name]==previous[name],"Maintenance committed ownership before verifying all edits")
  return edit(index,...)
 end
 swapForms(k)
 local ok,why=finish(k.Engine:RepairLearnedActions(plan)); assert(ok,tostring(why))
 assert(calls==2 and plan.formSignature~=oldSignature,"Form maintenance did not complete both changes")
 for _,action in ipairs(plan.actions) do
  assert(action.body~=previous[action.macroName],"The obsolete form guard survived maintenance")
  assert(canonical(body(action.macroName))==action.body and k.db.ownedMacros[action.macroName]==action.body,
   "The verified form body and ownership were not committed together")
 end
 for _,write in ipairs(Mock.writes) do assert(write[1]~="binding" and write[1]~="savebindings","Maintenance rewrote keys") end
end

function Tests.owned_macro_maintenance_rolls_back_verified_newline_body_on_later_failure()
 local k,plan=ready(); local previous=k.Copy(k.db.ownedMacros); local oldSignature=plan.formSignature
 local edit=EditMacro; local calls=0
 EditMacro=function(...)
  calls=calls+1
  if calls==2 then error("Injected second normalized edit failure") end
  return edit(...)
 end
 swapForms(k)
 local ok,why=finish(k.Engine:RepairLearnedActions(plan))
 assert(not ok and tostring(why):find("rolled back",1,true),tostring(why))
 assert(calls==3,"Rollback did not restore the first verified edit")
 for name,expected in pairs(previous) do
  assert(canonical(body(name))==expected,"Rollback left an updated form body installed")
  assert(k.db.ownedMacros[name]==expected,"Failed maintenance changed ownership")
 end
 assert(plan.formSignature==oldSignature,"Failed maintenance advanced the form signature")
end

function Tests.owned_macro_maintenance_preserves_personal_edit_instead_of_normalizing_it()
 local k,plan=ready(); local previous=k.Copy(k.db.ownedMacros)
 local edit=EditMacro; local touched; local personal="/say changed while maintenance ran"
 EditMacro=function(index,...)
  touched=GetMacroInfo(index)
  local result=edit(index,...)
  edit(GetMacroIndexByName(touched),nil,nil,personal)
  return result
 end
 swapForms(k)
 local ok,why=finish(k.Engine:RepairLearnedActions(plan))
 assert(not ok and tostring(why):find("personal edits were preserved",1,true),tostring(why))
 assert(touched and canonical(body(touched))==personal,"Rollback overwrote a personal command edit")
 assert(k.db.ownedMacros[touched]==previous[touched],"Maintenance adopted personal text")
end
