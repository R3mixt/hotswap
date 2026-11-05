# CurseForge publishing and GitHub sync

Project: [Hot Swap](https://www.curseforge.com/wow/addons/hot-swap), ID **1779519**. Source: [R3mixt/hotswap](https://github.com/R3mixt/hotswap). The project already has published files; publication of a new version is separate from pushing source.

## How this repository publishes

| GitHub action | Result |
| --- | --- |
| Push or pull request | Test and build; no CurseForge upload |
| Publish a GitHub prerelease | Build, verify, upload as CurseForge Beta |
| Publish a normal GitHub release | Build, verify, upload as CurseForge Release |
| Run Publish to CurseForge manually | Build and upload using your selected channel; default Beta |

[Publish to CurseForge](../.github/workflows/curseforge.yml) runs the publisher's network-free tests, then `package.py`, which runs the Lua and packaging regressions. It retains the exact runtime ZIP/checksum as an Actions artifact before uploading. The token is passed only to the upload step. Upload failures do not retry automatically, because a timed-out request may already have created a file.

This integration uploads files. It does not synchronize the CurseForge project description, screenshots, settings or comments. Keep the public description current separately. CurseForge moderation can delay availability after a successful upload.

## One-time setup

1. Create a publisher token in [CurseForge API tokens](https://authors.curseforge.com/account/api-tokens).
2. In [GitHub Actions secrets](https://github.com/R3mixt/hotswap/settings/secrets/actions), create **CURSEFORGE_API_TOKEN** and paste the token into its Secret field. Never put it in an issue, commit, workflow text or chat.
3. Check [publishing/curseforge.json](../publishing/curseforge.json). Version 1.0.3 targets project 1779519, Forever **1.60.1** and Classic Era / Hardcore **1.15.9**. These version names match the TOC and are offered by CurseForge. Add other game version names only after checking the client and CurseForge support. Live-client acceptance remains a separate check.
4. Enable GitHub Actions for the repository if GitHub prompts you. The workflow needs only read access to repository contents; CurseForge upload authorization comes from the dedicated secret.

Publishing authorization is verified: the 1.0.2 release workflow successfully uploaded CurseForge file 9453950 on 2026-11-05.

## Publish an update

1. Update the version in `KeybindOptimizer/Core.lua` and `KeybindOptimizer/KeybindOptimizer.toc` together.
2. Add `publishing/changelog-<version>.txt`, update `CHANGELOG.md` and `publishing/project.json`, and update the changelog entry in `package.py`'s source allowlist.
3. Push the commit and wait for **Validate Hot Swap** to pass. Complete the required live-client acceptance checks before claiming compatibility.
4. Open [GitHub Releases](https://github.com/R3mixt/hotswap/releases/new). Create a matching tag such as `v1.0.1` on the reviewed commit and publish it. For user testing, use `v1.0.1-beta.1` and check **Set as a pre-release**. The TOC may remain `1.0.1` for that prerelease tag.
5. Open the **Publish to CurseForge** Actions run. Its summary reports the uploaded file ID. Check the CurseForge Files page for moderation status and the correct versions/channel.

Do not repeatedly rerun a successful upload: it can create duplicate files. If a connection fails after transmission, inspect CurseForge first. A release tag that differs from the TOC version fails before upload. Publishing a GitHub release here triggers the upload workflow; the workflow itself does not attach the ZIP to the GitHub release. A separately attached verified install ZIP may also be provided. The exact package remains available in the Actions artifacts.

## Troubleshooting and manual upload

- **Missing secret:** save `CURSEFORGE_API_TOKEN` at repository level, with the exact spelling.
- **401/403:** check the token and whether its CurseForge account owns or can upload to project 1779519.
- **Version/channel error:** inspect `publishing/curseforge.json`, the release tag and the workflow inputs.
- **Failed tests:** fix the failure; the workflow stops before uploading.
- **Upload returned a file ID but download is unavailable:** inspect moderation/release status on CurseForge.

For a manual fallback, run `python package.py` and upload only `dist/HotSwap-<version>-CurseForge.zip`. Its immediate root must be `KeybindOptimizer/KeybindOptimizer.toc`. Never upload the developer-source ZIP. Select MIT as the project license and keep client claims accurate. Older published files may retain their original license notices.

## Why not enable a second packager webhook?

This repository already has a tested archive manifest and a nested source layout. The Actions uploader uses that exact archive. Running CurseForge's repository packager as well would establish a second packaging path and could create duplicate files. Choose one publishing route.

The implementation uses the documented multipart upload API with the token in a header and explicit version/channel metadata. See [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321). CurseForge also offers [repository webhook packaging](https://support.curseforge.com/support/solutions/articles/9000197281); it is an alternative, not required for this workflow.
