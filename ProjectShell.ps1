# ProjectShell - local desktop shortcuts for named PowerShell projects.
# Windows PowerShell 5.1 or PowerShell 7; PowerShell 7 is preferred.
[CmdletBinding()]
param(
    [string]$LaunchId = '',
    [switch]$SessionMenu,
    [switch]$RestartOnly,
    [switch]$RefreshLinks,
    [switch]$MatchConsole,
    [switch]$ElevateManager
)

$ErrorActionPreference = 'Stop'
$script:AppRoot = Join-Path $env:LOCALAPPDATA 'ProjectShell'
$script:StorePath = Join-Path $script:AppRoot 'profiles.json'
$script:ProgramPath = $PSCommandPath
$script:Desktop = [Environment]::GetFolderPath('DesktopDirectory')
$script:DesktopSettings = Join-Path $script:AppRoot 'settings.json'
if (Test-Path -LiteralPath $script:DesktopSettings -PathType Leaf) {
    try {
        $desktopChoice = Get-Content -LiteralPath $script:DesktopSettings -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace([string]$desktopChoice.DesktopPath) -and
            (Test-Path -LiteralPath ([string]$desktopChoice.DesktopPath) -PathType Container)) {
            # All project links follow the desktop selected during installation.
            $script:Desktop = [string]$desktopChoice.DesktopPath
        }
    }
    catch { Write-Warning ('Desktop path setting could not be read: ' + $_.Exception.Message) }
}


function Ensure-Store {
    if (-not (Test-Path -LiteralPath $script:AppRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $script:AppRoot -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $script:StorePath -PathType Leaf)) {
        '{"Version":1,"Profiles":[]}' | Set-Content -LiteralPath $script:StorePath -Encoding UTF8
    }
}

function Read-Store {
    Ensure-Store
    $raw = Get-Content -LiteralPath $script:StorePath -Raw -Encoding UTF8
    $result = $raw | ConvertFrom-Json
    if ($null -eq $result -or $null -eq $result.Profiles) {
        throw "Invalid profile store: $script:StorePath"
    }
    return @($result.Profiles)
}

function Save-Store([object[]]$Profiles) {
    Ensure-Store
    $payload = [pscustomobject]@{ Version = 1; Profiles = @($Profiles) }
    $tmp = Join-Path $script:AppRoot ('profiles-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tmp -Encoding UTF8
        [IO.File]::Copy($tmp, $script:StorePath, $true)
    }
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } }
}

function Get-PowerShellExe {
    $cmd = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $fallback = Join-Path $PSHOME 'powershell.exe'
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    $cmd = Get-Command powershell.exe -ErrorAction Stop
    return $cmd.Source
}

function Get-StandardPowerShellExe {
    # The normal launcher that works on this machine is Windows PowerShell 5.1.
    # Always use it for standard project shortcuts, just like the normal manager.
    # An old settings.json NormalEngine=PowerShell7 must not silently override
    # a user's explicit Admin: No selection.
    $systemPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $systemPs -PathType Leaf)) {
        throw ('Windows PowerShell was not found: ' + $systemPs)
    }
    return $systemPs
}

function Get-TerminalExe {
    $cmd = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Path -LiteralPath $cmd.Source)) { return $cmd.Source }
    return $null
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Quote-Arg([string]$Value) {
    # All quotes from Windows paths/names are escaped for CreateProcess command lines.
    return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Get-SafeName([string]$Name) {
    $safe = ($Name -replace '[\\/:*?"<>|\x00-\x1F]', '-') -replace '\s+', ' '
    $safe = $safe.Trim([char[]]@(' ', '.'))
    if (-not $safe) { $safe = 'Project' }
    if ($safe.Length -gt 85) { $safe = $safe.Substring(0,85).Trim([char[]]@(' ', '.')) }
    return $safe
}

function Find-FreeLinkFile([string]$Name, [string]$ExcludeFile = '') {
    $base = 'ProjectShell - ' + (Get-SafeName $Name)
    $n = 1
    do {
        $suffix = if ($n -eq 1) { '' } else { " ($n)" }
        $file = "$base$suffix.lnk"
        $full = Join-Path $script:Desktop $file
        $okay = (-not (Test-Path -LiteralPath $full)) -or ($file -eq $ExcludeFile)
        $n++
    } until ($okay)
    return $file
}

function Profile-LinkPath($entry) {
    return (Join-Path $script:Desktop ([string]$entry.ShortcutFile))
}

function Get-LinkRunAsFlag([string]$Path) {
    # Per Microsoft's Shell Link specification, LinkFlags is a DWORD at offset 0x14.
    # SLDF_RUNAS_USER (0x2000) can force alternate/elevated execution.
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 0x4C -or [BitConverter]::ToUInt32($bytes,0) -ne 0x4C) {
        throw ('Invalid Windows shortcut header: ' + $Path)
    }
    return (([BitConverter]::ToUInt32($bytes,0x14) -band 0x2000) -ne 0)
}

function Show-CompatibilityElevation([string]$FilePath) {
    $keys = @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    )
    foreach ($key in $keys) {
        try {
            $values = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            $item = $values.PSObject.Properties[$FilePath]
            if ($null -ne $item -and -not [string]::IsNullOrWhiteSpace([string]$item.Value)) {
                Write-Host ('Windows compatibility setting: ' + $key + ' = ' + $item.Value) -ForegroundColor Yellow
                if ([string]$item.Value -match 'RUNASADMIN') {
                    Write-Host 'The target is marked RUNASADMIN in Windows compatibility settings.' -ForegroundColor Yellow
                }
            }
        }
        catch { } # Registry keys may not exist or may be inaccessible.
    }
}

