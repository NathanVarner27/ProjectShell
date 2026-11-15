# ProjectShell — Development plan

This document distinguishes existing implementation from the remaining work needed for a reliable **v1.0** release. No Git commit, tag, release, or push is authorized by this document.

## 1. Standalone CLI foundation — implemented, Windows verification in progress

- Numbered manager and project session menus.
- Project-specific desktop shortcuts and recognizable terminal titles.
- Saved starting directories, optional startup scripts/commands, project groups, and alternate starting points.
- Normal and explicit administrator manager/project profiles.
- Desktop shortcut creation, editing, cloning, refreshing, diagnostics, and profile persistence.
- Session commands `psmenu`, `psrestart`, and `pshome`.
- Guided installation, both manager shortcuts inside the installation folder, configurable desktop placement, and in-place updates.

**Important:** Source-level/static checks are not proof that every workflow functions on Windows. In particular, Admin: No / Admin: Yes, custom desktop locations, and startup-task behavior require live verification.

## 2. First Windows executable installer — built, verification pending

- A lightweight native `Install-ProjectShell.exe` starts the existing script-based installer in a numbered PowerShell console.
- The executable uses `asInvoker` rather than silently requesting administrator rights.
- The installer asks for the destination folder and desktop manager shortcut preferences.
- Install from the extracted ZIP and retain the companion `.ps1` source alongside it.
- Test the executable on Windows 10 and Windows 11, including PCs without D: and systems with UAC enabled.
- Check whether Windows SmartScreen warns for the unsigned binary; document signing as a later release task.

## 3. Pre-v1 release verification — required before stable tag

1. Run `tests/Test-Source.ps1` under Windows PowerShell 5.1 and PowerShell 7.
2. Build the native launcher from source and inspect the embedded `asInvoker` manifest.
3. Test double-click installation, update, optional folder selection, Desktop visibility, and both folder launchers.
4. Verify new Admin: No project shortcuts open standard-user PowerShell without UAC.
5. Verify Admin: Yes paths explicitly request UAC, and do not accidentally elevate Admin: No tasks.
6. Verify local scripts/commands, `psmenu`/`pshome`/`psrestart`, and multiple independent titles.
7. Reinstall with existing profiles and confirm paths, commands, names, and preferences survive.
8. Review tracked files and ensure no local profile, shortcut, log, backup, or sensitive Windows path enters the repository.
9. Confirm intended Apache 2.0 license and add full official `LICENSE` text before identifying the project as open source.
10. Review `README.md`, `PROJECT-DESCRIPTION.md`, `SECURITY.md`, and changelog, then commit locally. Push/tag/create a GitHub release **only when the owner explicitly chooses**.

## 4. After v1 — future direction, not part of the current release

- Improve install/update distribution and consider code signing.
- Expand verified OS/PowerShell compatibility coverage.
- Continue the standalone CLI as a simple, reusable utility.
- Integrate into Nathan's Toolkit/Nathan's Ecosystem later, including an optional graphical interface, without removing the independent CLI workflow.

**Non-goal for v1:** turning ProjectShell into an AI-dependent service or requiring an online account.
