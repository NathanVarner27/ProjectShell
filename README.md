# ProjectShell

**An accessibility-first PowerShell project manager for Windows.**

ProjectShell helps people keep their PowerShell projects and sessions separate without having to type the same commands every time they start working. It's designed for people who need a more accessible way to manage PowerShell, including users with ADHD, beginners, and anyone working across several projects at once.

## Core Features

### Project Shortcuts

When you have several PowerShell sessions open, it isn't always obvious which one belongs to which project. That gets even harder when you're switching between projects or working on several parts of the same application. ProjectShell lets you create labeled shortcuts so you can tell them apart more easily.

### Project Directories

Open a session directly in the folder you've assigned to a project. That way, you can focus on the commands you're trying to run instead of navigating back to the same directory each time.

### Startup Commands

Instead of initializing the same project every time you open PowerShell, save the startup commands you need and get straight to coding or testing.

### Project Switching

Work across several projects, including ones that support or connect to a larger project. Saved launch configurations make it easier to move between them without repeatedly searching for folders and commands.

### Launch Options and Permissions

Some projects need different permissions to run or test correctly. Create shortcuts for normal or administrator launches so you don't have to keep reopening PowerShell and setting up the same session again.

### Numbered CLI Navigation

A guided, lightweight numbered menu gives users access to ProjectShell's features without requiring them to memorize complicated commands.

### Project Window Identification

Clearly labeled PowerShell windows help you see which project you're working on. This is especially useful when several sessions are open for related projects or different parts of the same application.

## Requirements

- Windows 10/11, interactive desktop session with Explorer/Windows Shell.
- Windows PowerShell 5.1 for **standard project and manager shortcuts** (included with supported Windows installations).
- PowerShell 7 is preferred for elevated sessions; the app falls back to Windows PowerShell if it is unavailable.
- A local folder where you can install and update the application. A `D:` drive is **not** required.
- Normal shortcuts intentionally use Windows PowerShell 5.1 because some computers have a PowerShell 7 executable configured to always elevate. Commands requiring PowerShell 7-specific features may need a different setup.

## Install or update

1. Download or clone this repository into a folder you trust, then extract the complete ZIP.
2. Review the `.ps1` files before running them. The app creates `.lnk` shortcuts and stores profile settings locally.
3. **Recommended for Windows x64:** double-click `Install-ProjectShell.exe` in the extracted folder, then choose a numbered installation location and desktop shortcut preferences. The installer uses a standard-user console and stays open after completion.
4. **Source-only alternative:** open a non-elevated Windows PowerShell in the folder and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-ProjectShell.ps1"
```

By default, the installation folder is:
- `D:\DevTools\ProjectShell` **if `D:` exists**, otherwise
- `%LOCALAPPDATA%\Programs\ProjectShell`

For a different folder, supply `-InstallRoot`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-ProjectShell.ps1" -InstallRoot "C:\Tools\ProjectShell"
```

If you prefer to keep it at `D:\DevTools\ProjectShell`, always use that same path for updates. During installation, choose whether to put the normal manager, admin manager, both, or neither on the desktop. **Both** are always created in the installation folder.

The installer does **not** automatically start an elevated manager. The `.exe` requires `Install-ProjectShell.ps1` in the same extracted folder; it is not a fully self-contained setup program. The standard-user executable has an explicit `asInvoker` elevation manifest. The unsigned executable can still trigger Windows SmartScreen warnings. See [native/BUILD.md](native/BUILD.md) for build details.

### Why `-ExecutionPolicy Bypass` appears

This switch applies to the launched PowerShell process; it does not change system-wide execution policy. The app also uses it in generated local shortcuts. **Do not run untrusted scripts or saved startup commands.** Organization-enforced policies can still block execution; the installer does not disable Windows UAC or change executable compatibility flags.

## Use

Open **Project Shell Manager.lnk** from the desktop or installation folder. Choose **1** to create a new shortcut. Give it a name, project group, existing starting directory, startup action, and administrator preference.

Each project shortcut launches its own window. The window title is your saved name. Use `psmenu` to reopen the session menu, `psrestart` to restart the startup task, or `pshome` to switch to your ordinary Windows home folder. The saved project starting folder is not changed by `pshome`.

For a standard test session, select **Admin: No** and **Classic PowerShell Console**. Use **Admin: Yes** only when the task actually requires administrator rights. Windows Terminal can have its own launch/elevation behaviors; classic console is the more reliable default.

## Where data is stored

- **Application scripts and two manager `.lnk` files:** the selected install folder.
- **Profiles:** `%LOCALAPPDATA%\ProjectShell\profiles.json`
- **Desktop selection/settings:** `%LOCALAPPDATA%\ProjectShell\settings.json`
- **Project `.lnk` files:** the Windows desktop folder selected during installation.

Existing profiles and startup commands are retained on update. Neither saved profiles nor generated desktop shortcuts are part of this repository. **Do not commit personal `profiles.json`, `settings.json`, logs, backups, or `.lnk` files.** Profiles can contain local folder names and user-defined commands.

## Troubleshooting

Run the read-only diagnostic script from the installed application folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Diagnose-Launch.ps1"
```

It prints executable paths, effective elevation information, compatibility flags, and shortcut targets. It does not change Windows settings. The manager's **12 — Audit project shortcut elevation settings** also checks installed project shortcuts.

If the normal manager says it is elevated, close the elevated installer/PowerShell window and open the normal manager shortcut from ordinary Windows Explorer. A normal `.lnk` cannot strip privileges from an already elevated parent process.

## Testing and status

GitHub Actions checks PowerShell syntax on **Windows PowerShell 5.1 and PowerShell 7**, plus source-level safety invariants. These are not substitutes for real Windows UAC and desktop shortcut tests. See [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) for manual verification.

**Status:** Pre-v1 release candidate. Windows clean-install, shortcut visibility, standard launch, and UAC tests remain required before advertising a stable release.

## Development and license

See [DEVELOPMENT-PLAN.md](DEVELOPMENT-PLAN.md) for the approved CLI-first direction and the outstanding v1 validation gates, and [PROJECT-DESCRIPTION.md](PROJECT-DESCRIPTION.md) for the GitHub description and audience.

ProjectShell was developed by **NathanVarner27**. A future GUI integration into Nathan's Toolkit is planned, but is not part of this standalone CLI release. The intended open-source license is **Apache License 2.0**, pending addition of the complete `LICENSE` file and final owner approval; do not advertise the current candidate as licensed open source yet.