function Write-ProfileLink($entry) {
    if (-not (Test-Path -LiteralPath $entry.StartDirectory -PathType Container)) {
        throw "Starting folder does not exist: $($entry.StartDirectory)"
    }
    # Both shortcut types first launch through the safe, non-elevating executable.
    # For Admin: Yes, ProjectShell.ps1 intentionally requests UAC in its
    # -LaunchId handler. This avoids incidental elevation from pwsh.exe.
    $ps = Get-StandardPowerShellExe
    $wt = Get-TerminalExe
    $linkPath = Profile-LinkPath $entry
    # Never edit a preexisting .lnk in place: WScript.Shell cannot explicitly clear
    # all advanced shortcut settings. Build a clean .lnk and atomically replace it.
    $temporaryLink = Join-Path $script:Desktop ('.ProjectShell-' + [guid]::NewGuid().ToString('N') + '.lnk')
    $shell = $null
    $link = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($temporaryLink)
        # Standard profiles keep an interactive console. Admin profiles use a
        # short-lived non-elevated bootstrap which requests UAC, then closes.
        # The elevated project window itself uses -NoExit in the launch handler.
        $noExit = if ([bool]$entry.Admin) { '' } else { '-NoExit ' }
        $launchArgs = '-NoLogo ' + $noExit + '-ExecutionPolicy Bypass -File ' + (Quote-Arg $script:ProgramPath) + ' -LaunchId ' + (Quote-Arg $entry.Id)
        if ([string]$entry.Terminal -eq 'WindowsTerminal' -and -not [bool]$entry.Admin -and $wt) {
            $link.TargetPath = $wt
            $link.Arguments = '-w new nt --title ' + (Quote-Arg $entry.Name) + ' --suppressApplicationTitle -d ' + (Quote-Arg $entry.StartDirectory) + ' ' + (Quote-Arg $ps) + ' ' + $launchArgs
        }
        else {
            $link.TargetPath = $ps
            $link.Arguments = $launchArgs
        }
        $link.WorkingDirectory = [string]$entry.StartDirectory
        $link.Description = 'ProjectShell: ' + [string]$entry.Name
        $link.IconLocation = $ps + ',0'
        $link.WindowStyle = 1
        $link.Save()
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link)
        $link = $null
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
        $shell = $null

        if (Get-LinkRunAsFlag $temporaryLink) {
            throw 'New desktop link unexpectedly requests elevation; no shortcut replaced.'
        }
        if (Test-Path -LiteralPath $linkPath -PathType Leaf) {
            # Keep original .lnk in the app data folder before replacing it.
            Ensure-Store
            $backupPath = Join-Path $script:AppRoot ('link-backup-' + [guid]::NewGuid().ToString('N') + '.lnk')
            # File.Replace creates the backup at this explicit path.
            [IO.File]::Replace($temporaryLink, $linkPath, $backupPath)
        }
        else { [IO.File]::Move($temporaryLink, $linkPath) }
        if (Get-LinkRunAsFlag $linkPath) {
            throw 'Unexpected RunAs shortcut flag persisted. Inspect shortcut Properties > Advanced.'
        }
        # Verify the ACTUAL .lnk destination, not merely the saved Admin field.
        $verifyShell = New-Object -ComObject WScript.Shell
        $verifyLink = $null
        try {
            $verifyLink = $verifyShell.CreateShortcut($linkPath)
            $expectedTarget = if ([string]$entry.Terminal -eq 'WindowsTerminal' -and -not [bool]$entry.Admin -and $wt) { $wt } else { $ps }
            if (-not [string]::Equals([string]$verifyLink.TargetPath, [string]$expectedTarget, [StringComparison]::OrdinalIgnoreCase)) {
                throw ('Shortcut executable mismatch: ' + $linkPath)
            }
            if ([string]$verifyLink.Arguments -notmatch '(?i)(?:^|\s)-LaunchId(?:\s|$)') {
                throw ('Shortcut has no project launch ID: ' + $linkPath)
            }
            if ([string]$verifyLink.Arguments -match '(?i)(?:^|\s)-ElevateManager(?:\s|$)') {
                throw ('Project shortcut has unexpected manager elevation argument: ' + $linkPath)
            }
        }
        finally {
            if ($null -ne $verifyLink) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($verifyLink) }
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($verifyShell)
        }
    }
    finally {
        if ($null -ne $link) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
        if ($null -ne $shell) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
        if (Test-Path -LiteralPath $temporaryLink -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryLink -Force -ErrorAction SilentlyContinue
        }
    }
}

function Read-Required([string]$Label, [string]$Default = '') {
    while ($true) {
        if ($Default) { $answer = Read-Host "$Label [$Default]" } else { $answer = Read-Host $Label }
        $answer = $answer.Trim()
        if ($answer) { return $answer }
        if ($Default) { return $Default }
        Write-Host 'This field is required.' -ForegroundColor Yellow
    }
}

function Browse-StartingFolder {
    # Use Windows' built-in folder selection dialog, while keeping the app CLI-only.
    # 0x51: return only file-system directories, use modern dialog, show edit box.
    try {
        $shell = New-Object -ComObject Shell.Application
        $chosen = $shell.BrowseForFolder(0, 'Select the project starting folder', 0x51, 0)
        if ($null -eq $chosen) { return $null }

        $path = [string]$chosen.Self.Path
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Container)) {
            Write-Host 'Choose an existing file-system folder, not a virtual location.' -ForegroundColor Yellow
            return $null
        }
        return (Resolve-Path -LiteralPath $path).ProviderPath
    }
    catch {
        Write-Host ('Folder picker unavailable: ' + $_.Exception.Message) -ForegroundColor Yellow
        Write-Host 'You can type or paste the full path using option 2.' -ForegroundColor Yellow
        return $null
    }
}

function Read-Folder([string]$Default = '') {
    while ($true) {
        Write-Host ''
        Write-Host 'SET STARTING FOLDER' -ForegroundColor Cyan
        if ($Default) { Write-Host ('Current folder: ' + $Default) }
        Write-Host '  1. Browse and select folder [recommended]'
        Write-Host '  2. Type or paste existing folder path'
        if ($Default) { Write-Host '  3. Keep current folder' }
        Write-Host '  0. Cancel (leave unchanged)'
        $choice = (Read-Host 'Number').Trim()
        switch ($choice) {
            '1' {
                $folder = Browse-StartingFolder
                if ($folder) {
                    Write-Host ('Starting folder set to: ' + $folder) -ForegroundColor Green
                    return $folder
                }
                Write-Host 'No folder selected. Starting folder was not changed.' -ForegroundColor Yellow
            }
            '2' {
                $value = Read-Required 'Starting folder (existing full path)' $Default
                $value = [Environment]::ExpandEnvironmentVariables($value.Trim('"'))
                if (Test-Path -LiteralPath $value -PathType Container) {
                    $folder = (Resolve-Path -LiteralPath $value).ProviderPath
                    Write-Host ('Starting folder set to: ' + $folder) -ForegroundColor Green
                    return $folder
                }
                Write-Host 'That folder was not found. Nothing was changed.' -ForegroundColor Yellow
            }
            '3' {
                if ($Default) { return $Default }
                Write-Host 'No current folder to keep.' -ForegroundColor Yellow
            }
            '0' { return $null }
            default { Write-Host 'Choose a listed number.' -ForegroundColor Yellow }
        }
    }
}

