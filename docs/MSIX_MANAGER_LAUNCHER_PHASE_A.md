# ProjectShell experimental manager launcher - Phase A

This stage adds only a distinct native entry point that runs ProjectShell.ps1 rather than the traditional installer. It does not package, install, publish, sign or certify MSIX. The existing Install-ProjectShell.exe and standalone Setup.exe remain separate.

Local acceptance stages:
1. Review and parse PowerShell source, confirm no replacement of tracked files.
2. Compile ProjectShell-Manager.exe using clang-cl/lld-link, or run the build in a controlled CI branch.
3. On an isolated Windows user profile, launch manager EXE, confirm numbered menus and closing behavior. Never run a live manager from production profiles without review; manager can modify its own profile store during normal use.
4. Only then create a test MSIX using a temporary identity, real PNG assets, uap10:RuntimeBehavior=packagedClassicApp and uap10:TrustLevel=mediumIL; MakeAppx structural test is insufficient.
5. Verify signed development MSIX (using a development-only trusted test certificate in a disposable VM) install/launch/update/uninstall and profile preservation; confirm the packaged PowerShell child process still functions and ownership of desktop shortcuts across upgrades. Do not install unsigned MSIX.
6. Get Partner Center identity, store requirements, and certified MSIX release approval before calling it store-ready.

Main blocker: Microsoft's MSIX guidelines caution desktop apps against launching command utilities such as PowerShell. ProjectShell intentionally relies on PowerShell, so Microsoft Store compatibility is **unproven** and may require an alternative submission/channel. Never promise Store acceptance.
