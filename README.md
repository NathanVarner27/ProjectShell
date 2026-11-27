# ProjectShell

**A free, open-source, accessibility-first PowerShell project and workspace manager for Windows.**

ProjectShell is a free, open-source, accessibility-first PowerShell project and workspace manager for Windows. It helps users organize development tools, configure project workspaces, create desktop shortcuts, and launch saved applications through a guided, numbered command-line interface.

ProjectShell is developed and maintained by **NathanVarner27** and distributed under the **Apache License 2.0**. Its source code and build workflows are publicly available on GitHub.

**Repository:** https://github.com/NathanVarner27/ProjectShell

When working in several PowerShell windows, ProjectShell gives each project a name, starting folder, and shortcut so users can keep sessions organized without retyping commands. It is designed with accessibility in mind, including users who benefit from guided menus instead of memorizing commands.

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

### Organize DevTools and import workspaces

Open **13 — DevTools folder and saved workspace/tool lookups** in the manager. Configure a default development-tools folder once (such as `D:\DevTools`), then create a new workspace, register an existing workspace folder, or import a folder or archive. The DevTools folder and ProjectShell's own installation folder are independent settings.

Import supports **folders and ZIP archives**, plus **RAR and 7Z** when 7-Zip is installed locally. Copy preserves the source. Move performs a copy first and verifies SHA-256 hashes before deleting the source after explicit user confirmation. Imports stage content under a temporary name and do not overwrite existing workspace folders. Only import archives you trust.

For each workspace, locate and save a **main launchable** (EXE, PS1, CMD, BAT, Python, JavaScript, or JAR) and optionally **an installer path** (saved separately). You can use suggestions, browse to a file, or type/paste its path. ProjectShell never runs the saved installer automatically.

### Launch a tool without leaving the menu

Inside a project session, **6** launches the saved main tool, **7** sets or changes it, and **8** opens saved workspace/tool lookups. The manager's **14** sets a shortcut's main launchable. During shortcut setup, startup option **4** can launch the saved main tool automatically when the shortcut opens, instead of merely opening the project folder.

An installer is not treated as the everyday main launchable. Existing project profiles work without a workspace registration.

### Optional system dependencies through Nathan's Catalogue (development preview)

ProjectShell continues to work independently. For missing optional system tools, it can generate a **Catalogue Dependency Broker v1** JSON request and open the independent Catalogue CLI for a **read-only preview**. It never installs, elevates, updates, removes, or automatically approves system dependencies. Catalogue v0.2.0-alpha.13's actual system-change workflow is **not production-approved**.

Choose **15** in the ProjectShell Manager, **9** in a project session menu, or **8** in the DevTools/workspace menu. During a RAR/7Z import, a missing 7-Zip also offers this preview. You can configure a user-selected Catalogue folder; it is never required for normal ProjectShell use. ProjectShell rechecks the dependency after the preview returns rather than trusting an exit code.

Recognized requests: optional **7-Zip** (WinGet exact ID), **Windows Sandbox** (Windows Optional Feature), and manual locators for **WinGet** and **Chocolatey**. General PowerShell modules, Python/Node/Java runtimes, and other Windows features are **not supported by this broker mapping**; follow the manual fallback. See [Catalogue integration and supported dependencies](docs/PROJECTSHELL_CATALOGUE_DEPENDENCIES.md) for full details.


### Transition an application to a new name (post-v1.1 preview)

ProjectShell includes a guided **application name transition** workflow for independent software that is changing names. It previews the exact ProjectShell-managed profile, group, workspace and desktop shortcut labels, including one optional explicitly mapped legacy abbreviation, then requires explicit confirmation before changing local metadata. It creates a recoverable backup and offers verification and rollback. A separate bounded, read-only inventory can find old/new names within selected source files, but cannot verify binary or public distribution changes. **It does not rename application binaries, source trees, folders, GitHub repositories, published releases or user startup commands.**

Open **16 — Application name transition / migration** in the ProjectShell Manager, **10** in a project session, or **9** in the workspace tools menu. The developer must independently verify a complete product-wide rename, including EXE/ZIP/MSIX identity, install/upgrade compatibility, documented aliases and existing user settings.

**First pilot:** GitHub Package Builder. Its future public name has not yet been selected, so automated tests use a synthetic name, not a new published product identity. Follow the [migration guide and acceptance checklist](docs/PROJECTSHELL_APPLICATION_NAME_MIGRATION.md) before performing a real rename.

## What you'll need

- Windows 10 or 11 with an interactive desktop and Windows Explorer.
- Windows PowerShell 5.1 for standard manager and project shortcuts.
- PowerShell 7 is recommended for elevated sessions, but isn't required; ProjectShell can fall back to Windows PowerShell.
- A local folder you can write to. You **do not** need a `D:` drive.

