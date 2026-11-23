# ProjectShell and Nathan's Catalogue — Dependency Broker v1

**Status:** Optional preview-only integration based on Catalogue v0.2.0-alpha.13.
**Authority:** Catalogue docs/DEPENDENCY_BROKER_V1.md, schema_version 1.

ProjectShell stays an independent, local-first project manager. Catalogue is an optional coordinator for operating-system prerequisites, not an execution engine, profile registry, logger or ProjectShell installer.

## Where to find it

- ProjectShell Manager: option **15**, Optional system dependencies (Catalogue preview).
- Project session (psmenu): option **9**.
- DevTools / saved workspace tools menu: option **8**.
- On RAR/7Z import with no 7z.exe: an explicitly declined-by-default prompt offers a Catalogue review.

Nothing is launched during ordinary ProjectShell startup.

## Configuration and handoff

Select dependency menu option **6** and choose the local Catalogue folder that includes artifacts\NathansCatalogue.pyz. ProjectShell stores the location in %LOCALAPPDATA%\ProjectShell\catalogue-integration.json. The optional NATHANS_CATALOGUE_ROOT environment variable can also point to Catalogue. D:\DevTools\catalogue is a development example, not an assumed installed path.

During alpha.13, ProjectShell uses the current Catalogue Python zipapp with an installed Python 3 launcher, avoiding potentially stale dist executables. It generates a bounded, declarative, UTF-8 without BOM request under %LOCALAPPDATA%\ProjectShell\dependency-requests\, asks for permission to preview, and runs only the independent Catalogue **dependency-request** CLI command in the existing terminal.

**No --interactive-apply. No installs, upgrades, repairs, uninstalls, network downloads, silent approval, privilege escalation, or background installers.** On return, ProjectShell re-detects the dependency rather than treating process exit codes as install success.

See [ProjectShell broker-v1 request sample](../examples/dependency-bridge/project-shell.json).

## Dependency mapping and limitations

| Dependency | Read-only detection | Catalogue broker v1 request | Notes |
| --- | --- | --- | --- |
| 7-Zip for RAR and 7Z imports | 7z.exe in PATH / usual Program Files | winget / install / 7zip.7zip | Optional; ZIP imports work without it. Review exact ID, provider and publisher separately. |
| Windows Sandbox | Get-WindowsOptionalFeature -Online, feature Containers-DisposableClientVM | windows-feature / enable / windows-sandbox | Optional test tool, **not** a WinGet package. Requires edition, virtualization and reboot/privilege review. If state cannot be read, status is Unknown. |
| WinGet | winget.exe in PATH | manual / locate / winget | Presence is not signature, publisher or compatibility verification. |
| Chocolatey | choco.exe in PATH | manual / locate / chocolatey | No self-install or repair automation. |
| PowerShell 7 | pwsh.exe presence | Unsupported | Optional; Windows PowerShell 5.1 remains supported. |
| PowerShell modules | App-specific | Unsupported | Broker v1 has no generic PowerShell module installation operation. |
| Python / Node / Java / Git / other runtimes | Depends on saved launchable | Not mapped | No trustworthy universal package/version rule. Review and configure manually. |
| Other Windows features | Varies | Unsupported | Broker v1 only supports Windows Sandbox. |

Executable presence is **not** trusted publisher, exact version compatibility, installation completeness or operational testing. Those checks remain open security gates. Catalogue alone owns reviewed system changes and receipts. ProjectShell owns shortcut privileges, workspaces, saved tools and local settings.

If Catalogue or Python is unavailable, ProjectShell keeps working, prints the saved request location, and offers manual vendor documentation/setup outside ProjectShell. The existing README uninstall and security rules remain unchanged.