function Read-YesNo([string]$Question, [bool]$Default = $false) {
    $hint = if ($Default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        $reply = (Read-Host "$Question ($hint)").Trim().ToLowerInvariant()
        if (-not $reply) { return $Default }
        if ($reply -in @('y','yes')) { return $true }
        if ($reply -in @('n','no')) { return $false }
        Write-Host 'Enter Y or N.' -ForegroundColor Yellow
    }
}

function Read-Startup($entry) {
    Write-Host ''
    Write-Host 'What should happen when this shortcut opens?'
    Write-Host '  1. Open the folder and show a PowerShell prompt [recommended]'
    Write-Host '  2. Run a local .ps1 file (can rerun later)'
    Write-Host '  3. Run a PowerShell command (can rerun later)'
    while ($true) {
        $pick = (Read-Host 'Number').Trim()
        switch ($pick) {
            '1' { $entry.StartupMode = 'Folder'; $entry.StartupValue = ''; return }
            '2' {
                while ($true) {
                    $value = Read-Required 'Full .ps1 file path'
                    $value = [Environment]::ExpandEnvironmentVariables($value.Trim('"'))
                    if ((Test-Path -LiteralPath $value -PathType Leaf) -and [IO.Path]::GetExtension($value) -ieq '.ps1') {
                        $entry.StartupMode = 'Script'
                        $entry.StartupValue = (Resolve-Path -LiteralPath $value).ProviderPath
                        return
                    }
                    Write-Host 'Choose an existing .ps1 file.' -ForegroundColor Yellow
                }
            }
            '3' {
                Write-Host 'This command executes on every launch and when you choose Restart.' -ForegroundColor Yellow
                $value = Read-Required 'PowerShell command to run'
                $entry.StartupMode = 'Command'
                $entry.StartupValue = $value
                return
            }
            default { Write-Host 'Choose 1, 2, or 3.' -ForegroundColor Yellow }
        }
    }
}

function Read-Admin([bool]$Default = $false) {
    Write-Host 'Administrator suggestions:' -ForegroundColor DarkCyan
    Write-Host '  Normal: code, test runs, logs, reading files, and most development.'
    Write-Host '  Admin: installing services, protected folders, system configuration.'
    Write-Host '  Admin shortcuts ask for Windows UAC approval when launched.'
    return (Read-YesNo 'Run this shortcut as administrator?' $Default)
}

function Read-Terminal([string]$Default = 'Console') {
    $wt = Get-TerminalExe
    Write-Host ''
    Write-Host 'TERMINAL WINDOW STYLE' -ForegroundColor Cyan
    Write-Host '  1. Classic PowerShell console [recommended; matches Project Shell Manager]'
    if ($wt) {
        Write-Host '  2. Windows Terminal (tab-style window; may need extra Windows configuration)'
    }
    else {
        Write-Host '  Windows Terminal was not found. Classic console will be used.' -ForegroundColor Yellow
    }
    $defaultNumber = if ($wt -and $Default -eq 'WindowsTerminal') { '2' } else { '1' }
    while ($true) {
        $pick = Read-Required 'Number' $defaultNumber
        if ($pick -eq '1') { return 'Console' }
        if ($pick -eq '2' -and $wt) {
            Write-Host 'Each launch uses a separate Windows Terminal window with a fixed title.' -ForegroundColor DarkCyan
            Write-Host 'If Windows Terminal reports 0x800702e4, change this profile to classic console.' -ForegroundColor Yellow
            return 'WindowsTerminal'
        }
        Write-Host 'Choose a listed number.' -ForegroundColor Yellow
    }
}

function Write-ProfileSummary($entry) {
    Write-Host ''
    Write-Host ("Name:          " + $entry.Name)
    Write-Host ("Project group: " + $entry.Group)
    Write-Host ("Start folder:  " + $entry.StartDirectory)
    Write-Host ("On launch:     " + $entry.StartupMode)
    if ($entry.StartupValue) { Write-Host ("Task:          " + $entry.StartupValue) }
    Write-Host ("Administrator: " + $(if ($entry.Admin) { 'Yes (UAC prompt)' } else { 'No' }))
    $display = if ($entry.Admin) { 'Classic console (for elevation)' } else { $entry.Terminal }
    Write-Host ("Terminal:      " + $display)
    Write-Host ("Desktop link:  " + $entry.ShortcutFile)
    Write-Host ''
}

function New-Profile([object[]]$Profiles, $CopyFrom = $null) {
    $copy = ($null -ne $CopyFrom)
    if ($copy) {
        Write-Host "Creating an alternate for: $($CopyFrom.Name)" -ForegroundColor Cyan
    }
    else { Write-Host 'CREATE A DESKTOP PROJECT SHORTCUT' -ForegroundColor Cyan }

    $groupDefault = if ($copy) { [string]$CopyFrom.Group } else { '' }
    $nameDefault = if ($copy) { "$($CopyFrom.Name) - Alt" } else { '' }
    $group = Read-Required 'Project group (e.g., UGA or COA)' $groupDefault
    $name = Read-Required 'Shortcut name AND terminal header' $nameDefault
    if (@($Profiles | Where-Object { $_.Name -ieq $name }).Count -gt 0) {
        Write-Host 'This title already exists. Give each shortcut a unique title.' -ForegroundColor Yellow
        return $Profiles
    }
    $dirDefault = if ($copy) { [string]$CopyFrom.StartDirectory } else { '' }
    $dir = Read-Folder $dirDefault
    if (-not $dir) {
        Write-Host 'Shortcut creation cancelled. No changes saved.' -ForegroundColor Yellow
        return ,$Profiles
    }
    $entry = [pscustomobject]@{
        Id = [guid]::NewGuid().ToString('D')
        Group = $group
        Name = $name
        StartDirectory = $dir
        StartupMode = 'Folder'
        StartupValue = ''
        Admin = $false
        Terminal = 'Console'
        ShortcutFile = ''
    }
    Read-Startup $entry
    $entry.Admin = Read-Admin $(if ($copy) { [bool]$CopyFrom.Admin } else { $false })
    if ($entry.Admin) {
        $entry.Terminal = 'Console'
        Write-Host 'Admin shortcut: classic PowerShell window will be used for reliable UAC elevation.' -ForegroundColor DarkCyan
    }
    else {
        $terminalDefault = if ($copy) { [string]$CopyFrom.Terminal } else { 'Console' }
        $entry.Terminal = Read-Terminal $terminalDefault
    }
    $entry.ShortcutFile = Find-FreeLinkFile $name
    Write-ProfileSummary $entry
    if (-not (Read-YesNo 'Create shortcut with these settings?' $true)) { return $Profiles }
    $new = @($Profiles) + @($entry)
    Save-Store $new
    Write-ProfileLink $entry
    Write-Host ("CREATED: " + (Profile-LinkPath $entry)) -ForegroundColor Green
    return ,$new
}

