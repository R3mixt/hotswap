"""Audit reproductions for 0.4.4, not acceptance tests for a fixed release.

Each scenario runs the real Lua modules in a fresh Lua 5.1 mock environment
and asserts the observed defect. These scenarios should stop passing once
their corresponding fixes land. Run with the project's Lupa dependency on
PYTHONPATH, installed normally, or supplied as --deps PATH. Example:
python review/2026-11-02/transaction_repros.py --deps path/to/python-deps
"""
import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests"))


SCENARIOS = {
    "restored_overflow_keeps_edited_macro_name": r'''
local k=TestAddon
Mock.class='WARLOCK'; Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
_G.MultiBar5=nil; _G.MultiBar6=nil; _G.MultiBar7=nil
k:Init(); k:GetSettings().flavor='era'; k:GetSettings().allowAccountMacros=true
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
assert(GetBindingAction(key)=='MACRO '..oldName)
assert(select(3,GetMacroInfo(GetMacroIndexByName(oldName)))=='/say changed by player')
print('Restore says success; '..key..' binds '..oldName..' instead of '..installed.macroName)
''',
    "automatic_form_recovery_removes_personal_changes": r'''
local k=TestAddon
k:Init(); k:GetSettings().allowAccountMacros=true; assert(k:Apply())
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
assert(k.db.enabled==false)
assert(GetBindingAction('CTRL-F24')=='')
assert(GetActionInfo(2)==nil)
print('Maintenance failure automatically restores original setup; personal key and slot removed')
''',
    "paused_apply_unrelated_edit_breaks_rollback": r'''
local k=TestAddon
k:Init(); k:GetSettings().allowAccountMacros=true; Mock.async=true
assert(k:Apply()=='pending')
local reached=false
for i=1,2000 do
 local job=k.Engine.job
 if job and job.steps[job.index].message=='Preparing native action bars' then reached=true; break end
 Mock:Advance(.016)
end
assert(reached and k.Engine.job.backupReady,'Fixture needs a completed backup')
Mock.combat=true; Mock:Advance(.016); assert(k.Engine.job.paused)
Mock.combat=false
SetBinding('CTRL-F24','OPENCHAT')
local ok,why=Mock:Drain()
assert(not ok and why:find('rollback could not finish',1,true),tostring(why))
assert(why:find('Unexpected restored key CTRL-F24',1,true),tostring(why))
assert(GetBindingAction('CTRL-F24')=='OPENCHAT','Personal key should survive this repro')
assert(not k.Engine.lastJob.rollbackComplete)
print('Unrelated new key survives, but Apply and rollback both fail verification: '..why)
''',
}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deps", type=Path, default=ROOT / "python-deps",
                        help="Directory containing the Lupa package; defaults to project/python-deps")
    args = parser.parse_args()
    if args.deps.is_dir():
        sys.path.insert(0, str(args.deps.resolve()))
    from run_tests import environment

    for name, scenario in SCENARIOS.items():
        environment().execute(scenario)
        print("REPRODUCED " + name, flush=True)
    print(f"{len(SCENARIOS)}/{len(SCENARIOS)} audit defects reproduced; mocked APIs, no live-client certification")
