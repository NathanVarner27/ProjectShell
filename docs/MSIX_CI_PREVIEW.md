# ProjectShell manager/MSIX CI structural preview — development only

## What this change does

- Builds `ProjectShell-Manager.exe` **from committed `native/ManagerLauncher.c`** using the already existing `scripts/build-manager-launcher.sh` on an Ubuntu GitHub Actions runner with LLVM.
- Runs the existing 7 manager source checks and 9 MSIX preview checks.
- Stages four existing ProjectShell PowerShell scripts, the new source-built executable, temporary PNG assets, and a temporary full-trust MSIX manifest.
- Uses Windows SDK `makeappx.exe` on a Windows CI runner to build and verify an **unsigned structural MSIX preview**.
- Uploads CI artifacts only; does not sign, install, register, publish GitHub Releases or GitHub Packages, or submit to Partner Center.

## Release boundaries

- This is NOT the final `v1.2.0` installer distribution and is NOT Store-ready.
- The main `installer-build.yml` continues to make the existing traditional ZIP and standalone Setup EXE independently.
- Do not commit the locally compiled `ProjectShell-Manager.exe`. Source-built unsigned EXE is CI-generated.
- The CI package identity `ProjectShell.CI.Preview` and temporary icon assets must **never be used as official Store assets**.
- Prior Phase A runtime acceptance on the owner's PC is not equivalent to launching the MSIX package after installation.
- Separate MSIX installation/update/uninstall, clean-machine tests, Store identity, branded assets, signing, and certification remain outstanding. Separate local-account testing was waived, not passed.
- The standing 90-file ProjectShell backup remains local and should not be uploaded or included in the repository.

## Review and eventual publication

Keep the branch development-only while CI checks run. Before any release: review final commit, tag, source-derived ZIP/EXE/MSIX, checksums, official Partner Center identity, proper signing or Store signing, and deployment outcomes. The public v1.1.0 GitHub release remains unchanged during this preview.