Standard shortcuts use Windows PowerShell 5.1 intentionally. On some computers, PowerShell 7 has been configured to always run as administrator. If your project needs PowerShell 7-only commands, you may need to adjust its setup.

## Install or update ProjectShell

### Download the correct files

Download an official complete Windows package from [GitHub Releases](https://github.com/NathanVarner27/ProjectShell/releases), or clone/download the source repository. Extract a ZIP to a folder you trust before running anything; review scripts if you are unsure about a download.

The **repository-built** `Install-ProjectShell.exe` is a launcher, **not a self-contained installer**. It must be kept in the same extracted folder as `Install-ProjectShell.ps1`, `ProjectShell.ps1`, `ProjectShell.Workspaces.ps1`, `ProjectShell.Catalogue.ps1`, and `Diagnose-Launch.ps1`. The repository source ZIP does not include the compiled EXE. Only use a single-file standalone installer if it is explicitly published and verified as such in an official release.

Requirements: Windows 10/11, Windows PowerShell 5.1, a writable installation folder, and an interactive Windows desktop. The installer works as a standard user when installing into a user-writable folder.

### Guided installation settings

Double-click `Install-ProjectShell.exe` in the **extracted complete package**, or start the guided PowerShell script using `-Guided`. The numbered prompts are:

| Prompt | Choice | What it does |
| --- | --- | --- |
| Installation location | **1 — Recommended** (default) | Uses `D:\DevTools\ProjectShell` if `D:` exists; otherwise uses `%LOCALAPPDATA%\Programs\ProjectShell`. |
| Installation location | **2 — Local AppData** | Always uses `%LOCALAPPDATA%\Programs\ProjectShell`. |
| Installation location | **3 — Custom path** | Enter a full, absolute path to a writable folder. |
| Installation location | **0 — Cancel** | Stops installation. |
| Desktop manager shortcuts | **1 — Normal only** (default) | Creates/updates the regular manager shortcut on your selected desktop. |
| Desktop manager shortcuts | **2 — Normal and Administrator** | Creates/updates both desktop manager shortcuts. |
| Desktop manager shortcuts | **3 — Administrator only** | Creates/updates only the administrator shortcut on your selected desktop. |
| Desktop manager shortcuts | **0 — Skip desktop changes** | Leaves existing desktop shortcuts unchanged. |

The installer always creates the **normal** and **administrator** manager shortcuts inside the installation folder. If desktop installation is selected, it asks you to verify the actual desktop location (including redirected/OneDrive desktops). It may offer to move a previously installed, now-unselected desktop manager shortcut into a backup; this requires your response.

For existing profiles, the installer refreshes saved project shortcuts and may ask whether to switch Windows Terminal profiles to the classic PowerShell console. At the end it can optionally open File Explorer to a new desktop shortcut; it **does not launch the manager automatically**.

**Normal manager:** Windows PowerShell 5.1, without requesting administrator access. **Administrator manager:** requests Windows UAC permission, using PowerShell 7 when available. Only approve elevation when needed.

### Install from the source script

If the EXE is not included, run the script from the extracted folder in a **regular, non-administrator PowerShell** window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-ProjectShell.ps1" -Guided
```

For an unattended *location choice only* (other prompts remain interactive), specify an install path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-ProjectShell.ps1" -InstallRoot "C:\Tools\ProjectShell"
```

`-ExecutionPolicy Bypass` is scoped to the launched PowerShell process. It does not change system-wide execution policy or disable UAC. Run scripts and launchables only from sources you trust.

### Update without losing settings

Extract the newer official package, run its installer, and choose the **same installation folder** you used previously. ProjectShell updates application scripts and its shortcuts while preserving saved local data under `%LOCALAPPDATA%\ProjectShell` (including `profiles.json`, `settings.json`, and `workspaces.json`). If prompted, review changes to existing project shortcuts before accepting them. The DevTools workspace root is a separate setting and does not have to match the application installation folder.


### Unattended native installation (per-user)

The native launcher and standalone Setup EXE accept exactly `--silent` or
`--silent-with-progress`. Both install to `%LOCALAPPDATA%\Programs\ProjectShell`,
without requesting elevation, changing desktop shortcuts or refreshing profiles. The latter
shows a progress console. Unknown arguments fail without installing.
The per-user Apps & Features entry registers an unattended uninstaller that
removes only unchanged inventoried application files; user data and unrelated
files are preserved. An existing unmanaged installation or modified managed
files require manual review. Interactive installation and explicit script
installation paths retain their existing behavior and are not automatically
registered. The managed uninstaller does not delete the saved workspace or
profile directory.

### Uninstall ProjectShell (manual, user-controlled)

For interactive or explicitly located script installations without a registered uninstaller, remove ProjectShell safely as follows:

1. **Close** the ProjectShell Manager and any ProjectShell-launched sessions. Record your chosen installation folder if it differs from the recommended locations.
2. **Remove ProjectShell desktop shortcuts** you created, including `Project Shell Manager.lnk`, `Project Shell Manager (Administrator).lnk`, and any project shortcuts you want removed. For a custom project shortcut, check **Properties → Target** and verify it references ProjectShell before deleting it. If your desktop is redirected, check that location.
3. In the **actual ProjectShell application installation folder**, delete only ProjectShell-installed files: `ProjectShell.ps1`, `ProjectShell.Workspaces.ps1`, `ProjectShell.Catalogue.ps1`, `Install-ProjectShell.ps1`, `Install-ProjectShell.exe`, `Diagnose-Launch.ps1`, `README.md`, `README.txt` if present, and the two `Project Shell Manager*.lnk` shortcuts. If the folder has **no other files or projects**, you may remove the now-empty folder.
4. **Optional: remove saved settings.** Open File Explorer, enter `%LOCALAPPDATA%\ProjectShell`, and review its contents. Deleting that folder removes your saved project profiles, workspace/tool lookup registry, desktop settings, and ProjectShell backups. **Keep it** if you might reinstall or want to preserve those settings.
5. Delete the **downloaded/extracted installer ZIP** if you no longer need it.

**Important:** Uninstalling ProjectShell does **not** delete imported or registered workspaces, development tools, user source code, or any contents of a DevTools root such as `D:\DevTools`. Never delete a shared DevTools folder to uninstall ProjectShell. If you installed ProjectShell into a folder containing other work, remove only the known ProjectShell files listed above. Removing ProjectShell does not automatically restore files moved during an earlier workspace import.

## Code signing policy

ProjectShell applied to the **SignPath Foundation** program, but its application was **declined for insufficient public visibility and adoption**. The current GitHub-built Windows executables are **unsigned**; there is no approved SignPath certificate or signed-publisher claim. GitHub attestations and SHA-256 checksums support integrity/provenance verification, not Windows publisher trust.

See the [ProjectShell code signing policy](CODE_SIGNING_POLICY.md), including maintainer roles, privacy commitments, signing approvals, and how to verify a signed release. Only the official [Releases](https://github.com/NathanVarner27/ProjectShell/releases) page should be used for public installer downloads.

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

The workspace registry and selected DevTools root are saved locally in `%LOCALAPPDATA%\ProjectShell\workspaces.json`. This file is not part of the public repository.

ProjectShell keeps your settings on your own computer:

| Item | Location |
| --- | --- |
| Application scripts and manager shortcuts | Your selected installation folder |
| Project profiles and saved startup actions | `%LOCALAPPDATA%\ProjectShell\profiles.json` |
| Desktop preferences | `%LOCALAPPDATA%\ProjectShell\settings.json` |
| DevTools root and saved workspace/tool lookups | `%LOCALAPPDATA%\ProjectShell\workspaces.json` |
| Optional Catalogue location and generated broker requests | `%LOCALAPPDATA%\ProjectShell\catalogue-integration.json` and `dependency-requests\` |
| Created project shortcuts | The Windows desktop folder chosen during installation |
| Application naming migration receipts/backups | `%LOCALAPPDATA%\ProjectShell\name-migrations\` |

Updating ProjectShell keeps your saved profiles, workspace registry, and startup commands in place. These personal files aren't meant to go in the public GitHub repository. **Don't upload your profiles, settings, logs, backups, or personal `.lnk` files**, since they may reveal local folders or commands.

### Active ProjectShell folder handoff (v1.2.0)

When a ProjectShell project session starts or launches its saved tool, it passes the saved `StartDirectory` as `PROJECTSHELL_START_DIRECTORY` **in that process only**. Children such as Distribution Builder Pilot can propose the exact workspace folder even after you change directories. This is not written to persistent user/system environment settings, and ProjectShell does not expose your profile store to other applications.

The application-name migration wizard changes ProjectShell-managed names and verified desktop links only. It does not move external application files or rewrite saved folder paths, launchables or startup commands; edit those separately in the Manager.

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

Developed and maintained by **NathanVarner27** for future integration into the larger **Nathan's Ecosystem**.

ProjectShell is provided under the [Apache License, Version 2.0](LICENSE). See the repository's license file for the terms.


## ProjectShell v1.2.0

ProjectShell continues to streamline accessible PowerShell
workflows through guided, lightweight project management.

### Version 1.2.0 highlights

- Improved workspace and session management.
- Configurable primary application launchables.
- DevTools directory integration.
- Application name transition and migration assistance.
- Dependency discovery through Nathan's Catalogue.

### Distribution development

Windows ZIP, standalone EXE, and MSIX preview distributions
are being prepared using Distribution Builder Pilot (DBP).

Final distribution acceptance remains in progress.
The unsigned MSIX is a development preview.
