# Contributing

For now, keep changes narrowly scoped and describe which Windows/PowerShell versions you tested. Include a reproduction for shortcut creation, elevation, desktop-folder detection, or project-session errors. Never attach `profiles.json`, real desktop `.lnk` files, or unredacted diagnostics from your personal machine.

Run the validation script on Windows with **both** Windows PowerShell 5.1 and PowerShell 7:

```powershell
powershell.exe -NoProfile -File .\tests\Test-Source.ps1
pwsh.exe -NoProfile -File .\tests\Test-Source.ps1
```

Do not run real elevated/UAC tests in automated CI; those require an interactive Windows desktop.
