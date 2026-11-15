# Release checklist (owner-controlled)

## Completed for source preparation

- [x] Application `.ps1` source included.
- [x] Private saved profiles, desktop links, installation logs, and local shortcuts excluded.
- [x] Installer supports a configurable installation location; retains `D:\DevTools\ProjectShell` as the preferred path when available.
- [x] Documentation, `.gitignore`, changelog, and GitHub Actions syntax checks added.
- [x] No GitHub push performed by this preparation package. Local remote setup and any publication remain user-controlled.

## Required installer EXE tests before v1

- [x] Native Windows x64 EXE compiled, structurally verified, and embedded `asInvoker` manifest checked.
- [x] EXE source and reproducible build workflow included.
- [ ] Double-click EXE on Windows and confirm numbered destination/shortcut prompts appear.
- [ ] Confirm EXE produces **no UAC prompt** when opened from standard Explorer (asInvoker).
- [ ] Confirm companion PowerShell script is required and missing-file error is intelligible.
- [ ] Confirm installer copies `Install-ProjectShell.exe` to the permanent installation folder.
- [ ] Confirm bundled executable launches and remains open for error review on Windows.

## Must verify on Windows before a public stable release

- [ ] Installer runs from both a D: computer and a PC without D:.
- [ ] Both manager `.lnk` files exist in the installation folder.
- [ ] Normal manager opens without a UAC prompt and shows non-elevated status.
- [ ] Admin manager asks for UAC and shows elevated status after approval.
- [ ] Installer's optional desktop links appear on the actual Windows desktop.
- [ ] **Admin: No** project shortcut runs non-elevated (UGA/COA or disposable test folder).
- [ ] **Admin: Yes** project shortcut asks for UAC and runs elevated.
- [ ] Startup mode Folder, local Script, and Command each behave as intended.
- [ ] Browse updates the starting folder; `pshome` returns to Windows home; `psrestart` reruns a test task.
- [ ] Reinstallation preserves existing `%LOCALAPPDATA%\ProjectShell\profiles.json`.
- [ ] Source validation passes on the GitHub Windows runner.

## Publication decisions (not decided by the assistant)

- [ ] Choose a repository name, owner, and visibility (public/private).
- [ ] If publishing as open source, select and add a `LICENSE` file.
- [ ] Review every file in `git status` / `git diff --cached` for personal information.
- [ ] Perform the first commit using your Git identity and manually push when ready.

**Do not publish your local AppData folder or the old project-shortcut ZIP archives.**
