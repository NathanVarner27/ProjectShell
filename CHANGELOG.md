# Changelog

## Unreleased — ProjectShell v1.2.0 preview: Catalogue and migration

- Added guided application name transition planning in Manager (16), project sessions (10) and workspace menu (9).
- Added exact-confirmation changes to ProjectShell-owned profile/workspace labels and desktop shortcuts, with local snapshots, post-change checks and conservative rollback.
- Added isolated GitHub Package Builder naming pilot fixtures; no rename of the real builder or automated repository/filesystem changes.
- Documented full software identity checklist for source, installer, ZIP/EXE/MSIX, GitHub distribution, legacy users and migration verification.

### Existing Catalogue dependency handoff

- Added optional, preview-only Nathan's Catalogue Dependency Broker v1 integration using the alpha.13 structured JSON contract.
- Added read-only dependency detection for 7-Zip, Windows Sandbox, WinGet and Chocolatey, with independent operation when Catalogue is missing.
- Added a user-initiated Catalogue review menu in manager/session/workspace menus and optional preview during RAR/7Z imports when 7-Zip is missing.
- Preserved manual fallbacks for unsupported PowerShell modules, runtimes and Windows features; no automated installs, updates, repairs, removals or elevation.
- Added Windows PowerShell 5.1/7 regression tests, installer packaging integration and security/contract documentation. Windows preview acceptance is pending; system installation remains disabled.


## ProjectShell v1.1.0 — DevTools workspace management (2026-11-23)

- Added a configurable DevTools root separate from ProjectShell's installation folder and a local saved workspace registry.
- Added creation and import of folders, ZIP archives, and RAR/7Z archives with locally installed 7-Zip, plus registration of existing DevTools folders.
- Added explicit copy/move decisions, staging, collision prevention, and copy verification before deleting originals.
- Added saved per-workspace main launchables and separate installer locations, with file-picker and manual path selection.
- Added direct main-tool launch and launcher setup from numbered manager and session menus.
- Added a startup action for shortcuts that automatically runs the selected main tool.
- Added a complete source-built Windows x64 ZIP and standalone setup EXE, including code-signing policy, security and removal documentation.
- Added isolated Windows package/source integrity and scripted installation tests. Full interactive desktop and UAC testing remains separate.
- Added SHA-256 checksums and free GitHub Actions artifact attestations for official main-branch builds; binaries remain Authenticode unsigned pending SignPath Foundation approval.


## ProjectShell v1 — Standalone CLI

ProjectShell's standalone CLI version brings project shortcuts, saved starting directories, startup commands, and numbered menus together in one PowerShell project manager for Windows.

### Features

- Create labeled shortcuts and separate PowerShell windows for different projects or tasks.
- Assign project groups, starting folders, and optional startup actions.
- Choose normal or administrator launches when creating project shortcuts.
- Use numbered manager and session menus, including `psmenu`, `psrestart`, and `pshome`.
- Install or update through a guided PowerShell installer, with a choice of installation folder and desktop manager shortcuts.
- Keep personal project profiles and startup commands in AppData rather than the public repository.
- Run the included diagnostic script to check shortcut targets and launch permissions.

### Installer and maintenance

- Added a Windows x64 native launcher, `Install-ProjectShell.exe`, that runs alongside `Install-ProjectShell.ps1` rather than replacing it.
- Added an `asInvoker` manifest to avoid automatically requesting administrator rights based on the installer name.
- Added an optional `-InstallRoot` setting and a local installation fallback for computers without a `D:` drive.
- Corrected the native installer build so it does not depend on missing C runtime string functions.
- Added GitHub Actions checks for Windows PowerShell 5.1 and PowerShell 7, plus a native installer build and artifact upload.
- Updated the GitHub Actions dependencies for Node.js 24 compatibility.

### Notes

The standalone CLI is the current release. A graphical interface as part of Nathan's Toolkit is planned for later.

The installer is currently unsigned, and building it in GitHub Actions does not replace real Windows desktop testing. See [README.md](README.md) and [native/BUILD.md](native/BUILD.md) for installation and packaging details.
