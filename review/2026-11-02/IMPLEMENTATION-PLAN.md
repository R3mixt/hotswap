# Priority implementation plan

1. Restore identity: remap authenticated saved direct macro references after recreation; verify through restore regression.
2. Maintenance recovery: replace automatic full restore with explicit recovery state and quarantine only unchanged owned form-dependent macros; preserve personal changes and defer combat writes.
3. Editing state: enter Draft when opening Items and when invoking Spells only; retain independent local preferences.
4. Imported shortcuts: stage incoming modes without hotkeys, then use the interactive validator against the complete merged collection; leave rejected shortcuts unassigned.
5. Fixed ranks: copy exact selected spell identity into the replacement descriptor.
6. Recommendations: reset search, keyboard view, modifier and form state on explicit preview.

Validate actual Lua regression suite, packaging tests and focused desired-behavior scenarios. Runtime client acceptance remains separate.

## Implemented outcome

All six requested items are implemented. The original report and defect probes remain historical baseline evidence; use tests/priority_fixes_spec.lua for corrected behavior.

Recovery uses a named backup and the existing bounded transaction worker. It disables only exact, still-owned form-dependent macro bodies, preserves personally edited macros/keys/slots, pauses for combat and exposes a persistent recovery-needed status. Successful explicit Apply or Restore clears that state. It does not silently restore the original setup.

Other review backlog items, including concurrent-writer reconciliation (F3 in the full report), remain separate from these six requested fixes. Client taint/input/casting acceptance is still required before release. No installation or publication is included in this change.

## Validation

412/412 actual-Lua-5.1 scenarios passed, including eight new priority/recovery scenarios. Seven packaging tests passed. All 26 UI geometry cases instantiated. Runtime input/casting/taint behavior remains unverified in game.