function Select-Profile([object[]]$Profiles, [string]$Question = 'Number', [switch]$GroupOnly, [string]$Group = '') {
    $visible = @($Profiles | Where-Object { -not $GroupOnly -or $_.Group -ieq $Group } | Sort-Object Name)
    if ($visible.Count -eq 0) { Write-Host 'No matching profiles.' -ForegroundColor Yellow; return $null }
    Write-Host ''
    for ($n = 0; $n -lt $visible.Count; $n++) {
        $p = $visible[$n]
        $adminText = if ($p.Admin) { ' [ADMIN]' } else { '' }
        Write-Host ("  {0}. {1}{2} - {3}" -f ($n+1),$p.Name,$adminText,$p.StartDirectory)
    }
    Write-Host '  0. Cancel'
    while ($true) {
        $reply = (Read-Host $Question).Trim()
        if ($reply -eq '0') { return $null }
        $index = 0
        if ([int]::TryParse($reply,[ref]$index) -and $index -ge 1 -and $index -le $visible.Count) {
            return $visible[$index - 1]
        }
        Write-Host 'Enter one of the listed numbers.' -ForegroundColor Yellow
    }
}

function Start-Profile($entry) {
    if (-not [bool]$entry.Admin -and (Test-IsAdmin)) {
        Write-Host ''
        Write-Host 'The manager is running as Administrator, but this profile is NORMAL.' -ForegroundColor Yellow
        Write-Host 'For a standard session, close the elevated manager and double-click the' -ForegroundColor Yellow
        Write-Host 'desktop shortcut from a normal Windows Explorer desktop.' -ForegroundColor Yellow
        Write-Host 'Launch cancelled so a test task is not accidentally elevated.' -ForegroundColor Yellow
        return
    }
    $file = Profile-LinkPath $entry
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Write-ProfileLink $entry }
    Invoke-Item -LiteralPath $file
}

function Edit-Profile([object[]]$Profiles, $entry) {
    $oldLink = Profile-LinkPath $entry
    while ($true) {
        Write-ProfileSummary $entry
        Write-Host 'EDIT: 1 Name/title  2 Group  3 Folder  4 Startup action  5 Admin  6 Terminal  0 Save and back'
        $pick = (Read-Host 'Number').Trim()
        switch ($pick) {
            '1' {
                $name = Read-Required 'New name/title' $entry.Name
                if (@($Profiles | Where-Object { $_.Id -ne $entry.Id -and $_.Name -ieq $name }).Count -gt 0) {
                    Write-Host 'That title belongs to another profile.' -ForegroundColor Yellow
                }
                else { $entry.Name = $name }
            }
            '2' { $entry.Group = Read-Required 'Project group' $entry.Group }
            '3' {
                $newFolder = Read-Folder $entry.StartDirectory
                if ($newFolder) { $entry.StartDirectory = $newFolder }
            }
            '4' { Read-Startup $entry }
            '5' {
                $entry.Admin = Read-Admin ([bool]$entry.Admin)
                if ($entry.Admin) { $entry.Terminal = 'Console' }
            }
            '6' {
                if ([bool]$entry.Admin) {
                    Write-Host 'Admin shortcuts use classic console so Windows can request UAC elevation.' -ForegroundColor Yellow
                    $entry.Terminal = 'Console'
                }
                else { $entry.Terminal = Read-Terminal $entry.Terminal }
            }
            '0' {
                if ($oldLink -ne (Profile-LinkPath $entry) -and (Test-Path -LiteralPath $oldLink)) {
                    Remove-Item -LiteralPath $oldLink -Force
                }
                $newShortcutName = Find-FreeLinkFile $entry.Name $entry.ShortcutFile
                if ($newShortcutName -ne $entry.ShortcutFile) {
                    $oldLink = Profile-LinkPath $entry
                    $entry.ShortcutFile = $newShortcutName
                    if (Test-Path -LiteralPath $oldLink) { Remove-Item -LiteralPath $oldLink -Force }
                }
                Save-Store $Profiles
                Write-ProfileLink $entry
                Write-Host 'Updated shortcut and saved profile.' -ForegroundColor Green
                return
            }
            default { Write-Host 'Choose a listed number.' -ForegroundColor Yellow }
        }
    }
}

