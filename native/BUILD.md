# Building the Windows installer executable

`Install-ProjectShell.exe` is a small native Windows x64 launcher. It opens a **new, normal-user Windows PowerShell console** with `Install-ProjectShell.ps1` in the same extracted folder. It does not contain or replace the PowerShell application's code. The console remains open after installation so prompts, completion messages, and errors can be reviewed.

The EXE embeds a requested execution level of `asInvoker` to avoid an unwanted elevation prompt based only on the executable's installer-like name. The PowerShell script controls the installation settings, including the numbered installation-folder selection (`-Guided`) and manager/desktop shortcuts. The launcher **never requests UAC directly**.

## Build

From a system with LLVM `clang-cl`, `lld-link`, Bash, and Python 3:

```bash
bash scripts/build-native-installer.sh
```

This generates `Install-ProjectShell.exe` in the repository root. The source is in `native/InstallLauncher.c`; `.def` files declare the Windows DLL imports. The generated `.exe` is a release artifact, not a required tracked Git source file.

## Package

Distribute the EXE together with `Install-ProjectShell.ps1`, `ProjectShell.ps1`, and `Diagnose-Launch.ps1`; optionally include the README and license. **Do not distribute the EXE alone.** The script must be present beside the executable. Users should extract the ZIP before double-clicking the EXE.

## Security and release gates

- Windows SmartScreen may warn because the executable is **unsigned**. Do not imply it is digitally signed.
- The PowerShell child uses a process-local `-ExecutionPolicy Bypass` because the existing application uses unsigned scripts. This does not change machine-wide policy or override Windows UAC.
- The EXE is intentionally `asInvoker`; it cannot force an already elevated parent launch context to become standard-user.
- `scripts/check-installer-pe.py` checks binary structure and the embedded manifest **only**. Test a complete installation, with desktop shortcuts and both standard/admin launch modes, on real Windows before v1 stable tagging.
