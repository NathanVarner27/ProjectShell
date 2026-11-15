# Changelog

## V1 ProjectShell

- Added native Windows x64 `Install-ProjectShell.exe` alongside script-based installation.
- Embedded `asInvoker` manifest to avoid unintended UAC prompts based on installer file name.
- Added numbered installation-location selection when started by EXE (`-Guided`).
- Added native launcher build recipe, structural tests, and CI build workflow.
- Reused the revised accessibility-first README, GitHub description, and CLI-first development plan.
- Kept saved profiles and user shortcuts outside repository source control.
- Created a documented repository layout, Git ignore rules, release checklist, and syntax-validation workflow.
- Kept the existing profile store separate from source control.
- Added optional `-InstallRoot` for installations and a user-local fallback on computers without `D:`.
- Changed the diagnostic script to use its own folder by default (with optional `-InstallRoot`).