function Match-ManagerTerminalStyle([object[]]$Profiles) {
    if ($Profiles.Count -eq 0) {
        Write-Host 'No saved project shortcuts to update.' -ForegroundColor Yellow
        return
    }
    Write-Host ''
    Write-Host 'MATCH PROJECT WINDOWS TO THE MANAGER' -ForegroundColor Cyan
    Write-Host 'Switch every saved project shortcut to classic PowerShell console windows.'
    Write-Host 'This avoids the Windows Terminal launch path that produced 0x800702e4.'
    Write-Host 'Project titles, folders, commands, and administrator choices are preserved.'
    if (-not (Read-YesNo 'Change terminal styles and refresh all desktop shortcuts?' $false)) {
        Write-Host 'No changes made.'
        return
    }
    Ensure-Store
    $backup = Join-Path $script:AppRoot ('profiles-before-console-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    Copy-Item -LiteralPath $script:StorePath -Destination $backup -Force
    foreach ($entry in $Profiles) { $entry.Terminal = 'Console' }
    Save-Store $Profiles
    foreach ($entry in $Profiles) {
        Write-ProfileLink $entry
        Write-Host ('Updated: ' + $entry.Name) -ForegroundColor Green
    }
    Write-Host ('Profiles backup: ' + $backup) -ForegroundColor DarkCyan
    Write-Host 'Each project shortcut now opens in its own named console window.' -ForegroundColor Green
}

function Repair-SavedShortcuts([switch]$ConvertToConsole) {
    $profiles = @(Read-Store)
    if ($profiles.Count -eq 0) {
        Write-Host 'No existing project shortcuts require refreshing.' -ForegroundColor DarkCyan
        return
    }

    if ($ConvertToConsole) {
        $needsChange = @($profiles | Where-Object { [string]$_.Terminal -ne 'Console' })
        if ($needsChange.Count -gt 0) {
            $backup = Join-Path $script:AppRoot ('profiles-before-console-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
            Copy-Item -LiteralPath $script:StorePath -Destination $backup -Force
            foreach ($entry in $profiles) { $entry.Terminal = 'Console' }
            Save-Store $profiles
            Write-Host ('Profile backup: ' + $backup) -ForegroundColor Cyan
            Write-Host ('Switched ' + $needsChange.Count + ' shortcut profile(s) to classic PowerShell.') -ForegroundColor Green
        }
    }

    foreach ($entry in $profiles) {
        try {
            if (-not (Test-Path -LiteralPath $entry.StartDirectory -PathType Container)) {
                Write-Host ('WARNING: ' + $entry.Name + ' starting folder was not found: ' + $entry.StartDirectory) -ForegroundColor Yellow
                Write-Host '  Edit this shortcut in the manager (5 -> select shortcut -> 3 -> Browse).' -ForegroundColor Yellow
                continue
            }
            Write-ProfileLink $entry
            Write-Host ('Refreshed desktop shortcut: ' + $entry.Name + ' (' + $entry.Terminal + ')') -ForegroundColor Green
        }
        catch {
            Write-Host ('Could not refresh ' + $entry.Name + ': ' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
}

function Show-ShortcutDiagnostics($entry) {
    Write-Host ''
    Write-Host ('SHORTCUT DIAGNOSTICS | ' + $entry.Name) -ForegroundColor Cyan
    Write-Host ('Saved terminal:  ' + $entry.Terminal)
    Write-Host ('Admin requested by saved profile: ' + $entry.Admin)
    Write-Host ('Manager process ACTUALLY elevated: ' + $(if (Test-IsAdmin) { 'YES' } else { 'NO' }))
    Write-Host ('Starting folder: ' + $entry.StartDirectory)
    Write-Host ('Desktop link:    ' + (Profile-LinkPath $entry))
    if (Test-Path -LiteralPath $entry.StartDirectory -PathType Container) {
        Write-Host 'Starting folder exists: YES' -ForegroundColor Green
    }
    else {
        Write-Host 'Starting folder exists: NO. Edit this shortcut and browse for a valid folder.' -ForegroundColor Yellow
    }
    if ([string]$entry.StartupMode -eq 'Script' -and -not (Test-Path -LiteralPath $entry.StartupValue -PathType Leaf)) {
        Write-Host ('Startup .ps1 file is missing: ' + $entry.StartupValue) -ForegroundColor Yellow
    }
    $linkFile = Profile-LinkPath $entry
    if (-not (Test-Path -LiteralPath $linkFile -PathType Leaf)) {
        Write-Host 'Desktop shortcut missing. Use manager option 6 to restore.' -ForegroundColor Yellow
        return
    }
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($linkFile)
        Write-Host ('Actual link target: ' + $link.TargetPath)
        Write-Host ('Shortcut argument string: ' + $link.Arguments)
        $normalExpected = Get-StandardPowerShellExe
        $expectedEngine = [string]::Equals([string]$link.TargetPath, [string]$normalExpected, [StringComparison]::OrdinalIgnoreCase)
        if ([string]$entry.Terminal -eq 'WindowsTerminal' -and -not [bool]$entry.Admin) {
            Write-Host 'Windows Terminal was selected; its own settings can still require elevation.' -ForegroundColor Yellow
        }
        Write-Host ('Uses standard Windows PowerShell executable: ' + $(if ($expectedEngine) { 'YES' } else { 'NO / WINDOWS TERMINAL' })) -ForegroundColor $(if ($expectedEngine) { 'Green' } else { 'Yellow' })
        Write-Host ('Expected elevation behavior: ' + $(if ([bool]$entry.Admin) { 'UAC prompt from Project Shell after opening' } else { 'No UAC, task blocked if process somehow elevated' }))
        $linkRunAs = Get-LinkRunAsFlag $linkFile
        Write-Host ('Shortcut RunAs flag: ' + $(if ($linkRunAs) { 'SET (may elevate)' } else { 'CLEAR' }))
        if ($linkRunAs) { Write-Host 'Select manager option 6 to rebuild this shortcut from a clean .lnk.' -ForegroundColor Yellow }
        Show-CompatibilityElevation ([string]$link.TargetPath)
        Write-Host ('Normal engine target (configured): ' + (Get-StandardPowerShellExe))
        $actualIsWt = [IO.Path]::GetFileName([string]$link.TargetPath) -ieq 'wt.exe'
        $expectedWt = ([string]$entry.Terminal -eq 'WindowsTerminal') -and (-not [bool]$entry.Admin) -and [bool](Get-TerminalExe)
        if ($actualIsWt -ne $expectedWt) {
            Write-Host 'MISMATCH: actual shortcut uses a different terminal from its saved profile.' -ForegroundColor Yellow
            Write-Host 'Choose manager option 6 to refresh, or option 9 to match console styles.' -ForegroundColor Yellow
        }
        elseif ($actualIsWt) {
            Write-Host 'This shortcut launches through Windows Terminal (wt.exe).' -ForegroundColor Yellow
            Write-Host 'If it fails with error 0x800702e4, select manager option 9.' -ForegroundColor Yellow
        }
        else {
            Write-Host 'This shortcut targets PowerShell directly, matching the manager style.' -ForegroundColor Green
        }
    }
    catch { Write-Host ('Unable to read shortcut details: ' + $_.Exception.Message) -ForegroundColor Yellow }
    Write-Host 'If a shortcut still opens elevated, inspect its target executable Compatibility settings.' -ForegroundColor DarkCyan
    Write-Host 'A shortcut cannot override a Windows executable configured to always elevate.' -ForegroundColor DarkCyan
}

function Show-Help {
    Write-Host ''
    Write-Host 'PROJECT SHELL - TIPS' -ForegroundColor Cyan
    Write-Host 'Use a separate shortcut for each task: UGA - Testing, UGA - Reports, COA - Testing.'
    Write-Host 'Use the same project group to connect variants. Each link opens its own window.'
    Write-Host 'Normal mode is preferred for test runs. Admin mode only when truly needed.'
    Write-Host 'Admin: No always uses Windows PowerShell 5.1 (normal manager engine).'
    Write-Host 'Use Browse to select a starting folder; your selection automatically fills the setting.'
    Write-Host 'Select Folder to land in an interactive project shell, or Script/Command to run a task.'
    Write-Host 'The startup task runs at launch and again when you select Restart.'
    Write-Host 'Type psmenu in an open project shell to see its numbered menu again.'
    Write-Host 'Type psrestart to reset the folder and rerun the startup task.'
    Write-Host 'Choose session menu 5 or type pshome to return to your normal user home folder.'
    Write-Host 'For a matching classic console style, select menu 9 and confirm.'
    Write-Host 'Menu 6 rebuilds saved desktop links from clean shortcut files (with backups).'
    Write-Host 'Admin: No is a saved preference. Actual process elevation is shown at project launch.'
    Write-Host 'Do not launch normal tasks from an elevated manager; use the desktop links.'
    Write-Host 'Windows Terminal launch error 0x800702e4 means Windows requires elevation.'
    Write-Host 'If that happens, use classic console; do not enable Admin just to hide this error.'
    Write-Host 'Option 11 locates or repairs the NORMAL Manager desktop shortcut.'
    Write-Host 'For Administrator Manager desktop placement, rerun Install-ProjectShell.ps1.'
    Write-Host 'Deleting a shortcut here does not delete the project or its files.'
    Write-Host ''
}

function Show-ManagerDesktopShortcut {
    $managerLink = Join-Path $script:Desktop 'Project Shell Manager.lnk'
    Write-Host ''
    Write-Host 'MANAGER DESKTOP SHORTCUT | LOCATE / REPAIR' -ForegroundColor Cyan
    Write-Host ('Configured desktop folder: ' + $script:Desktop)
    Write-Host ('Expected manager link:    ' + $managerLink)
    Write-Host ('Actual program:          ' + $script:ProgramPath)
    if (Test-IsAdmin) {
        Write-Host 'WARNING: this manager is elevated. Creating a desktop link will not remove elevation from this window.' -ForegroundColor Yellow
    }
    if (-not (Test-Path -LiteralPath $script:Desktop -PathType Container)) {
        Write-Host 'The saved desktop folder is missing. Re-run Install-ProjectShell.ps1 to select the correct folder.' -ForegroundColor Red
        return
    }
    if (-not (Test-Path -LiteralPath $managerLink -PathType Leaf)) {
        Write-Host 'The manager desktop shortcut is missing.' -ForegroundColor Yellow
        if (Read-YesNo 'Create it now?' $true) {
            $shell = New-Object -ComObject WScript.Shell
            try {
                $link = $shell.CreateShortcut($managerLink)
                $ps = Get-StandardPowerShellExe
                $link.TargetPath = $ps
                $link.Arguments = '-NoLogo -ExecutionPolicy Bypass -File ' + (Quote-Arg $script:ProgramPath)
                $link.WorkingDirectory = Split-Path -Path $script:ProgramPath -Parent
                $link.IconLocation = $ps + ',0'
                $link.Description = 'Project Shell Manager - named PowerShell project shortcuts'
                $link.Save()
                Write-Host ('Created manager link: ' + $managerLink) -ForegroundColor Green
            }
            finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
        }
    }
    if (Test-Path -LiteralPath $managerLink -PathType Leaf) {
        Write-Host 'Shortcut file exists on the configured desktop.' -ForegroundColor Green
        if (Read-YesNo 'Show it in File Explorer?' $true) {
            try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $managerLink + '"') }
            catch { Write-Host ('Could not open File Explorer: ' + $_.Exception.Message) -ForegroundColor Yellow }
        }
        Write-Host 'If the file is in Explorer but not on your screen, check Desktop > View > Show desktop icons.' -ForegroundColor DarkCyan
        Write-Host 'If the path is the wrong desktop, rerun the installer and choose Browse.' -ForegroundColor DarkCyan
    }
}

function Show-LauncherAudit {
    Write-Host ''
    Write-Host 'PROJECT SHORTCUT AUDIT | ADMIN: NO vs YES' -ForegroundColor Cyan
    $profiles = @(Read-Store)
    if ($profiles.Count -eq 0) { Write-Host 'No saved project profiles.'; return }
    $expected = Get-StandardPowerShellExe
    $shell = New-Object -ComObject WScript.Shell
    try {
        foreach ($entry in $profiles) {
            $path = Profile-LinkPath $entry
            $mode = if ([bool]$entry.Admin) { 'ADMIN (explicit UAC)' } else { 'STANDARD (no UAC)' }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                Write-Host ('MISSING: ' + $entry.Name + ' [' + $mode + ']') -ForegroundColor Yellow
                continue
            }
            $link = $shell.CreateShortcut($path)
            try {
                $engineTarget = if ([string]$entry.Terminal -eq 'WindowsTerminal' -and -not [bool]$entry.Admin) { Get-TerminalExe } else { $expected }
                $engineMatches = [string]::Equals([string]$link.TargetPath, [string]$engineTarget, [StringComparison]::OrdinalIgnoreCase)
                $runasFlag = Get-LinkRunAsFlag $path
                $argumentsOK = ([string]$link.Arguments -match '(?i)(?:^|\s)-LaunchId(?:\s|$)') -and
                    ([string]$link.Arguments -notmatch '(?i)(?:^|\s)-ElevateManager(?:\s|$)')
                $check = $engineMatches -and -not $runasFlag -and $argumentsOK
                $color = if ($check) { 'Green' } else { 'Yellow' }
                Write-Host (($(if ($check) { 'PASS' } else { 'CHECK' })) + ': ' + $entry.Name + ' [' + $mode + ']') -ForegroundColor $color
                Write-Host ('  Target: ' + $link.TargetPath)
                if ([string]$entry.Terminal -eq 'WindowsTerminal') { Write-Host '  Windows Terminal selected: may have independent elevation settings.' -ForegroundColor Yellow }
                Write-Host ('  Link RunAs flag: ' + $runasFlag + ' | Launch ID arguments: ' + $argumentsOK)
                if (-not $check) { Write-Host '  Use menu 6 to rebuild this shortcut.' -ForegroundColor Yellow }
            }
            finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
        }
    }
    finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
}

function Show-Manager {
    while ($true) {
        $profiles = @(Read-Store)
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor Cyan
        Write-Host (' PROJECT SHELL | Shortcut Manager') -ForegroundColor Cyan
        Write-Host (" {0} saved shortcuts | {1}" -f $profiles.Count,$script:Desktop)
        if (Test-IsAdmin) {
            Write-Host ' ADMINISTRATOR MANAGER: standard project profiles will not launch here.' -ForegroundColor Yellow
        }
        Write-Host '============================================================' -ForegroundColor Cyan
        Write-Host '  1. Create desktop shortcut'
        Write-Host '  2. List and inspect shortcuts'
        Write-Host '  3. Open a project shortcut'
        Write-Host '  4. Create alternate starting point (clone)'
        Write-Host '  5. Edit shortcut'
        Write-Host '  6. Rebuild / refresh desktop shortcuts (clear old link flags)'
        Write-Host '  7. Remove shortcut'
        Write-Host '  8. Recommendations / help'
        Write-Host '  9. Match all shortcut windows to manager (classic console)'
        Write-Host ' 10. Diagnose a project shortcut'
        Write-Host ' 11. Locate / repair Manager desktop shortcut'
        Write-Host ' 12. Audit project shortcut elevation settings'
        Write-Host '  0. Exit manager'
        $choice = (Read-Host 'Number').Trim()
        try {
            switch ($choice) {
                '1' { $null = New-Profile $profiles }
                '2' {
                    if ($profiles.Count -eq 0) { Write-Host 'No saved shortcuts.'; break }
                    $selected = Select-Profile $profiles 'Inspect number'
                    if ($null -ne $selected) { Write-ProfileSummary $selected }
                }
                '3' {
                    $selected = Select-Profile $profiles 'Open number'
                    if ($null -ne $selected) { Start-Profile $selected }
                }
                '4' {
                    $selected = Select-Profile $profiles 'Clone number'
                    if ($null -ne $selected) { $null = New-Profile $profiles $selected }
                }
                '5' {
                    $selected = Select-Profile $profiles 'Edit number'
                    if ($null -ne $selected) { Edit-Profile $profiles $selected }
                }
                '6' {
                    foreach ($entry in $profiles) {
                        Write-ProfileLink $entry
                        Write-Host ("Restored: " + $entry.Name) -ForegroundColor Green
                    }
                }
                '7' {
                    $selected = Select-Profile $profiles 'Remove number'
                    if ($null -ne $selected -and (Read-YesNo ("Remove '" + $selected.Name + "' shortcut ONLY?") $false)) {
                        $remaining = @($profiles | Where-Object { $_.Id -ne $selected.Id })
                        Save-Store $remaining
                        $path = Profile-LinkPath $selected
                        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
                        Write-Host 'Removed shortcut/profile. Project files were not touched.' -ForegroundColor Green
                    }
                }
                '8' { Show-Help }
                '9' { Match-ManagerTerminalStyle $profiles }
                '10' {
                    $selected = Select-Profile $profiles 'Diagnose number'
                    if ($null -ne $selected) { Show-ShortcutDiagnostics $selected }
                }
                '11' { Show-ManagerDesktopShortcut }
                '12' { Show-LauncherAudit }
                '0' { return }
                default { Write-Host 'Choose a listed number.' -ForegroundColor Yellow }
            }
        }
        catch { Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red }
    }
}

function Get-ProfileById([string]$Id) {
    $profiles = @(Read-Store)
    $result = @($profiles | Where-Object { $_.Id -eq $Id })
    if ($result.Count -ne 1) { throw "Project profile not found: $Id" }
    return $result[0]
}

function Get-UserProfileFolder {
    # This is the user's HOME DIRECTORY, not the $PROFILE startup-script path.
    $folder = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrWhiteSpace($folder)) { $folder = $HOME }
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        throw ('Windows user profile folder was not found: ' + $folder)
    }
    return $folder
}

