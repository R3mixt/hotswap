# Offline addon previews

This harness loads the addon's real Lua modules in TOC order and captures their
widgets using a deterministic mock of the WoW API. It requires no WoW process,
account, or SavedVariables file. Real spell/item icons are cached once from public
Wowhead metadata and its ZAM image CDN; capture and rendering then work offline.
It does not change your installed addon or game settings.

## Generate screenshots

From the repository root on Windows, with Python and PowerShell available:

```powershell
python -m pip install -r requirements-dev.txt
python ui-qa/icon_assets.py --fetch
python ui-qa/capture.py
pwsh -NoProfile -File ui-qa/render.ps1
```

The renderer uses Windows `System.Drawing`; `powershell -File` can also be used.
Its default scale is **2x**, preserving the addon's logical layout while producing
crisper PNGs. Use `-Scale 1` for smaller review images. To render one captured view:

```powershell
pwsh -NoProfile -File ui-qa/render.ps1 -Pages modern-current
```

`capture.py` first records the existing page/dialog QA cases, then captures
Classic and Modern with the same sample current keybindings, presets, Window
settings, and draft spellbook. The showcase current layout includes spells,
movement controls, and mouse bindings rather than an empty keyboard.

Raw JSON and PNG files are written under `ui-qa/` and ignored by Git. The eight
theme screenshots and `theme-comparison.png` are also saved to
[`review/themes/`](../review/themes/) for documentation and review.

## What the images prove

Frames, labels, sizes, anchors, visibility, sample bindings, theme colors, and
font choices come from the running addon code. Modern skin textures are rendered
from the same color/alpha data that the addon sends to WoW. Both themes use the
same real spell/item artwork, including unlearned spell metadata. The renderer
preserves icon cropping, tint, alpha and desaturation. Classic window artwork
uses an approximate bevel. Fonts are approximated with Georgia for Classic and
Segoe UI for Modern. Each image is visibly labeled **OFFLINE PREVIEW**.

## Preview icon cache

[`icons/manifest.json`](icons/manifest.json) records verified spell/item IDs,
icon names, metadata edition, public source URLs, and SHA-256 image hashes. The
bounded fixture covers the Druid preview and its sample items, not every class.
Metadata for unlearned spells does not mark them as learned. The inherited test
fixture includes a few later-expansion spells; their display metadata does not
change the runtime addon's Era catalog or compatibility claims.

Downloaded JPEGs live in the ignored `.cache/icons/` directory. They are neither
committed as addon assets nor included in the installable ZIP. Run
`python ui-qa/icon_assets.py` to verify the cache without network access. Missing
or damaged assets stop capture/rendering with an explicit error; rerun `--fetch`
to repair them. The renderer no longer silently substitutes initials or blanks.

World of Warcraft icon artwork belongs to **Blizzard Entertainment**, served
here by [Wowhead](https://www.wowhead.com/classic) / ZAM for preview purposes.
That artwork is not covered by this repository's MIT source-code license.

These images are suitable for design review and explaining the interface. They
are not in-game screenshots and do not verify protected execution, taint,
hardware input, actual Blizzard artwork, or compatibility with another addon.
Those behaviors still require live-client testing.

When changing a theme, regenerate and inspect both themes, including a dialog
and the Settings page. Check that a Modern-to-Classic switch restores the native
artwork, and that populated keycaps and labels remain readable.
