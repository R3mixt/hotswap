# Preset, planner, library and item review — 2026-11-02

Baseline: 0.4.4 / `7d5d5f28a527bfa298ddc33f7a4670b0d24da5bf`.
Scope: static source review and isolated actual-Lua-5.1 reproductions using the existing WoW mocks. No runtime changes. Neither reproduction establishes live-client casting or secure-input behavior.

## Confirmed defects

### P2 — Imported shortcuts can invalidate every existing draft

- Anchors: `KeybindOptimizer/Presets.lua:545` (import shortcut parser), `:471` (only duplicate shortcut keys cleared), versus `:193` (interactive reserved-key rejection).
- Reproduction: start with an error-free Leveling preset. Interactive `SetHotkey('Leveling','W')` correctly rejects W. Import `KBO2\nc\tDRUID\nn\tImported\nh\tImported\tW\na\tImported`. Import succeeds and retains W. Select existing Leveling and Apply: it fails with `W is used by Move forward and preset Imported.`
- Expected: invalid imported shortcuts should be left unassigned with a precise explanation, or rejected before insertion. An imported draft should not disable unrelated saved layouts.
- Cause: shortcut actions are global to all plans, but merge only compares shortcut-to-shortcut equality. Import does not use the interactive reserved-key and action-conflict validation.
- Fix: one shared shortcut validator for UI/import/restore; validate against proposed merged state before mutation. Clear conflicting imported shortcuts while keeping the draft, report which key/action/preset conflicts. Do not silently relocate existing player actions.
- Acceptance: import W, an existing custom spell key, a protected control, another shortcut, and a free shortcut. Unrelated existing presets must remain applicable, and import must perform zero live writes.
- Confidence: high; reproduced in actual Lua modules. Reproduction script confirms that rejected Apply also performs zero writes; this is a workflow blocker, not observed live-binding corruption.

### P2 — Copying a fixed-rank spellbook entry silently changes its rank

- Anchors: `KeybindOptimizer/Library.lua:269` (source descriptor reconstruction), `:148` (entry explicitly displays configured rank).
- Reproduction: set `druid.wrath.caster` to spell ID 5176, Rank 1. The spellbook entry displays `Wrath · Rank 1`, spell ID 5176. Place that entry on `druid.moonfire.caster`. Destination becomes Wrath spell ID 5177 with no explicit rank; source stays Rank 1.
- Expected: copying the displayed fixed-rank action should preserve its exact rank, or explicitly present a separate highest-rank family choice.
- Cause: Place reconstructs a source-family descriptor but drops `selectedSpellID` and `explicitRank` for ordinary source actions.
- Fix: a shared action-to-descriptor helper should preserve reviewed rank identity and resolved family; ensure the custom-action and replaced-action paths use the same semantics.
- Acceptance: copy fixed rank, highest rank, shared-talent alternate, replaced spell, and custom duplicate. Copied rank must match what the selected entry promises, destination retains its native position, and other form pages remain unchanged.
- Confidence: high; reproduced using actual Lua modules. The wrong draft resolves before Apply, so no live cast is needed to establish the defect.

Run both observed-defect checks with `python review/2026-11-02/presets_repros.py --deps PATH_TO_PYTHON_DEPS`. These are review reproductions, not green acceptance tests for the desired behavior.

## Design and architecture improvements

1. **Make planning context explicit.** `Planner:Build` reads selected settings through K.db, Items and Library; Presets temporarily substitutes K.db/settings for preview and validation (`Presets.lua:168`, `:197`, `:289`). Existing exception restoration is valuable, but new helpers can accidentally read or mutate the wrong context. Introduce an immutable planner input containing preset settings/items, player capabilities, current ownership and shortcut set. Keep live/draft/recommendation view types separate.
2. **Centralize descriptor and shortcut validation.** The two confirmed bugs both arise from multiple paths implementing almost the same contract. Use one typed descriptor conversion and one proposed-state shortcut validator for UI, import, recommendation saving and recovery. Preserve local macro references as identities rather than importing text.
3. **Avoid rebuilding all drafts twice for a shortcut edit.** `SetHotkey` builds every preset at `Presets.lua:199`, then `ValidateHotkeys()` repeats the collection at `:212`. Preset counts are intentionally unbounded. Cache each draft's occupied/protected-key index by signature and capability revision; perform a focused conflict lookup and fresh validation at Apply. This is a source-backed scaling risk, not a demonstrated client timeout.
4. **Guarantee export/import round trips at documented limits.** Export-all has no size/line ceiling (`Presets.lua:371`), while Import rejects over 2 MB or 50,000 records (`:480`, `:487`). An arbitrarily large locally created collection can therefore produce an unusable export. Estimate and enforce compatible limits before copying, or split large collections into clearly named parts. This is a boundary issue, not reproduced as a common-user failure.
5. **Add import inspection and repair.** Show class/client, names to be created, shortcut conflicts, missing local macro references, unsupported focus/target modes and unavailable items before merging. Provide a clear result summary and selectable errors. The current data-only parsing and no-live-write import behavior should remain.
6. **Keep equipment and item promises precise.** Items already has explicit selections and alternatives, capability-gated targeting, missing/inventory status and separate equipment actions. Automatic best food/water is absent, and pet bar ordering/autocast is absent. Treat those as separately scoped features, not defects in implemented preset switching.
7. **Budget saved history and synchronous snapshot work.** Engine snapshots all preset data per backup through `Presets:SnapshotState`. Coordinate retention/size controls with the transaction review; never prune the original baseline or the only usable recovery automatically. No data-size/timeout claim is established here.

## Strengths to preserve

- Recommendation preview restores temporary state on failure and creates neither a saved draft nor live writes.
- Typed import descriptors reject arbitrary Lua/macro text, include class checks, and validate per-action limits.
- Item target capabilities are explicit rather than guessed from item labels.
- Planner separates learned eligibility from display metadata and preserves native form-slot linkage.
- Explicit activation, macro capacity preflight and local macro identity checks remain key product boundaries.
