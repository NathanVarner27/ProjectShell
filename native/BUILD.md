# Building the Windows x64 installer

`Install-ProjectShell.exe` is a small Windows launcher for ProjectShell's guided PowerShell installer. It starts `Install-ProjectShell.ps1` in a new PowerShell console and leaves the console open so users can see installation prompts, results, or errors.

The executable **is not a self-contained installer**. It must be distributed with the PowerShell scripts it launches.

A **different binary**, `ProjectShell-v1.2.0-Windows-x64-Setup.exe`, is also built from the verified complete release ZIP by `scripts/build-standalone-installer.py`. That release asset **is self-contained**. Both EXEs are currently unsigned. SignPath Foundation declined ProjectShell's application on public visibility/adoption grounds; no Foundation signing is available.

## Build it

On a system with LLVM `clang-cl`, `lld-link`, Bash, and Python 3, run this from the repository folder:

```bash
bash scripts/build-native-installer.sh
```

The script builds `Install-ProjectShell.exe` in the repository root and then checks that it is a Windows x64 executable with the intended imports and `asInvoker` manifest.

The launcher source is in `native/InstallLauncher.c`. The `.def` files describe its Windows API imports. The build avoids a separate C runtime dependency.

GitHub Actions builds the unsigned launcher and the standalone setup EXE, and provides both as workflow artifacts. A successful build proves the executable was compiled and passed structural checks; it does **not** prove that installation or desktop shortcuts work on every Windows computer.

## Package it

Include these files together in the extracted installation folder:

- `Install-ProjectShell.exe`
- `Install-ProjectShell.ps1`
- `ProjectShell.ps1`
- `ProjectShell.Workspaces.ps1`
- `ProjectShell.Catalogue.ps1` (optional, preview-only system dependency handoff)
- `ProjectShell.Migration.ps1` (local application-name migration, backup and rollback)
- `Diagnose-Launch.ps1`

Also include `README.md`, `SECURITY.md`, `CODE_SIGNING_POLICY.md`, `CHANGELOG.md`, and `LICENSE` in a public distribution package. **Do not distribute the EXE by itself.** Users should extract the complete ZIP before running the bundled launcher; the separate `ProjectShell-v1.2.0-Windows-x64-Setup.exe` release asset does not require extraction.

## Permissions and Windows testing

The executable requests `asInvoker`, so it does not request elevation on its own. The launcher still cannot turn an already elevated process into a standard-user process.

The PowerShell installer uses a process-local `-ExecutionPolicy Bypass`; this does not change system-wide policy or disable UAC. The repository-built EXE is currently unsigned, so Windows SmartScreen may warn users. See the [code signing policy](../CODE_SIGNING_POLICY.md) for the declined SignPath application and unsigned release verification; no signing is claimed until a built artifact has a verified trusted Authenticode signature.

Before publishing a new downloadable installer package, test installation, updates, desktop shortcut selection, standard launches, and administrator launches on a real Windows desktop. Include testing on systems without a `D:` drive if possible.

For everyday installation instructions, see [README.md](../README.md).
