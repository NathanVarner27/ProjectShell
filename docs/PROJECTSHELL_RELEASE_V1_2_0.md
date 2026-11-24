# ProjectShell v1.2.0 — release and local acceptance checklist

## Included functionality

- Windows CLI ProjectShell Manager, numbered menus, saved profiles and launchable tools.
- Guided **ProjectShell-owned** application name migration: read-only preview, exact approval, backup, receipt, verification, conservative rollback. Does not move or rewrite third-party application source, binary, settings, GitHub repo or launchable paths.
- Process-local `PROJECTSHELL_START_DIRECTORY` handoff to child applications; existing working-directory fallback retained.
- Optional Nathan's Catalogue preview-only dependency review. No automatic dependency installs.
- Windows ZIP with the complete launcher/script set and a standalone source-built Windows x64 Setup EXE; both Authenticode unsigned.

## Verified or required acceptance

- [x] The application migration feature has Windows PowerShell 5.1/7 source/build CI passing in its development branch.
- [x] Real user's migration planning, apply/rollback, stored JSON syntax/readability, script parsing, restored desktop links and permissions were tested separately.
- [x] Real DBP installed files: 66 content-equivalent to the tested DBP commit; local 163-test Python regression (5 expected skips), canonical/legacy CLI and Windows launchers passed.
- [x] Both local ProjectShell DBP saved profiles have correct name, group, folder and launchable, with desktop links present and different administrator settings.
- [ ] Confirm BOTH DBP desktop links open at the expected location and actual privilege (normal and UAC); a saved flag is not proof of actual privilege.
- [ ] Run combined PR CI (PowerShell 5.1/7; Windows ZIP/EXE build and isolated installation); ensure the process-local handoff test runs.
- [ ] Validate new v1.2.0 installer on a real Windows desktop and confirm user data survives upgrade. Existing installed files/hashes from older build do not prove new build equivalence.
- [ ] Inspect artifact hashes, license, provenance and published asset names before public release.
- [ ] Publish only after approving the verified version/tag and labeling both ZIP/EXE Authenticode **unsigned**.
- [ ] Test ProjectShell with DBP-generated ZIP, reviewed standalone EXE and separately prototyped MSIX. DBP does not compile EXEs and an installer EXE is **not** automatically a suitable MSIX entry point.

## Boundaries

Preserve local `%LOCALAPPDATA%\ProjectShell` profiles/workspaces/settings and saved shortcuts during upgrade. Keep administrative and standard-user test profiles separate; do not change elevation settings without review. Do not remove old ProjectShell v1.1.0 release.

MSIX: not an official v1.2.0 deliverable. Full-trust Windows packaged app behavior, runtime entrypoint, three PNG assets, SDK MakeAppx, Partner Center identity/publisher for Store submission, signature/trust for local installation, WACK and clean-machine update/uninstall acceptance remain separate.
