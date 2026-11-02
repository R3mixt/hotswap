"""Read-only review probes; prints observed defects in the 0.4.4 UI."""
from pathlib import Path
import argparse
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--deps', type=Path, default=ROOT / 'python-deps', help='Folder containing the lupa package')
args = parser.parse_args()
sys.path.insert(0, str(args.deps))
sys.path.insert(0, str(ROOT / 'tests'))
from run_tests import environment

CASES = {
    'items-from-current': r'''
local k=TestAddon; k:Init(); k:GetSettings().allowAccountMacros=true
k.UI:Open(); k.UI:ShowPage("Items")
local page=k.UI.pages.Items
page.idInput:SetText("1710"); page.addID:Click(); page.useChoice:Click()
print("selected item", k:GetSettings().itemBindings["item.utility"].selected)
print("source",k.UI.bindingSource,"apply enabled",k.UI.apply:IsEnabled())
page.rebind:Click()
print("capture shown",k.UI.capture and k.UI.capture:IsShown(),"notice",k.UI.notice)
page.openBook:Click()
print("book shown",k.UI.library and k.UI.library:IsShown(),"source",k.UI.bindingSource)
assert(k:GetSettings().itemBindings["item.utility"].selected==1710)
assert(k.UI.bindingSource=="current" and not k.UI.apply:IsEnabled())
assert(not k.UI.capture or not k.UI.capture:IsShown())
assert(not k.UI.library or not k.UI.library:IsShown())
''',
    'spells-only-from-current': r'''
local k=TestAddon; k:Init(); k:GetSettings().allowAccountMacros=true
k.UI:Open(); k.UI:ShowPage("Settings"); k.UI.pages.Settings.spellsOnly:Click()
print("protected",k:GetSettings().preserveMovement,"source",k.UI.bindingSource,"apply enabled",k.UI.apply:IsEnabled())
assert(k:GetSettings().preserveMovement and k.UI.bindingSource=="current" and not k.UI.apply:IsEnabled())
''',
    'preview-search-state': r'''
local k=TestAddon; k:Init(); k:GetSettings().allowAccountMacros=true
k.UI:Open(); local page=k.UI.pages.Bindings
page.search:SetText("ZZZZunlikely"); page.search:GetScript("OnTextChanged")(page.search,true)
k.UI:ShowPage("Presets"); page=nil
k.UI.pages.Presets.recommendations:Click()
print("source",k.UI.bindingSource,"view",k.UI.bindingView,"query",k.UI.search)
print("empty",k.UI.pages.Bindings.list.empty:GetText())
assert(k.UI.bindingSource=="recommendation" and k.UI.bindingView=="list" and k.UI.search=="zzzzunlikely")
''',
}

failures = 0
for name, source in CASES.items():
    print('\nPROBE:', name, flush=True)
    try:
        environment().execute(source)
    except Exception as exc:
        failures += 1
        print('PROBE ERROR:', exc)
raise SystemExit(1 if failures else 0)