function Enter-UserProfileFolder {
    $folder = Get-UserProfileFolder
    Set-Location -LiteralPath $folder
    Write-Host ('Returned to your PowerShell home folder: ' + $folder) -ForegroundColor Green
}

function Set-ProjectTitle([string]$Name) {
    try { $Host.UI.RawUI.WindowTitle = $Name } catch { }
}

function Invoke-ProjectTask($entry) {
    Set-ProjectTitle $entry.Name
    if (-not (Test-Path -LiteralPath $entry.StartDirectory -PathType Container)) {
        Write-Host ('Missing starting folder: ' + $entry.StartDirectory) -ForegroundColor Red
        return
    }
    Set-Location -LiteralPath $entry.StartDirectory
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host (' ' + $entry.Name) -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('Project:  ' + $entry.Group)
    Write-Host ('Folder:   ' + $entry.StartDirectory)
    $elevated = Test-IsAdmin
    Write-Host ('ACTUAL process privilege: ' + $(if ($elevated) { 'Administrator' } else { 'Standard user' }))
    Write-Host ('Profile requests admin: ' + $(if ($entry.Admin) { 'Yes' } else { 'No' }))
    if ($elevated -and -not [bool]$entry.Admin) {
        Write-Host 'WARNING: standard profile opened in an elevated process.' -ForegroundColor Yellow
        Write-Host 'Close this window and launch the shortcut from a normal desktop session.' -ForegroundColor Yellow
        if ([string]$entry.StartupMode -in @('Script','Command')) {
            Write-Host 'Automatic startup task skipped to avoid unintended administrator execution.' -ForegroundColor Yellow
            return
        }
    }
    Write-Host ('Startup:  ' + $entry.StartupMode)
    Write-Host ''
    try {
        switch ([string]$entry.StartupMode) {
            'Folder' { Write-Host 'Ready for commands.' -ForegroundColor Green }
            'Script' {
                if (-not (Test-Path -LiteralPath $entry.StartupValue -PathType Leaf)) {
                    Write-Host 'Startup script does not exist.' -ForegroundColor Red
                }
                else { & $entry.StartupValue }
            }
            'Command' { & ([scriptblock]::Create([string]$entry.StartupValue)) }
            default { Write-Host 'Unknown startup mode. Nothing was executed.' -ForegroundColor Yellow }
        }
    }
    catch { Write-Host ('TASK ERROR: ' + $_.Exception.Message) -ForegroundColor Red }
    Set-ProjectTitle $entry.Name
}

