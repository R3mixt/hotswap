"""Observed-state review checks for 0.4.4, not desired-behavior regressions.

Run with the project's normal test dependency or --deps PATH_TO_PYTHON_DEPS.
No addon files or real WoW state are changed.
"""
from pathlib import Path
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--deps", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
if args.deps:
    sys.path.insert(0, str(args.deps))
sys.path.insert(0, str(root / "tests"))
from run_tests import environment

scenarios = {
    "selecting an unchanged active draft forces an unnecessary apply": r'''
local k=TestAddon; k:Init(); k:GetSettings().allowAccountMacros=true
assert(k.Presets:Activate('Leveling'))
local count=#k.db.bindingBackupOrder
local signature=k.Presets:Signature('Leveling')
assert(k.Presets:Activate('Leveling'))
assert(#k.db.bindingBackupOrder==count, 'Direct repeated activation is correctly a no-op')
assert(k.Presets:Select('Leveling'))
assert(k.Presets:Signature('Leveling')==signature)
assert(not k.Presets:HasUnappliedChanges(), 'No preset content changed')
assert(k.dirty, 'Selection nevertheless marks draft dirty')
assert(k.Presets:Activate('Leveling'))
assert(#k.db.bindingBackupOrder==count+1)
print('OBSERVED: unchanged selection sets dirty and adds a backup on reactivation.')
''',
    "a failed native action read is presented as an empty slot": r'''
local k=TestAddon
Mock.bindings={['1']='ACTIONBUTTON1'}; Mock.bindingInventory=nil
Mock.actions[1]={'spell',5176}
GetActionInfo=function() error('Injected native action read failure') end
Mock:ResetWrites()
local plan=k.CurrentBindings:Build()
assert(plan.byKey['1'].liveEmpty)
assert(plan.byKey['1'].label=='Empty action slot')
assert(#plan.errors==0)
assert(#Mock.writes==0)
print('OBSERVED: unreadable occupied slot is labeled Empty, with no read error.')
''',
}

for name, script in scenarios.items():
    environment().execute(script)
    print("REPRODUCED:", name)
