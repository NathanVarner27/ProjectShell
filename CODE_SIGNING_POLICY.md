# ProjectShell — Code signing policy

This policy applies to ProjectShell's official Windows release artifacts and is linked from the [project home page](README.md) and [download/release page](https://github.com/NathanVarner27/ProjectShell/releases).

**Repository:** https://github.com/NathanVarner27/ProjectShell  
**License:** Apache License 2.0  
**Maintainer:** [NathanVarner27](https://github.com/NathanVarner27)

## Signing provider and current status

**Current status: unsigned; no approved public Authenticode signing provider.**

ProjectShell applied to the SignPath Foundation program. The Foundation **declined the application** because the project had not yet established enough independent public adoption and visibility (such as community contributions, external references and sustained public engagement). SignPath invited the project to reapply if those conditions change. This is not a code-security assessment and is not an endorsement of any ProjectShell build.

**Do not claim that SignPath Foundation signs, approves, sponsors or provides a certificate for ProjectShell.** The project's public GitHub release binaries remain unsigned unless a future independently verified signing arrangement is explicitly documented. Windows may display an unknown-publisher or SmartScreen warning.

Official build artifacts can include SHA-256 checksums and GitHub Actions build attestations; these help verify artifact integrity and provenance but **do not** make a Windows executable Authenticode-signed, remove SmartScreen warnings, or establish a Windows publisher identity.

Reapplication to SignPath or selection of another provider must be separately approved, and all signing claims must be based on verified signatures on the actual published file.

## Team roles and responsibilities

| Role | Current trusted member | Responsibilities |
| --- | --- | --- |
| **Author / committer** | [NathanVarner27](https://github.com/NathanVarner27) | Develops and maintains the source repository and build workflows; evaluates requested changes. |
| **Reviewer** | [NathanVarner27](https://github.com/NathanVarner27) | Reviews submissions from non-committers before merging, with extra scrutiny for executable behavior, installer changes, and build workflows. |
| **Release/signing approver** | [NathanVarner27](https://github.com/NathanVarner27) | Reviews release provenance; if a trusted signing service is later established, approves each signing request individually. |

All team members with source or future code-signing access should enable multi-factor authentication. If maintainers are added, this table must be updated with their responsibilities; changes from non-committers require review by an authorized project member. Signing approval is a **manual, release-by-release decision** and must not be granted automatically.

## Release and signing procedure

1. Review the exact tagged source revision, changelog, dependencies, license, and all changes to packaging or GitHub Actions workflows.
2. Run Windows PowerShell 5.1 and PowerShell 7 validation and the installer-build checks. Verify interactive installation and update behavior on Windows before a stable release.
3. Build Windows executables **only from the project's public source and build scripts** using an auditable, reproducible GitHub Actions workflow. Verify resulting artifact identities, source revision, and checksums. Never represent an untraceable or locally supplied binary as an official verified build.
4. Do **not** submit a signing request under SignPath Foundation's name without a future explicit acceptance. If an approved signing provider is later configured, submit only ProjectShell-owned binaries from the verified build pipeline, and require an authorized maintainer to approve each request.
5. Publish artifacts and release notes on [GitHub Releases](https://github.com/NathanVarner27/ProjectShell/releases), clearly labeling unsigned executables. If future signing is established, verify Authenticode status, publisher identity, and intended release hashes before labeling files signed.
6. If a build, review, signature, or provenance check fails, **do not publish it as signed**. Fix the issue and repeat verification.

GitHub Actions builds and checksum files alone do not confer Windows publisher trust. A ZIP can carry checksums and build attestations; its included executable must independently have a valid Authenticode signature to be described as Windows-signed.

## Privacy policy and user control

**This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it.**

ProjectShell is a local-first tool. Its project profiles, saved startup commands, workspace lookups, and desktop preferences remain on the user's computer under `%LOCALAPPDATA%\ProjectShell`. ProjectShell does not require an account, analytics, or telemetry to manage these settings. Creating shortcuts, opening local folders, installing into a selected directory, and running saved tools are local actions.

**User-directed actions are different:** A program, script, Git command, external service, or installer that a user chooses to run through ProjectShell may access a network and has its own privacy practices. ProjectShell does not endorse or override those external tools' policies. Looking at online source documentation or downloading a release through a browser likewise involves the user's chosen external services.

ProjectShell does not silently change system-wide PowerShell execution policy or Windows UAC settings. Guided installation describes the file-copy and shortcut actions; administrator execution is explicitly requested through Windows UAC. For instructions to remove installed files, shortcuts, and optional local user data, see [uninstallation](README.md#uninstall-projectshell-manual-user-controlled).

## Verify a downloaded executable's signing status

On Windows, open PowerShell in the downloaded/extracted release folder and run:

```powershell
Get-AuthenticodeSignature -FilePath ".\Install-ProjectShell.exe" |
    Format-List Status, StatusMessage, SignerCertificate
```

An unsigned ProjectShell executable is expected to show a status such as `NotSigned`. If a future release is signed, a result of `Status : Valid` must be accompanied by an appropriate signer certificate; verify the specific provider at that time. A valid signature does not independently establish which release and source revision the file belongs to.

**Do not rely on a filename, release description, SmartScreen prompt, or this policy alone as proof of signing.** Verify the individual EXE. ZIP packages are not themselves Authenticode-signed merely because they contain a signed EXE.

## Security concerns and policy violations

Please follow [SECURITY.md](SECURITY.md) and avoid posting secrets or private local paths in public issues. If a file falsely claims a trusted publisher signature, preserve the evidence and report it through the repository's security contact and the relevant certificate provider's abuse channel.