function Show-OpenProjectMenu([string]$Id) {
    while ($true) {
        $entry = Get-ProfileById $Id
        Set-ProjectTitle $entry.Name
        Write-Host ''
        Write-Host (' ' + $entry.Name + ' | SESSION MENU') -ForegroundColor Cyan
        Write-Host '  1. Restart/reset this project task'
        Write-Host '  2. Return to starting folder (do not rerun task)'
        Write-Host '  3. Open alternate shortcut from this project group'
        Write-Host '  4. Show project settings'
        Write-Host '  5. Return to user profile (home folder)'
        Write-Host '  0. Return to PowerShell prompt'
        $answer = (Read-Host 'Number').Trim()
        try {
            switch ($answer) {
                '1' { Invoke-ProjectTask $entry }
                '2' { Set-Location -LiteralPath $entry.StartDirectory; Write-Host 'Folder restored.' -ForegroundColor Green }
                '3' {
                    $other = @((Read-Store) | Where-Object { $_.Group -ieq $entry.Group -and $_.Id -ne $entry.Id })
                    $selected = Select-Profile $other 'Open alternate number'
                    if ($null -ne $selected) { Start-Profile $selected }
                }
                '4' { Write-ProfileSummary $entry }
                '5' {
                    Enter-UserProfileFolder
                    # Leave the project menu so the user can enter regular commands.
                    # The project shortcut still retains its original starting folder.
                    return
                }
                '0' { return }
                default { Write-Host 'Choose a listed number.' -ForegroundColor Yellow }
            }
        }
        catch { Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red }
    }
}

