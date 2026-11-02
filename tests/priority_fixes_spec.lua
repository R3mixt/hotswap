function Tests.priority_restore_resolves_overflow_macro_identity()

local k=TestAddon
Mock.class='WARLOCK'; Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
_G.MultiBar5=nil; _G.MultiBar6=nil; _G.MultiBar7=nil
k:Init(); k:GetSettings().flavor='era'; Mock:AllowFullCatalogMacros()
for _,def in ipairs(k.Profiles:Get('WARLOCK','era')) do
 local id=def.spellIDs and def.spellIDs[1]
 if id and not def.combo then Mock.catalog[id]={id=id,name=def.name,icon=id} end
end
assert(k:Apply()); assert(k:Apply())
local backupID=k.Engine:ListBackups()[1].id
local a
for _,candidate in ipairs(k.db.appliedPlan.actions) do
 if candidate.nativeOverflow and candidate.body then a=candidate; break end
end
assert(a,'Fixture needs a generated overflow action')
local key,oldName,actionID=a.key,a.macroName,a.id
EditMacro(GetMacroIndexByName(oldName),nil,nil,'/say changed by player')
assert(k:Restore())
local ok,why=k.Engine:RestoreBackup(backupID)
assert(ok,why)
local installed
for _,candidate in ipairs(k.db.appliedPlan.actions) do
 if candidate.id==actionID then installed=candidate end
end
assert(installed and installed.macroName~=oldName)
assert(GetBindingAction(key)=='MACRO '..installed.macroName)
assert(select(3,GetMacroInfo(GetMacroIndexByName(installed.macroName)))==installed.body)
assert(k.db.bindingBackups[backupID].snapshot.bindings[key]=='MACRO '..oldName)
assert(select(3,GetMacroInfo(GetMacroIndexByName(oldName)))=='/say changed by player')
end

function Tests.priority_form_failure_preserves_personal_changes()

local k=TestAddon
k:Init(); Mock:AllowFullCatalogMacros(); assert(k:Apply())
SetBinding('CTRL-F24','OPENCHAT'); Mock.actions[2]={'item',900001}
local formAction
for _,a in ipairs(k.db.appliedPlan.actions) do
 if a.targeting=='form' and a.formType=='cat' then formAction=a end
end
assert(formAction and formAction.macroName)
EditMacro(GetMacroIndexByName(formAction.macroName),nil,nil,'/say my custom form button')
local forms=k.API:GetForms()
-- Deterministically exercise a changed form-index signature. This is the
-- same index-reorder fixture used in the existing macro identity suite;
-- unlike that suite, leave Core's high-level recovery enabled.
Mock.forms[forms.cat.index],Mock.forms[forms.bear.index]=Mock.forms[forms.bear.index],Mock.forms[forms.cat.index]
k:MaintainLearnedActions()
if k.Engine.busy then Mock:Drain() end
assert(k.db.enabled and k.db.recoveryRequired and k.recoveryQuarantined)
assert(GetBindingAction('CTRL-F24')=='OPENCHAT')
assert(GetActionInfo(2)=='item')
end

function Tests.priority_import_discards_reserved_shortcut()

local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros()
assert(#k:Preview().errors==0)
assert(not k.Presets:SetHotkey('Leveling','W'))
Mock:ResetWrites()
local ok,why=k:Import('KBO2\nc\tDRUID\nn\tImported\nh\tImported\tW\na\tImported')
assert(ok,why)
assert(k.db.presets.Imported.hotkey==nil)
assert(#Mock.writes==0, 'Import itself must not touch live bindings')
assert(k.Presets:Select('Leveling'))
local applied,message=k:Apply()
assert(applied,tostring(message))

end

function Tests.priority_copy_preserves_displayed_fixed_rank()

local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros()
assert(k.Library:SetRank('druid.wrath.caster',5176))
local selected
for _,entry in ipairs(k.Library:List({tab='spells'})) do
    if entry.actionID=='druid.wrath.caster' then selected=entry end
end
assert(selected and selected.label=='Wrath · Rank 1' and selected.spellID==5176)
Mock:ResetWrites()
assert(k.Library:Place(selected,'druid.moonfire.caster'))
local destination
for _,action in ipairs(k:Preview().actions) do
    if action.id=='druid.moonfire.caster' then destination=action end
end
assert(destination and destination.spellID==5176 and destination.explicitRank)
assert(#Mock.writes==0)
end

function Tests.priority_items_enters_draft_and_opens_spellbook()

local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros()
k.UI:Open(); k.UI:ShowPage("Items")
local page=k.UI.pages.Items
page.idInput:SetText("1710"); page.addID:Click(); page.useChoice:Click()
page.rebind:Click()
page.openBook:Click()
assert(k:GetSettings().itemBindings["item.utility"].selected==1710)
assert(k.UI.bindingSource=="draft" and k.UI.apply:IsEnabled())

assert(k.UI.library and k.UI.library:IsShown())
end

function Tests.priority_spells_only_enters_editable_draft()

local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros()
k.UI:Open(); k.UI:ShowPage("Settings"); k.UI.pages.Settings.spellsOnly:Click()
assert(k:GetSettings().preserveMovement and k.UI.bindingSource=="draft" and k.UI.apply:IsEnabled())
end

function Tests.priority_recommendation_resets_unrelated_search()

local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros()
k.UI:Open(); local page=k.UI.pages.Bindings
page.search:SetText("ZZZZunlikely"); page.search:GetScript("OnTextChanged")(page.search,true)
k.UI:ShowPage("Presets"); page=nil
k.UI.pages.Presets.recommendations:Click()
assert(k.UI.bindingSource=="recommendation" and k.UI.bindingView=="keyboard" and not k.UI.search)
end

function Tests.priority_recovery_defers_combat_and_preserves_personal_macro()
 local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros(); assert(k:Apply())
 local action
 for _,a in ipairs(k.db.appliedPlan.actions) do if a.targeting=="form" and a.macroName then action=a; break end end
 assert(action)
 local name=action.macroName
 EditMacro(GetMacroIndexByName(name),nil,nil,"/say personal")
 local backups=#k.Engine:ListBackups()
 Mock.combat=true; Mock:ResetWrites(); k:RequireRecovery("Test recovery")
 assert(#Mock.writes==0 and k.db.recoveryRequired)
 Mock.combat=false; k:MaintainLearnedActions(); if k.Engine.busy then assert(Mock:Drain()) end
 assert(k.recoveryQuarantined and #k.Engine:ListBackups()==backups+1)
 assert(select(3,GetMacroInfo(GetMacroIndexByName(name)))=="/say personal")
end
