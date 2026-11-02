"""Reproduce review findings against 0.4.4 without changing addon or shared tests.

Use the normal development dependencies, or:
  python review/2026-11-02/presets_repros.py --deps PATH_TO_PYTHON_DEPS
These checks assert observed baseline defects; they are not passing acceptance tests.
"""
from pathlib import Path
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--deps', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
if args.deps:
    sys.path.insert(0, str(args.deps))
sys.path.insert(0, str(root / 'tests'))
from run_tests import environment

scenarios = {
    'imported shortcut blocks an otherwise valid existing preset': r'''
local k=TestAddon; k:Init(); k:GetSettings().allowAccountMacros=true
assert(#k:Preview().errors==0)
assert(not k.Presets:SetHotkey('Leveling','W'))
Mock:ResetWrites()
local ok,why=k:Import('KBO2\nc\tDRUID\nn\tImported\nh\tImported\tW\na\tImported')
assert(ok,why)
assert(k.db.presets.Imported.hotkey=='W')
assert(#Mock.writes==0, 'Import itself must not touch live bindings')
assert(k.Presets:Select('Leveling'))
local applied,message=k:Apply()
assert(not applied and message:find('W is used by Move forward and preset Imported.',1,true),tostring(message))
assert(#Mock.writes==0, 'Rejected Apply must not write')
print('OBSERVED: import keeps forbidden W shortcut; existing Leveling Apply is now blocked.')
''',
    'copying a displayed fixed-rank family silently upgrades its rank': r'''
local k=TestAddon; k:Init(); k:GetSettings().allowAccountMacros=true
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
assert(destination and destination.spellID==5177 and not destination.explicitRank)
assert(#Mock.writes==0)
print('OBSERVED: displayed Wrath Rank 1 (5176) copies as highest Wrath (5177).')
''',
}
for name, script in scenarios.items():
    environment().execute(script)
    print('REPRODUCED:', name)
