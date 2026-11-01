# CurseForge submission

Status: prepared locally; author-dashboard sign-in is required before creating a project or submitting files. There is no assigned project ID or public project URL yet. This file must not be mistaken for proof of publication.

## Prepared materials

- `publishing/project.json`: title, summary, proposed category and release metadata.
- `publishing/curseforge-description.md`: player-facing description.
- `publishing/logo.png`: original project logo; `logo.svg` is its editable source.
- `CHANGELOG.md`: release notes.
- `dist/HotSwap-0.3.0.zip`: game installation ZIP produced by `python package.py`.
- `dist/HotSwap-0.3.0-source.zip`: separate development archive; do not use as the primary game-install file.
- SHA-256 manifests: verify the file you upload matches the reviewed build.

The default license is All Rights Reserved with permission for personal gameplay. It does not grant others permission to republish modified copies. A broader open-source license can be chosen deliberately later.

## Submission steps

1. Sign in at the [author dashboard](https://authors.curseforge.com/#/projects/create/choose-game). Select World of Warcraft and the addon project type.
2. Use Hot Swap as the title. Confirm available slug/category values in the current dashboard; metadata contains no invented numeric IDs. Add the prepared summary, description, license and original logo.
3. Upload the install ZIP as **Beta** with the changelog. Select only the exact supported game flavor/version offered in the dashboard. Era is the present test target; do not mark Retail or claim a Forever client acceptance run that has not occurred.
4. Submit for moderation, then record the assigned project ID, project URL and file URL. A created draft or uploaded file is not yet a publicly approved release.
5. Perform compatibility.md's live-client acceptance checks. Promote a subsequent verified build to Release only when appropriate.

CurseForge's [submission documentation](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project) explains the account, metadata, file upload and review process. Its current guidance says default app synchronization needs at least one Release file; Beta files require opt-in. Keep the beta label truthful rather than changing it solely for app visibility. See also the [project submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips).

## Version control and later releases

The dedicated Git repository contains source, tests, documentation, build tools and publication metadata. Machine installation scripts, recovery backups, dependencies and generated QA captures are ignored. GitHub Actions is prepared to validate and build if this repository is later pushed to GitHub; it does not run merely because the local files exist.

For an update: change the TOC/Core version together, update changelog and target-version claims, run tests, build, inspect checksums, commit, tag the reviewed beta/release, then upload the matching install ZIP to the existing project. Never commit CurseForge API tokens. No remote, API secret or automatic upload is configured by this preparation.
