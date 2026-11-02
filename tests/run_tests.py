"""Execute the actual addon modules in Lua 5.1 against a deterministic WoW API mock.

This is a regression harness, not a substitute for a real WoW client test.
Run: python work/tests/run_tests.py
"""
from pathlib import Path
import sys
import traceback

HERE = Path(__file__).resolve().parent
WORK = HERE.parent
sys.path.insert(0, str(WORK / "python-deps"))
from lupa.lua51 import LuaRuntime, lua_type

SOURCE = WORK if (WORK / "Core.lua").exists() else WORK / "KeybindOptimizer"
MODULES = ["Core", "API", "Profiles", "Macros", "Items", "LibraryData", "Library", "NativeBars", "Planner", "Engine", "Presets", "ItemsUI", "UI", "LibraryUI", "Launcher"]


def environment():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((HERE / "mock.lua").read_text(encoding="utf-8"), name="@mock.lua")
    native_mock = HERE / "native_mock.lua"
    if native_mock.exists():
        lua.execute(native_mock.read_text(encoding="utf-8"), name="@native_mock.lua")
    namespace = lua.table()
    for module in MODULES:
        path = SOURCE / (module + ".lua")
        chunk = lua.compile(path.read_text(encoding="utf-8-sig"), name="@" + str(path))
        chunk("KeybindOptimizer", namespace)
    lua.globals().TestAddon = namespace
    lua.execute('''
        -- Most behavioral scenarios assert the completed transaction. Drain
        -- the real frame worker here; dedicated async scenarios set Mock.async.
        local function wrap(owner,name)
            local raw=owner[name]
            owner[name]=function(self,...)
                local ok,message,extra=raw(self,...)
                if ok=="pending" and not Mock.async then
                    local finished,why=Mock:Drain()
                    return finished,why,extra
                end
                return ok,message,extra
            end
        end
        wrap(TestAddon,"Apply"); wrap(TestAddon,"Restore")
        wrap(TestAddon.Engine,"RestoreBackup")
        wrap(TestAddon.Engine,"Activate")
        wrap(TestAddon.Engine,"RepairLearnedActions")
    ''')
    for spec in sorted(HERE.glob("*spec.lua"), key=lambda p: (p.name != "test_spec.lua", p.name)):
        lua.execute(spec.read_text(encoding="utf-8"), name="@" + spec.name)
    return lua


def plain(value):
    if lua_type(value) == "table":
        return {plain(key): plain(child) for key, child in value.items()}
    return value


def lua_table(lua, value):
    if isinstance(value, dict):
        table = lua.table()
        for key, child in value.items():
            table[lua_table(lua, key)] = lua_table(lua, child)
        return table
    return value


def reload_from_saved_variables():
    first = environment()
    first.execute("TestAddon:Init(); assert(TestAddon:Apply())")
    saved = plain(first.globals().KeybindOptimizerDB)
    persistent = {
        field: plain(first.globals().Mock[field])
        for field in ["macros", "bindings", "bindingSets", "bindingSet", "modified", "cvars", "actions", "actionToggles", "actionPage"]
    }
    second = environment()
    second.globals().KeybindOptimizerDB = lua_table(second, saved)
    for field, value in persistent.items():
        second.globals().Mock[field] = lua_table(second, value)
    second.execute("""
        Mock:Fire('ADDON_LOADED', 'KeybindOptimizer')
        Mock:Fire('PLAYER_LOGIN')
        assert(TestAddon.db.enabled, 'Reload lost enabled profile')
        assert(not TestAddon.Engine.dock, 'Reload recreated custom action bars')
        assert(GetBindingAction('1')=='ACTIONBUTTON1', 'Reload lost native main-bar binding')
        assert(GetActionInfo(1), 'Reload lost native bar contents')
        assert(TestAddon:Restore(), 'Reload lost rollback snapshot')
        assert(Mock.bindings.F=='ASSISTTARGET', 'Reload rollback did not restore original F')
        assert(GetMacroInfo(GetMacroIndexByName("UserMacro"))=='UserMacro', 'Reload rollback removed personal macro')
    """)


def main():
    absent = [name for name in MODULES if not (SOURCE / (name + ".lua")).exists()]
    if absent:
        print("BLOCKED: implementation modules not present: " + ", ".join(absent))
        return 2
    try:
        prototype = environment()
    except Exception:
        traceback.print_exc()
        return 1
    names = sorted(str(key) for key in prototype.globals().Tests.keys())
    passed = 0
    for name in names:
        try:
            lua = environment()
            lua.globals().Tests[name]()
            print("PASS " + name)
            passed += 1
        except Exception as exc:
            print("FAIL " + name + "\n" + str(exc))
    try:
        reload_from_saved_variables()
        print("PASS reload_from_saved_variables_in_fresh_lua_vm")
        passed += 1
    except Exception as exc:
        print("FAIL reload_from_saved_variables_in_fresh_lua_vm\n" + str(exc))
    names.append("reload_from_saved_variables_in_fresh_lua_vm")
    print(f"\n{passed}/{len(names)} tests passed (actual Lua 5.1; mocked WoW APIs).")
    return 0 if passed == len(names) and names else 1


if __name__ == "__main__":
    raise SystemExit(main())