try {
    if ($ElevateManager -and -not (Test-IsAdmin)) {
        # Dedicated admin manager entrypoint. Windows asks for UAC approval;
        # the normal manager launcher never calls this path.
        Write-Host 'Opening Project Shell Manager as Administrator (UAC approval required)...' -ForegroundColor Yellow
        $adminArguments = '-NoProfile -NoLogo -ExecutionPolicy Bypass -File ' +
            (Quote-Arg $script:ProgramPath) + ' -ElevateManager'
        try {
            Start-Process -FilePath (Get-PowerShellExe) -ArgumentList $adminArguments `
                -WorkingDirectory (Split-Path -Path $script:ProgramPath -Parent) -Verb RunAs | Out-Null
        }
        catch {
            Write-Host ('Administrator launch cancelled or blocked: ' + $_.Exception.Message) -ForegroundColor Yellow
        }
        return
    }
    if ($RefreshLinks) {
        Repair-SavedShortcuts -ConvertToConsole:$MatchConsole
        return
    }
    if ($LaunchId) {
        $entry = Get-ProfileById $LaunchId
        if (-not [bool]$entry.Admin -and (Test-IsAdmin)) {
            # Do not allow a standard project script/command to run elevated.
            Write-Host ('BLOCKED: ' + $entry.Name + ' is configured Admin: No, but this PowerShell process is elevated.') -ForegroundColor Red
            Write-Host 'Close this window and open the regular project shortcut from non-elevated Explorer.' -ForegroundColor Yellow
            Write-Host 'No project startup command was run.' -ForegroundColor Yellow
            return
        }
        if ([bool]$entry.Admin -and -not (Test-IsAdmin)) {
            Write-Host 'This shortcut requests administrator privileges. Windows will ask for approval.' -ForegroundColor Yellow
            $argumentText = '-NoLogo -NoExit -ExecutionPolicy Bypass -File ' + (Quote-Arg $script:ProgramPath) + ' -LaunchId ' + (Quote-Arg $LaunchId)
            try {
                Start-Process -FilePath (Get-PowerShellExe) -ArgumentList $argumentText -WorkingDirectory $entry.StartDirectory -Verb RunAs | Out-Null
                exit
            }
            catch {
                Write-Host 'Elevation was cancelled or blocked; no elevated action ran.' -ForegroundColor Yellow
                return
            }
        }
        if ($RestartOnly) {
            Invoke-ProjectTask $entry
        }
        elseif ($SessionMenu) {
            Show-OpenProjectMenu $LaunchId
        }
        else {
            $global:ProjectShell_Path = $script:ProgramPath
            $global:ProjectShell_ActiveId = $LaunchId
            function global:Restart-ProjectShell {
                & $global:ProjectShell_Path -LaunchId $global:ProjectShell_ActiveId -RestartOnly
            }
            function global:Show-ProjectShellMenu {
                & $global:ProjectShell_Path -LaunchId $global:ProjectShell_ActiveId -SessionMenu
            }
            function global:Return-ProjectShellHome {
                $folder = [Environment]::GetFolderPath('UserProfile')
                if ([string]::IsNullOrWhiteSpace($folder)) { $folder = $HOME }
                Set-Location -LiteralPath $folder
                Write-Host ('PowerShell home: ' + $folder) -ForegroundColor Green
            }
            Set-Alias -Name pshome -Value Return-ProjectShellHome -Scope Global -Force
            Set-Alias -Name psrestart -Value Restart-ProjectShell -Scope Global -Force
            Set-Alias -Name psmenu -Value Show-ProjectShellMenu -Scope Global -Force
            Invoke-ProjectTask $entry
            Write-Host ''
            Write-Host 'Type psmenu for numbered actions; pshome for your user folder; psrestart to rerun; exit to close.' -ForegroundColor DarkCyan
            Show-OpenProjectMenu $LaunchId
        }
    }
    else {
        # Even a normal shortcut can inherit administrator privileges when
        # started from an already-elevated parent. Refuse that accidental mode.
        if ((Test-IsAdmin) -and -not $ElevateManager) {
            Write-Host 'Normal Manager was launched inside an elevated process.' -ForegroundColor Yellow
            Write-Host 'For standard mode, open Project Shell Manager from non-elevated Explorer.' -ForegroundColor Yellow
            Write-Host 'For intentional admin mode, use Project Shell Manager (Administrator).' -ForegroundColor Yellow
            return
        }
        if (Test-IsAdmin) {
            Set-ProjectTitle 'Project Shell Manager (Administrator)'
        }
        else {
            Set-ProjectTitle 'Project Shell Manager'
        }
        Show-Manager
    }
}
catch {
    Write-Host ('PROJECT SHELL ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Your project folders were not changed by the shortcut manager.' -ForegroundColor Yellow
}
