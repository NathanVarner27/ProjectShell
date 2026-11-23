# Application Name Transition and Migration — preview v1

**Status:** Post-v1.1.0 development feature. Local ProjectShell metadata migration is implemented; a full external application rename is NOT automatically performed or verified.

## Purpose

ProjectShell provides a guided pathway when a separate application changes its public name. GitHub Package Builder is growing beyond GitHub packages, but its official replacement name is **not selected yet**. Do not publish or rename the actual project using a synthetic label from the regression tests.

A complete rename includes much more than changing a desktop shortcut. ProjectShell can inventory the work and update **ProjectShell-owned display names only**. The developer remains responsible for editing and validating the application itself. This is **not** a folder, source-code, GitHub-repository or installed-program renamer.

## Start the wizard

- ProjectShell Manager: **16 — Application name transition / migration**
- Open project session (`psmenu`): **10**
- DevTools/workspace menu: **9**

1. Select **1 — Plan/preview**, enter the existing application name and proposed new name. The old name must match a ProjectShell profile/workspace name exactly or be followed by ` - ` and a suffix (e.g. "GitHub Package Builder - Testing"). Abbreviated names such as `GPB` and `GHPB`, and folders like `GitHubPackageBuilder`, are **not silently rewritten**.
2. Review the matched project titles, profile groups, workspace labels and desktop shortcut filenames. **Preview does not change any files.**
3. Choose **2 — Apply**, confirm a default-no prompt, and type exactly `RENAME <old name>`.
4. ProjectShell writes a receipt and copies the original metadata/owned shortcuts to `%LOCALAPPDATA%\ProjectShell\name-migrations\<timestamp>-<id>\`, updates matching display names, and regenerates verified desktop shortcuts. Previous links are removed only when ProjectShell verifies that they target the corresponding ProjectShell profile. Unknown/unowned desktop links are left untouched.
5. Choose **3 — Verify** to check metadata hashes and desktop shortcut presence. **This is not an application-wide verification.**
6. Choose **4 — Roll back**. The app requires `ROLLBACK <receipt ID>` and refuses if source data changed, backups fail SHA-256 verification, or former shortcut paths are occupied.

Application folders, executable paths, source files, GitHub projects, manifests, startup command text and other developer-owned assets are never automatically renamed. Nathan's Catalogue integration remains independent.

## What counts as a full naming transition?

A project cannot be marked fully renamed until the **application owner** verifies all applicable areas:

| Area | Required checks | Current ProjectShell scope |
| --- | --- | --- |
| Public identity | Windows titles, menus, help, about text, accessible labels | Local ProjectShell labels only |
| Launch behavior | Profiles, desktop shortcuts, working folder, standard/admin privileges | Local profile name/link replacement with backup and restore |
| Application source | Internal names, CLI commands, app IDs, modules, APIs, README/tests | Manual developer change and regression testing |
| Distribution | EXE, ZIP, MSIX, installer/uninstall identity, update detection | Manual; no binary editing or signing |
| GitHub | Repository URL and redirects, workflows, release tags, downloads | Manual; no GitHub mutation |
| Stored user data | Old config paths, upgrades, legacy aliases and compatibility | External app-specific migration tests |
| Dependencies | Catalogue identifiers, structured broker requests and version agreements | Not rewritten; check after changing product app ID |
| Safety and recovery | Backups, rollback, source integrity, Windows tests, UAC | Local ProjectShell metadata safety only; remaining checks external |

A migration can be **partially complete** even if ProjectShell's titles are updated. The verification command always reports **external application rename not verified**.

## GitHub Package Builder — first pilot

**Existing name:** GitHub Package Builder.

**Official new name:** Developer selection pending.

**Synthetic test name:** Distribution Builder Pilot (temporary fixture only, never an approved product name).

### Stage A — Isolated ProjectShell tests

- [ ] Preview recognizes the main shortcut, suffixed testing shortcut and matching workspace.
- [ ] Preview leaves user metadata and external application files untouched.
- [ ] Apply requires exact consent, records snapshot backups and changes only ProjectShell-owned labels.
- [ ] Start folders, startup content, launchables, unrelated projects and abbreviations remain unchanged.
- [ ] New shortcuts verify; old ProjectShell-owned shortcuts can be safely replaced.
- [ ] Rollback restores previous saved data and owned shortcuts.
- [ ] Unsafe names and stale plans are rejected.

Tests are defined in `tests/Test-NameMigration.ps1`; verify successful Windows PowerShell 5.1/7 CI before checking these items.

### Stage B — Real GitHub Package Builder naming transition (NOT DONE)

- [ ] Select a new public name, shortened executable name, command name, app identifier and tagline.
- [ ] Back up the actual source, installation, manifests, settings, release automation and ProjectShell profiles.
- [ ] Update application-owned names in a reviewable development branch; retain existing data and backward-compatible aliases/migrations.
- [ ] Use ProjectShell's preview and approved local metadata transition; verify normal and admin shortcuts and launcher paths.
- [ ] Build and test the newly named ZIP, EXE and planned MSIX; test installation and upgrade on Windows without overwriting v1.1.0 ProjectShell.
- [ ] Verify existing users' settings, paths, and shortcuts survive the app rename.
- [ ] Verify GitHub repository, redirect/backlinks, release assets and documentation match the official selected name.
- [ ] Run security, uninstall and rollback checks; document unsupported rename surfaces.

**Full transition gate:** Stage B must pass before describing GitHub Package Builder as fully renamed or publishing its new identity.

## Safety limits / unsupported operations

- No arbitrary search-and-replace inside source trees, ZIP, EXE, MSIX, binaries or unknown settings.
- No automatic folder moves or deletion, background installer, elevation, package installation, GitHub commit/push/rename or release publication.
- No silent rewriting of user-configured startup commands or executable paths.
- No automatic updates for old abbreviations, aliases or unrelated profiles.
- Case-only renames, duplicate names, modified metadata, or reused old shortcut destinations may need explicit manual resolution.
- Rollback requires stored post-migration metadata and backup SHA-256 checks to match. Keep independent backups for any external application-wide migration.

This is post-**ProjectShell v1.1.0** development. The published v1.1.0 release is unchanged.