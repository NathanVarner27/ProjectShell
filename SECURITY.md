# Security notes

Project Shell creates Windows `.lnk` files and can run **user-selected PowerShell commands or scripts**. Treat those saved startup actions as executable code. Only save commands you trust.

- **Admin: No:** starts through Windows PowerShell 5.1 in standard mode; the application blocks automatic startup tasks if the process is unexpectedly elevated. This cannot change privileges on an already elevated parent process.
- **Admin: Yes:** deliberately requests Windows UAC. Never approve elevation for an unfamiliar script or executable.
- **Installer:** overwrites application scripts and rebuilds its own shortcuts in the selected installation directory. It preserves profiles in AppData.
- **Privacy:** Project Shell is local. Profiles can contain personal paths or commands; do not include those files in bug reports or public commits. Redact usernames and sensitive paths from diagnostic output before sharing.
- **Execution policy:** The app uses process-local `-ExecutionPolicy Bypass` when launching `.ps1` files. This is not a security boundary. It does not modify organization policies or Windows UAC settings.

For a security issue, avoid posting secrets in a public GitHub issue. Contact the repository owner privately using a contact method they publish when the repository is created.
