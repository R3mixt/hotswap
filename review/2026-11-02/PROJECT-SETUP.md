# Permanent project setup

Created 2 November 2026 at Clay's request.

- Permanent project: `C:\Users\Clay\Documents\Hot Swap`
- Runtime source: `KeybindOptimizer\`
- Original checkout: `C:\Users\Clay\Documents\Codex\2026-10-31\i-x20\work`
- Review branch: `codex/hot-swap-professional-review`
- Baseline: `7d5d5f28a527bfa298ddc33f7a4670b0d24da5bf`, 0.4.4 beta

The permanent folder is an independent local Git clone with copied objects, full existing history and the original beta tags. The original checkout is unchanged. The baseline branch `codex/hot-swap` remains available. No remote is configured because the source checkout had none; no hosting account/repository has been assumed and nothing was pushed.

The review was prepared in the chat's writable staging workspace and transferred as a Git commit onto the permanent review branch. Review evidence and recommendations live under `review/2026-11-02/`; runtime sources are unchanged from the baseline. The explicit release manifest does not package this review directory.

The pinned `lupa==2.8` development dependency was copied from the existing working setup into ignored `python-deps/`. Tests run here without relying on the old checkout. No private backups, account bindings, SavedVariables, receipts or machine-specific installer scripts were copied into the new project.

```powershell
Set-Location -LiteralPath 'C:\Users\Clay\Documents\Hot Swap'
git status
git log -5 --oneline
python tests/run_tests.py
python -m unittest discover -s tests -p test_package.py -v
```

For another development machine, install `requirements-dev.txt` in an isolated Python environment. The addon has no external runtime dependency. Run `python package.py` when preparing an actual release; the review did not rebuild or install one.

Git integrity checks completed with no corruption. The source clone contains some pre-existing unreachable objects; these are not broken references and were left alone. The ignored test output is `test-results.txt`.
