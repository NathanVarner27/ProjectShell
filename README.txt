PROJECT SHELL — STANDARD AND ADMINISTRATOR LAUNCHERS

Permanent installation:
  D:\DevTools\ProjectShell

Two launchers always in that folder:
  Project Shell Manager.lnk                  (NORMAL)
  Project Shell Manager (Administrator).lnk  (UAC)

WHY STANDARD LAUNCH MODE CHANGED
On some computers, pwsh.exe (PowerShell 7) is configured to run elevated.
A desktop shortcut cannot override that Windows executable setting. Previous
Project Shell releases pointed both launchers at pwsh.exe, so even the normal
shortcut could request elevation.

The default NORMAL engine is now built-in Windows PowerShell 5.1, while the
ADMINISTRATOR launcher uses PowerShell 7 and explicitly requests UAC. If your
PowerShell 7 executable does not request elevation, you can opt into it for
normal shortcuts at installation. The choice applies to normal manager and
normal project shortcuts; administrator project shortcuts use PowerShell 7.

This fallback changes the shell engine for normal project sessions. If a
project requires PowerShell 7-only functionality, fix its executable's
Windows compatibility settings first, then switch normal engine to PS7.

INSTALL / UPDATE
1. Close open Project Shell windows.
2. Extract the ZIP into D:\DevTools\ProjectShell.
3. Run the installer (after reviewing/trusting its scripts):

   pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\DevTools\ProjectShell\Install-ProjectShell.ps1"

4. Normal engine: select 1 (Windows PowerShell 5.1).
5. Desktop placement: select 1 (normal desktop shortcut).
6. Select the Windows registered desktop when asked.
7. Close the installer shell. Open Project Shell Manager from the
   desktop directly, or double-click the NORMAL .lnk in its install folder.

Your UGA and COA project settings remain in:
  %LOCALAPPDATA%\ProjectShell\profiles.json

DIAGNOSIS
If the normal launcher still opens elevated or asks for UAC, run:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\DevTools\ProjectShell\Diagnose-Launch.ps1"

It reports shortcut targets, RunAs flags, PowerShell executable compatibility
settings, and the current session's privilege level without changing anything.

SECURITY
The normal launch path does not request elevation. The admin launcher requests
Windows UAC explicitly. This application does not modify Registry compatibility
settings or override system-enforced elevation. Execution-policy Bypass above
applies to that process only. Only run trusted scripts.

PowerShell shortcut and UAC behavior must be tested on your Windows computer.

STANDARD AND ADMIN LAUNCH POLICY (SHORTCUT REPAIR)
- Install asks which manager launcher(s) to copy to Desktop. Both always exist in D:\DevTools\ProjectShell.
- Both manager and project shortcuts marked Admin: No use Windows PowerShell 5.1, the known-working normal launcher.
- Admin: Yes project shortcuts start with the safe shell, then explicitly request UAC and run PowerShell 7 if available.
- Old settings.json NormalEngine=PowerShell7 is repaired automatically on install.
- The installer rebuilds existing .lnk files; it never changes each project's saved Admin choice.
- Manager menu 12 audits targets, shortcut flags, and saved Admin expectations.
- If a project marked Admin: No is somehow elevated by Windows, startup tasks are blocked rather than executed elevated.
