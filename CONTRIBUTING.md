# Contributing

ProjectShell is a standalone PowerShell project manager designed to make working across several projects easier, especially for people who benefit from a more accessible, guided workflow.

Bug reports and suggestions are welcome through GitHub Issues. If you report a problem, explain what you were trying to do, what happened, and which Windows and PowerShell versions you were using. For shortcut, installation, or administrator issues, include the steps needed to reproduce the problem.

Please **do not upload** your `profiles.json`, `settings.json`, personal desktop `.lnk` files, logs, backups, or unredacted diagnostic output. They may contain your folders, usernames, or saved commands.

For code changes, keep the changes focused and explain what you tested. The source checks can be run from the repository folder in Windows PowerShell 5.1 and PowerShell 7:

```powershell
powershell.exe -NoProfile -File .\tests\Test-Source.ps1
pwsh.exe -NoProfile -File .\tests\Test-Source.ps1
```

The GitHub Actions workflows run these source checks and compile the installer. Real shortcut behavior and Windows UAC prompts still need testing on an interactive Windows desktop.

ProjectShell uses the [Apache License, Version 2.0](LICENSE). Future integration with Nathan's Toolkit is planned, but this repository is for the standalone CLI application.
