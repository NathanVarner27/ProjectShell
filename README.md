# ProjectShell

**An accessibility-first PowerShell project manager for Windows.**

When you're working in several PowerShell windows, it can be difficult to remember which session belongs to which project—or which commands you need to run before you can start working. ProjectShell is meant to make that easier. It gives each project a name, a starting folder, and its own shortcuts so you can spend more time working and less time setting everything up again.

I built ProjectShell with accessibility in mind, especially for people with ADHD, people learning PowerShell, and anyone trying to keep several projects or different parts of the same application straight.

## What ProjectShell does

### Keep projects separate

Give each project its own labeled shortcut and window title. If you're working on several related projects at once, you can tell which PowerShell window is which instead of guessing.

### Start in the right folder

Choose the folder a project should open in. When you use its shortcut, PowerShell starts there without making you navigate to the same directory again.

### Save startup commands

Some projects need the same setup commands every session. Save a startup action for the project so you can get to coding or testing without typing those commands every time.

### Switch between projects

Keep shortcuts for separate projects, or for different tasks within one larger project. You can return to the session you need without searching for its folder and setup instructions.

### Choose how a project launches

Some testing tasks require administrator access; others don't. ProjectShell lets you configure normal and administrator launch options. Use the normal option unless the task specifically needs administrator rights.

### Use a guided menu

The manager uses numbered choices instead of making you memorize its commands. You can create, check, and manage project shortcuts from that menu.

## What you'll need

- Windows 10 or 11 with an interactive desktop and Windows Explorer.
- Windows PowerShell 5.1 for standard manager and project shortcuts.
- PowerShell 7 is recommended for elevated sessions, but isn't required; ProjectShell can fall back to Windows PowerShell.
- A local folder you can write to. You **do not** need a `D:` drive.

Standard shortcuts use Windows PowerShell 5.1 intentionally. On some computers, PowerShell 7 has been configured to always run as administrator. If your project needs PowerShell 7-only commands, you may need to adjust its setup.

## Install or update ProjectShell

1. Download or clone this repository, or use a complete installer package if one is available under [Releases](https://github.com/NathanVarner27/ProjectShell/releases). Extract the ZIP before installing, and use a folder you trust.
2. Review the PowerShell scripts (`.ps1`) before running them. ProjectShell creates Windows shortcuts and saves your project settings locally.
3. On Windows x64, the easiest option is to double-click `Install-ProjectShell.exe` **if it is included in your downloaded package**. The GitHub source ZIP does not include a compiled installer. Follow the numbered prompts to pick an installation folder and choose whether you want desktop shortcuts.
4. If the installer EXE isn't included, or you prefer running the source script, open a regular (not administrator) Windows PowerShell window in the extracted folder and enter:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-ProjectShell.ps1"
```

ProjectShell suggests `D:\DevTools\ProjectShell` when a `D:` drive is present. Otherwise it uses `%LOCALAPPDATA%\Programs\ProjectShell`. You can choose another folder with `-InstallRoot`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-ProjectShell.ps1" -InstallRoot "C:\Tools\ProjectShell"
```

For updates, stick with the same installation folder. The installer lets you choose whether the normal manager, administrator manager, both, or neither should appear on your desktop. Both manager shortcuts are created in the installation folder regardless.

**About the EXE:** `Install-ProjectShell.exe` is a small launcher, not an all-in-one installer. It needs `Install-ProjectShell.ps1` beside it. It opens a standard-user console instead of automatically asking for administrator privileges. Since the EXE is unsigned, Windows SmartScreen may show a warning. See [how the installer is built](native/BUILD.md) for details.

### A note about `-ExecutionPolicy Bypass`

The command above applies that setting only to the PowerShell process it starts; it doesn't change the computer's system-wide execution policy. ProjectShell also uses it for local shortcuts. Only run scripts and startup commands you trust. This does not turn off Windows UAC or override rules set by your organization.

## Getting started

Open **Project Shell Manager.lnk** from your desktop or the installation folder. Select **1** to create a shortcut, then choose its name, project group, existing starting directory, startup action, and whether it needs administrator access.

Each project shortcut opens a separate window with the name you saved. Once it's open, these commands are available:

| Command | What it does |
| --- | --- |
| `psmenu` | Opens the session's numbered menu. |
| `psrestart` | Runs the project's startup task again. |
| `pshome` | Takes you to your normal Windows home folder without changing the saved project starting directory. |

If you're testing a normal session, choose **Admin: No** and **Classic PowerShell Console**. Windows Terminal is an option, but its own settings can affect how it launches and whether it elevates.

## Your project settings

ProjectShell keeps your settings on your own computer:

| Item | Location |
| --- | --- |
| Application scripts and manager shortcuts | Your selected installation folder |
| Project profiles and saved startup actions | `%LOCALAPPDATA%\ProjectShell\profiles.json` |
| Desktop preferences | `%LOCALAPPDATA%\ProjectShell\settings.json` |
| Created project shortcuts | The Windows desktop folder chosen during installation |

Updating ProjectShell keeps your saved profiles and startup commands in place. These personal files aren't meant to go in the public GitHub repository. **Don't upload your profiles, settings, logs, backups, or personal `.lnk` files**, since they may reveal local folders or commands.

## If a shortcut isn't working

From the installed ProjectShell folder, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Diagnose-Launch.ps1"
```

This checks the launch paths, permission information, Windows compatibility flags, and shortcut targets without changing your Windows settings. You can also choose **12 — Audit project shortcut elevation settings** in the manager.

If a normal shortcut unexpectedly opens as administrator, close the elevated window and try opening the normal manager shortcut directly from a regular Windows Explorer window. A shortcut cannot remove privileges from a process that's already elevated.

## Stable release and what's next

**ProjectShell is the stable, standalone CLI version of the application.** You can manage your PowerShell projects now without waiting for a graphical interface. If something doesn't work correctly on your computer, check the shortcut settings or use the diagnostic script above. Windows installations and administrator settings can vary, so I still want to hear about problems people run into.

Automated source checks pass under Windows PowerShell 5.1 and PowerShell 7, and the Windows x64 installer builds successfully. Those checks do not replace trying installation, shortcuts, and UAC on an actual Windows desktop.

Next, I plan to bring ProjectShell into Nathan's Toolkit as part of the larger Nathan's Ecosystem. That version will have a graphical interface. For now, ProjectShell is CLI-only.

## Technologies and acknowledgments

ProjectShell uses PowerShell, Microsoft .NET and Windows features such as Windows Script Host, the Windows Shell API, and User Account Control. Windows Terminal is an optional way to open sessions. Git and GitHub are used for version control and hosting.

I'm listing these because they were used to build or manage the project, not because the companies behind them worked on ProjectShell.

## Developer and license

Developed by **NathanVarner27** for future integration into the larger **Nathan's Ecosystem**.

ProjectShell is provided under the [Apache License, Version 2.0](LICENSE). See the repository's license file for the terms.
