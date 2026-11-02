# Hot Swap

WoW binding presets and keyboard editing using Blizzard's original action bars. **0.4.0 beta** targets Forever, with Classic Era / Hardcore as the current test client. Applying a preset updates its assigned keys while preserving unrelated bindings and mouse controls.

[Player instructions](KeybindOptimizer/README.md), [scope and known gaps](docs/requirements.md), [architecture](docs/architecture.md), [code review](docs/code-review.md), [CurseForge setup](docs/curseforge.md).

## Development

```text
python -m pip install -r requirements-dev.txt
python tests/run_tests.py
python package.py
```

There are no external addon runtime libraries. Lupa provides Lua 5.1 for tests. Packaging reruns the suite and writes runtime/source ZIPs and checksums to `dist`; `--output PATH` chooses another directory. Do not upload dependencies, installation receipts, backups or SavedVariables.

The `KeybindOptimizer` folder and SavedVariables name remain for upgrade compatibility; the displayed name is Hot Swap. Commit focused changes with passing tests. Tag reviewed betas separately from stable releases. Do not mark a release stable solely to obtain default CurseForge app visibility.
