# Preparing the v1 source commit manually

1. Back up your current source and review this candidate package. Do not overwrite a running Project Shell installation or uncommitted edits without checking them first.
2. Copy the source files from this package into your repository root, including `.github`, `native`, `scripts`, `tests`, README, and development documents. The compiled EXE can be used locally; `.gitignore` intentionally keeps generated executables out of source commits.
3. Check the actual diff before staging. Run the appropriate PowerShell validation tests and Windows installation/UAC checks before a stable release.

```powershell
Set-Location "D:\DevTools\ProjectShell" # Replace with your local repo folder

git status --short
git diff --check
git add -- .gitignore .gitattributes .github native scripts tests ProjectShell.ps1 Install-ProjectShell.ps1 Diagnose-Launch.ps1 README.md README.txt PROJECT-DESCRIPTION.md DEVELOPMENT-PLAN.md CHANGELOG.md CONTRIBUTING.md SECURITY.md RELEASE-CHECKLIST.md GITHUB-V1-PREP.md MANUAL-GITHUB-PUSH.md
git diff --cached --check
git diff --cached --stat
git diff --cached
```

4. From the extracted installer ZIP, double-click `Install-ProjectShell.exe` in Windows Explorer. It opens a standard-user PowerShell console, offers numbered setup options, and remains open for review. Test normal and administrator launchers separately.
5. In Windows PowerShell 5.1 and PowerShell 7, run `./tests/Test-Source.ps1`. Check the GitHub Actions workflows if a remote repository is available.
6. Confirm the planned license and add the full official `LICENSE` file before describing the code as open source.
7. When you are satisfied, create a local v1 release-candidate commit. Tagging and pushing remain explicit manual decisions.

Release binaries belong in GitHub Release ZIPs; the checked-in source is reproducible using `scripts/build-native-installer.sh`.
