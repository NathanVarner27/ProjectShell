# Manual GitHub publication steps

The ZIP contains **repository files only**, not an existing `.git` directory. No remote has been added and nothing has been pushed.

1. Extract the repository ZIP to a **separate working/source folder** (for example, `D:\DevTools\ProjectShell-Source`). Do not mix your Git repository with installed `.lnk` files and AppData profiles.
2. Review [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) and decide whether the repository should be private or public. Add a license if you intend it to be open source.
3. Run the following commands in the extracted source directory:

```powershell
git init -b main
git add .
git status --short
git diff --cached --stat
git commit -m "Initial Project Shell source"
```

4. On GitHub, create an **empty repository**: do **not** check the boxes for a generated README, `.gitignore`, or license because these files/decisions are already handled locally.
5. Copy your new repository's GitHub HTTPS or SSH URL. **The following two commands are the manual publication step; run them only when you're ready:**

```powershell
git remote add origin YOUR-REPOSITORY-URL
git push -u origin main
```

If an `origin` already exists, inspect `git remote -v` rather than adding a duplicate. If a Git identity is not configured, Git will ask you to set `user.name` and `user.email` before committing.

GitHub's official guide: https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github
