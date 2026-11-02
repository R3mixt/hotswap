# Offline addon previews

This harness loads the addon's real Lua modules in TOC order and captures their
widgets using a deterministic mock of the WoW API. It requires no WoW process,
account, network connection, or SavedVariables file. It does not change your
installed addon or game settings.

## Generate screenshots

From the repository root on Windows, with Python and PowerShell available:

```powershell
python -m pip install -r requirements-dev.txt
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
from the same color/alpha data that the addon sends to WoW. Classic template
artwork uses an approximate bevel; game icons use deterministic colored initials.
Fonts are approximated with Georgia for Classic and Segoe UI for Modern. Each
image is visibly labeled **OFFLINE PREVIEW**.

These images are suitable for design review and explaining the interface. They
are not in-game screenshots and do not verify protected execution, taint,
hardware input, actual Blizzard artwork, or compatibility with another addon.
Those behaviors still require live-client testing.

When changing a theme, regenerate and inspect both themes, including a dialog
and the Settings page. Check that a Modern-to-Classic switch restores the native
artwork, and that populated keycaps and labels remain readable.
