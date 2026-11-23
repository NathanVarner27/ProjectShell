# ProjectShell — Code signing policy

This policy applies to ProjectShell's official Windows release artifacts and is linked from the [project home page](README.md) and [download/release page](https://github.com/NathanVarner27/ProjectShell/releases).

**Repository:** https://github.com/NathanVarner27/ProjectShell  
**License:** Apache License 2.0  
**Maintainer:** [NathanVarner27](https://github.com/NathanVarner27)

## Signing provider and current status

**Selected provider (pending approval):** SignPath Foundation, using SignPath.io. The required acknowledgement for qualifying signed releases is:

> Free code signing provided by SignPath.io, certificate by SignPath Foundation

**Important status:** ProjectShell has selected SignPath Foundation as its code-signing provider, but SignPath Foundation acceptance, signing configuration, and issuance of signed release artifacts have **not yet been verified**. Until those steps are completed, repository-built Windows executables must be described as **unsigned**. This policy alone does **not** sign any files, certify any releases, or imply Foundation approval.

When an official binary is actually signed using a SignPath Foundation certificate, the Windows certificate publisher will be **SignPath Foundation**, while ProjectShell remains developed and maintained by **NathanVarner27**. Only releases whose signatures have been checked may be labeled "signed."

## Team roles and responsibilities

| Role | Current trusted member | Responsibilities |
| --- | --- | --- |
| **Author / committer** | [NathanVarner27](https://github.com/NathanVarner27) | Develops and maintains the source repository and build workflows; evaluates requested changes. |
| **Reviewer** | [NathanVarner27](https://github.com/NathanVarner27) | Reviews submissions from non-committers before merging, with extra scrutiny for executable behavior, installer changes, and build workflows. |
| **Code-signing approver** | [NathanVarner27](https://github.com/NathanVarner27) | Reviews the exact release and build provenance and explicitly approves **each** signing request. |

All team members with source or SignPath access must enable multi-factor authentication. If maintainers are added, this table must be updated with their responsibilities; changes from non-committers require review by an authorized project member. Signing approval is a **manual, release-by-release decision** and must not be granted automatically.

## Release and signing procedure

1. Review the exact tagged source revision, changelog, dependencies, license, and all changes to packaging or GitHub Actions workflows.
2. Run Windows PowerShell 5.1 and PowerShell 7 validation and the installer-build checks. Verify interactive installation and update behavior on Windows before a stable release.
3. Build Windows executables **only from the project's public source and build scripts** using an auditable, reproducible GitHub Actions workflow. Verify the resulting artifact identities, source revision, and checksums. A locally supplied or untraceable executable must not be submitted as an official SignPath build.
4. When the project is approved and integrated with SignPath.io, submit only ProjectShell-owned binaries from the verified build pipeline. The trusted **approver** must manually approve every signing request; do not sign unrelated or third-party binaries.
5. After signing, verify Authenticode signatures and the intended release file hashes, then publish artifacts and release notes on [GitHub Releases](https://github.com/NathanVarner27/ProjectShell/releases). Clearly identify any files that remain unsigned.
6. If a build, review, signature, or provenance check fails, **do not publish it as signed**. Fix the issue and repeat verification.

GitHub Actions builds and checksum files alone do not confer Windows publisher trust. A ZIP can carry checksums and build attestations; its included executable must independently have a valid Authenticode signature to be described as Windows-signed.

## Privacy policy and user control

**This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it.**

ProjectShell is a local-first tool. Its project profiles, saved startup commands, workspace lookups, and desktop preferences remain on the user's computer under `%LOCALAPPDATA%\ProjectShell`. ProjectShell does not require an account, analytics, or telemetry to manage these settings. Creating shortcuts, opening local folders, installing into a selected directory, and running saved tools are local actions.

**User-directed actions are different:** A program, script, Git command, external service, or installer that a user chooses to run through ProjectShell may access a network and has its own privacy practices. ProjectShell does not endorse or override those external tools' policies. Looking at online source documentation or downloading a release through a browser likewise involves the user's chosen external services.

ProjectShell does not silently change system-wide PowerShell execution policy or Windows UAC settings. Guided installation describes the file-copy and shortcut actions; administrator execution is explicitly requested through Windows UAC. For instructions to remove installed files, shortcuts, and optional local user data, see [uninstallation](README.md#uninstall-projectshell-manual-user-controlled).

## Verify an official signed executable

On Windows, open PowerShell in the downloaded/extracted release folder and run:

```powershell
Get-AuthenticodeSignature -FilePath ".\Install-ProjectShell.exe" |
    Format-List Status, StatusMessage, SignerCertificate
```

A qualifying signed executable should show `Status : Valid` and a signer certificate issued to **SignPath Foundation**. If the file is unsigned, `Status` will not be `Valid` (for example, `NotSigned`). A valid signature is not a substitute for reviewing which official release and source revision the file belongs to.

**Do not rely on a filename, release description, SmartScreen prompt, or this policy alone as proof of signing.** Verify the individual EXE. ZIP packages are not themselves Authenticode-signed merely because they contain a signed EXE.

## Security concerns and policy violations

Please follow [SECURITY.md](SECURITY.md) and avoid posting secrets or private local paths in public issues. If an artifact claiming a SignPath Foundation signature may violate SignPath's rules, report it using the channels described in the [SignPath Foundation conditions](https://signpath.org/terms.html).

The project commits to the [SignPath Foundation conditions for open-source projects](https://signpath.org/terms.html) if the application is accepted; publishing this policy does not assert that acceptance has occurred.