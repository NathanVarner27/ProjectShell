# Security

ProjectShell creates Windows shortcuts and can run PowerShell commands or scripts that you choose for your projects. Saved startup commands are still executable code, so only use commands and files you trust.

## Launch permissions

- **Admin: No** uses standard Windows PowerShell 5.1 for normal project sessions. If a session unexpectedly starts elevated, ProjectShell is designed to skip its automatic startup task. A shortcut cannot remove administrator privileges from a process that is already elevated.
- **Admin: Yes** requests Windows administrator access through UAC. Only approve that request when the task needs it and you trust the commands being run.
- The guided installer uses a standard-user launch. The installer can update application scripts and rebuild its own shortcuts in the selected folder, while keeping saved profiles in AppData.

## Local data and execution policy

ProjectShell works with local project settings. Profiles may contain personal folder names and user-defined commands. Do not upload profiles, settings, backups, desktop shortcuts, or unredacted diagnostics to GitHub.

ProjectShell uses process-local `-ExecutionPolicy Bypass` to run its PowerShell scripts. This does not change your computer's system-wide execution policy or disable Windows UAC. It also does not make an untrusted script safe.

The GitHub-built Windows launcher is currently unsigned and may trigger a SmartScreen warning. ProjectShell has selected SignPath Foundation for future code signing, pending application approval and verified build integration. **Do not represent an unsigned release as signed.** See [Code signing policy](CODE_SIGNING_POLICY.md). Check that you obtained an installer from the official GitHub Releases page and review its scripts before running them.

ProjectShell itself does not transmit project settings over the network. User-configured applications or commands launched through ProjectShell may independently make network connections; review those tools separately. For uninstall instructions and optional local-data deletion, see [README — Uninstall ProjectShell](README.md#uninstall-projectshell-manual-user-controlled).

## Reporting a security issue

If you find a security issue, **do not include passwords, tokens, private paths, or personal files in a public GitHub Issue**. Use a private reporting option if one is available on the repository. If no private contact method is listed, open a public issue with only a general description and ask for a safe way to share the details.
