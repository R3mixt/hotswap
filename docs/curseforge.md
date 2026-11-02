# CurseForge submission

Status: the author reports that the CurseForge project has been created. The project ID and public URL have not been supplied here, and upload/publication of this release is not verified. The files below are prepared locally for that existing project.

## Prepared materials

- `publishing/project.json`: title, summary, proposed category and release metadata.
- `publishing/curseforge-description.md`: player-facing description.
- `publishing/logo.png`: original project logo; `logo.svg` is its editable source.
- `CHANGELOG.md`: release notes.
- `dist/HotSwap-0.4.3-CurseForge.zip`: **the only ZIP to upload to CurseForge**, produced by `python package.py`.
- `dist/HotSwap-0.4.3-developer-source-NOT-FOR-UPLOAD.zip`: separate development archive; **do not upload this to CurseForge**.
- SHA-256 manifests: verify the file you upload matches the reviewed build.

The upload ZIP must contain `KeybindOptimizer/KeybindOptimizer.toc` immediately inside the addon folder, with the listed Lua files beside it. Upload the ZIP unchanged; do not add an outer HotSwap/version folder or upload the source archive. Packaging verifies this shape and every TOC load path before producing the upload file.

The author reported a missing-TOC rejection for version 0.4.2. The local runtime archive does contain the correctly placed TOC and all referenced files. The source archive has an extra outer folder; which exact file was submitted and the full rejection text have not been verified. Do not describe the old runtime file as missing its TOC or claim this rebuild has been accepted by CurseForge.

The default license is All Rights Reserved with permission for personal gameplay. It does not grant others permission to republish modified copies. A broader open-source license can be chosen deliberately later.

## Submission steps

1. Sign in at the [author dashboard](https://authors.curseforge.com/) and open the existing Hot Swap project.
2. Use Hot Swap as the title. Confirm available slug/category values in the current dashboard; metadata contains no invented numeric IDs. Add the prepared summary, description, license and original logo.
3. Upload the install ZIP as **Beta** with the changelog. Select only the exact supported game flavor/version offered in the dashboard. Era is the present test target; do not mark Retail or claim a Forever client acceptance run that has not occurred.
4. Submit for moderation, then record the assigned project ID, project URL and file URL. A created draft or uploaded file is not yet a publicly approved release.
5. Perform compatibility.md's live-client acceptance checks. Promote a subsequent verified build to Release only when appropriate.

CurseForge's [submission documentation](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project) explains the account, metadata, file upload and review process. Its current guidance says default app synchronization needs at least one Release file; Beta files require opt-in. Keep the beta label truthful rather than changing it solely for app visibility. See also the [project submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips).

## Version control and later releases

The dedicated Git repository contains source, tests, documentation, build tools and publication metadata. Machine installation scripts, recovery backups, dependencies and generated QA captures are ignored. GitHub Actions is prepared to validate and build if this repository is later pushed to GitHub; it does not run merely because the local files exist.

For an update: change the TOC/Core version together, update changelog and target-version claims, run tests, build, inspect checksums, commit, tag the reviewed beta/release, then upload the matching install ZIP to the existing project. Never commit CurseForge API tokens. No remote, API secret or automatic upload is configured by this preparation.
