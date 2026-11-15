# Installs/updates Project Shell at a stable path, preserving existing profiles.
# Re-run this installer after extracting the latest ProjectShell.zip.
[CmdletBinding()]
param(
    # Defaults to D:\DevTools\ProjectShell on computers with D:, otherwise
    # %LOCALAPPDATA%\Programs\ProjectShell. Can be overridden explicitly.
    [string]$InstallRoot = '',
    [switch]$Guided
)
$ErrorActionPreference = 'Stop'

# The EXE uses -Guided to offer a numbered installation-folder choice.
# Running the .ps1 directly retains the existing default/fallback behavior.
if ($Guided -and [string]::IsNullOrWhiteSpace($InstallRoot)) {
    $recommendedRoot = if (Test-Path -LiteralPath 'D:\' -PathType Container) {
        'D:\DevTools\ProjectShell'
    }
    else { Join-Path $env:LOCALAPPDATA 'Programs\ProjectShell' }
    $localRoot = Join-Path $env:LOCALAPPDATA 'Programs\ProjectShell'
    Write-Host ''
    Write-Host 'PROJECT SHELL | INSTALLATION LOCATION' -ForegroundColor Cyan
    Write-Host ('  1. Recommended: ' + $recommendedRoot)
    Write-Host ('  2. Local AppData: ' + $localRoot)
    Write-Host '  3. Type a different installation folder'
    Write-Host '  0. Cancel installation'
    do {
        $locationChoice = (Read-Host 'Number [1]').Trim()
        if (-not $locationChoice) { $locationChoice = '1' }
        if ($locationChoice -notin @('0','1','2','3')) {
            Write-Host 'Choose 0, 1, 2, or 3.' -ForegroundColor Yellow
        }
    } while ($locationChoice -notin @('0','1','2','3'))
    switch ($locationChoice) {
        '0' { Write-Host 'Installation cancelled.'; return }
        '1' { $InstallRoot = $recommendedRoot }
        '2' { $InstallRoot = $localRoot }
        '3' {
            $InstallRoot = (Read-Host 'Enter a full installation folder path').Trim().Trim('"')
            if ([string]::IsNullOrWhiteSpace($InstallRoot) -or -not [IO.Path]::IsPathRooted($InstallRoot)) {
                throw 'Please enter a nonempty absolute installation folder path.'
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    if (Test-Path -LiteralPath 'D:\' -PathType Container) {
        $InstallRoot = 'D:\DevTools\ProjectShell'
    }
    else {
        $InstallRoot = Join-Path $env:LOCALAPPDATA 'Programs\ProjectShell'
    }
}
$installRoot = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($InstallRoot))
$sourceRoot = $PSScriptRoot
$sourceProgram = Join-Path $sourceRoot 'ProjectShell.ps1'
$targetProgram = Join-Path $installRoot 'ProjectShell.ps1'
$dataRoot = Join-Path $env:LOCALAPPDATA 'ProjectShell'
$profileStore = Join-Path $dataRoot 'profiles.json'
$settingsFile = Join-Path $dataRoot 'settings.json'

if (-not (Test-Path -LiteralPath $sourceProgram -PathType Leaf)) {
    throw 'ProjectShell.ps1 must be next to Install-ProjectShell.ps1.'
}
New-Item -Path $installRoot -ItemType Directory -Force | Out-Null
New-Item -Path $dataRoot -ItemType Directory -Force | Out-Null

# When source and installation locations match, never copy a file onto itself.
# If extracted elsewhere, replace just the app/installer/readme at the stable installation path.
foreach ($fileName in @('ProjectShell.ps1', 'Install-ProjectShell.ps1', 'Install-ProjectShell.exe', 'Diagnose-Launch.ps1', 'README.md', 'README.txt')) {
    $from = Join-Path $sourceRoot $fileName
    $to = Join-Path $installRoot $fileName
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { continue }
    if (-not [string]::Equals([IO.Path]::GetFullPath($from), [IO.Path]::GetFullPath($to), [StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $from -Destination $to -Force
    }
}

$powerShell = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $powerShell) { $powerShell = Get-Command powershell.exe -ErrorAction Stop }
$systemPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $systemPowerShell -PathType Leaf)) {
    throw ('Windows PowerShell executable is missing: ' + $systemPowerShell)
}
# Standard project sessions always use the same working engine as the normal
# manager. Old NormalEngine=PowerShell7 settings are repaired on install.
$normalEngine = 'WindowsPowerShell'

function Get-NormalShellPath {
    return [string]$script:systemPowerShell
}

function Show-EngineCompatibility([string]$Path) {
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    )) {
        try {
            $settings = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            $setting = $settings.PSObject.Properties[$Path]
            if ($null -ne $setting -and [string]$setting.Value -match 'RUNASADMIN') {
                Write-Host ('WARNING: ' + $Path + ' is configured RUNASADMIN in ' + $key) -ForegroundColor Yellow
            }
        } catch { }
    }
}

function New-ManagerLink([string]$Destination, [bool]$Administrator = $false) {
    $parent = Split-Path -Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw ('Shortcut destination folder does not exist: ' + $parent)
    }
    $tempLink = Join-Path $parent ('.ProjectShell-Manager-' + [guid]::NewGuid().ToString('N') + '.lnk')
    $backupLink = Join-Path $parent ('.ProjectShell-OldManager-' + [guid]::NewGuid().ToString('N') + '.lnk')
    $shell = $null
    $link = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($tempLink)
        # Both manager shortcuts start through the known-working standard engine.
        # The ADMIN shortcut then explicitly requests UAC via -ElevateManager.
        $selectedPowerShell = Get-NormalShellPath
        $link.TargetPath = $selectedPowerShell
        # The administrator launcher requests UAC through ProjectShell.ps1's
        # -ElevateManager switch, not a persistent RunAs shortcut flag.
        $arguments = '-NoLogo -ExecutionPolicy Bypass -File "' + $targetProgram + '"'
        if ($Administrator) { $arguments += ' -ElevateManager' }
        $link.Arguments = $arguments
        $link.WorkingDirectory = $installRoot
        $link.Description = if ($Administrator) {
            'Project Shell Manager (Administrator) - asks for UAC approval'
        } else {
            'Project Shell Manager - normal non-administrator session'
        }
        $link.IconLocation = $selectedPowerShell + ',0'
        $link.WindowStyle = 1
        $link.Save()
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link)
        $link = $null
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
        $shell = $null

        # Both launchers use clean shell-link flags. Only the explicit admin
        # entrypoint performs elevation; normal manager never requests UAC.
        $header = [IO.File]::ReadAllBytes($tempLink)
        if ($header.Length -lt 0x4C -or [BitConverter]::ToUInt32($header, 0) -ne 0x4C -or
            (([BitConverter]::ToUInt32($header, 0x14) -band 0x2000) -ne 0)) {
            throw 'New shortcut is invalid or has unexpected RunAs flags. Existing shortcut was not changed.'
        }
        if (Test-Path -LiteralPath $Destination -PathType Leaf) {
            [IO.File]::Replace($tempLink, $Destination, $backupLink)
            try {
                $backupArchive = Join-Path $dataRoot ('manager-link-backup-' + [guid]::NewGuid().ToString('N') + '.lnk')
                Move-Item -LiteralPath $backupLink -Destination $backupArchive -Force -ErrorAction Stop
            }
            catch {
                Write-Host ('Previous shortcut backup remains at: ' + $backupLink) -ForegroundColor Yellow
            }
        }
        else { [IO.File]::Move($tempLink, $Destination) }
        Write-Host ('Manager shortcut: ' + $Destination) -ForegroundColor Green
    }
    finally {
        if ($null -ne $link) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
        if ($null -ne $shell) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
        if (Test-Path -LiteralPath $tempLink -PathType Leaf) {
            Remove-Item -LiteralPath $tempLink -Force -ErrorAction SilentlyContinue
        }
    }
}

function Add-DesktopCandidate([System.Collections.Generic.List[object]]$Candidates, [string]$Path, [string]$Source) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim('"'))
    try {
        if (-not (Test-Path -LiteralPath $expanded -PathType Container)) { return }
        $expanded = [IO.Path]::GetFullPath($expanded).TrimEnd('\')
    }
    catch { return }
    foreach ($current in $Candidates) {
        if ([string]::Equals([string]$current.Path, $expanded, [StringComparison]::OrdinalIgnoreCase)) {
            $current.Sources += $Source
            return
        }
    }
    $Candidates.Add([pscustomobject]@{ Path = $expanded; Sources = @($Source) })
}

function Get-DesktopCandidates {
    $found = [System.Collections.Generic.List[object]]::new()
    # Respect Windows' configured personal Desktop, including OneDrive redirection.
    try {
        $registered = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop).Desktop
        Add-DesktopCandidate $found ([string]$registered) 'Windows registered desktop'
    }
    catch { }
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shellDesktop = [string]$shell.SpecialFolders.Item('Desktop')
        Add-DesktopCandidate $found $shellDesktop 'Windows Shell desktop'
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }
    catch { }
    Add-DesktopCandidate $found ([Environment]::GetFolderPath('DesktopDirectory')) '.NET desktop folder'
    if (Test-Path -LiteralPath $settingsFile -PathType Leaf) {
        try {
            $old = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            Add-DesktopCandidate $found ([string]$old.DesktopPath) 'Previous Project Shell choice'
        }
        catch { Write-Host ('Previous desktop-path setting could not be read: ' + $_.Exception.Message) -ForegroundColor Yellow }
    }
    # These are candidate locations, not assumptions about which desktop is active.
    foreach ($oneDrive in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
        if (-not [string]::IsNullOrWhiteSpace($oneDrive)) {
            Add-DesktopCandidate $found (Join-Path $oneDrive 'Desktop') 'OneDrive desktop candidate'
        }
    }
    return @($found.ToArray())
}

function Browse-DesktopTarget {
    $shell = $null
    try {
        $shell = New-Object -ComObject Shell.Application
        $selected = $shell.BrowseForFolder(0, 'Select your actual Windows Desktop folder', 0x51, 0)
        if ($null -eq $selected) { return '' }
        $selectedPath = [string]$selected.Self.Path
        if (-not (Test-Path -LiteralPath $selectedPath -PathType Container)) {
            Write-Host 'Select an existing folder.' -ForegroundColor Yellow
            return ''
        }
        return [IO.Path]::GetFullPath($selectedPath)
    }
    catch {
        Write-Host ('Folder picker unavailable: ' + $_.Exception.Message) -ForegroundColor Yellow
        return ''
    }
    finally {
        if ($null -ne $shell) {
            try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) } catch { }
        }
    }
}

function Select-DesktopTarget {
    $candidates = @(Get-DesktopCandidates)
    # Prefer Windows' CURRENT registered Desktop, rather than an old saved choice
    # that may have caused shortcuts to be created somewhere not visible.
    $preferred = 0
    for ($i=0; $i -lt $candidates.Count; $i++) {
        if ($candidates[$i].Sources -contains 'Windows registered desktop') { $preferred = $i; break }
    }
    Write-Host ''
    Write-Host 'VERIFY DESKTOP LOCATION' -ForegroundColor Cyan
    Write-Host 'A shortcut can exist in a folder without appearing on your visible Desktop.'
    Write-Host 'Select the folder used by your Windows Desktop icons:'
    for ($i=0; $i -lt $candidates.Count; $i++) {
        $label = if ($i -eq $preferred) { ' [suggested]' } else { '' }
        Write-Host ((' {0}. {1}{2}' -f ($i+1),$candidates[$i].Path,$label))
        Write-Host ('      ' + ($candidates[$i].Sources -join '; ')) -ForegroundColor DarkGray
    }
    Write-Host '  B. Browse for the correct Desktop folder'
    Write-Host '  T. Type a different Desktop folder path'
    Write-Host '  0. Do not create a desktop shortcut'
    $suggested = if ($candidates.Count -gt 0) { [string]($preferred+1) } else { 'B' }
    while ($true) {
        $choice = (Read-Host ('Desktop folder choice [' + $suggested + ']')).Trim()
        if (-not $choice) { $choice = $suggested }
        if ($choice -eq '0') { return '' }
        if ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $candidates.Count) { return [string]$candidates[$index].Path }
        }
        elseif ($choice -ieq 'B') {
            $selected = Browse-DesktopTarget
            if ($selected) { return $selected }
        }
        elseif ($choice -ieq 'T') {
            $selected = (Read-Host 'Full Desktop folder path').Trim('"').Trim()
            $selected = [Environment]::ExpandEnvironmentVariables($selected)
            if (Test-Path -LiteralPath $selected -PathType Container) {
                return [IO.Path]::GetFullPath($selected)
            }
            Write-Host 'That folder does not exist.' -ForegroundColor Yellow
        }
        Write-Host 'Select one of the folder numbers, B, T, or 0.' -ForegroundColor Yellow
    }
}

function Save-DesktopTarget([string]$Folder) {
    $settings = [ordered]@{ DesktopPath = $Folder; NormalEngine = $script:normalEngine; Version = 2 }
    $tempFile = Join-Path $dataRoot ('settings-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $settings | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $tempFile -Encoding UTF8
        # This is a Project Shell-specific setting, not the project's saved profiles.
        [IO.File]::Copy($tempFile, $settingsFile, $true)
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force }
    }
}

function Assert-ManagerLink([string]$ShortcutPath, [bool]$Administrator = $false) {
    if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) {
        throw ('Created shortcut is missing: ' + $ShortcutPath)
    }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $null
    try {
        $shortcut = $shell.CreateShortcut($ShortcutPath)
        $expectedShell = Get-NormalShellPath
        if (-not [string]::Equals([string]$shortcut.TargetPath, $expectedShell, [StringComparison]::OrdinalIgnoreCase)) {
            throw ('Shortcut target mismatch at: ' + $ShortcutPath)
        }
        if ([string]$shortcut.Arguments -notlike ('*' + $targetProgram + '*')) {
            throw ('Shortcut no longer points to ProjectShell.ps1: ' + $ShortcutPath)
        }
        $hasAdminSwitch = ([string]$shortcut.Arguments -match '(?i)(?:^|\s)-ElevateManager(?:\s|$)')
        if ($hasAdminSwitch -ne $Administrator) {
            throw ('Shortcut elevation mode does not match its name: ' + $ShortcutPath)
        }
        $bytes = [IO.File]::ReadAllBytes($ShortcutPath)
        if ($bytes.Length -lt 0x4C -or [BitConverter]::ToUInt32($bytes, 0) -ne 0x4C -or
            (([BitConverter]::ToUInt32($bytes, 0x14) -band 0x2000) -ne 0)) {
            throw ('Shortcut has an unexpected RunAs flag: ' + $ShortcutPath)
        }
        $mode = if ($Administrator) { 'Administrator (UAC)' } else { 'Standard' }
        Write-Host ('Verified ' + $mode + ' manager shortcut: ' + $ShortcutPath) -ForegroundColor Green
    }
    finally {
        if ($null -ne $shortcut) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }
}

function Notify-ExplorerShortcut([string]$ShortcutPath) {
    try {
        if (-not ('ProjectShell.ShellNotify' -as [type])) {
            Add-Type -Namespace ProjectShell -Name ShellNotify -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern void SHChangeNotify(uint eventId, uint flags, string path, System.IntPtr other);
'@
        }
        # Notify Explorer that the shortcut was created/updated; no Explorer restart.
        [ProjectShell.ShellNotify]::SHChangeNotify(0x00002000, 0x0005, $ShortcutPath, [IntPtr]::Zero)
    }
    catch { Write-Host ('Explorer refresh notification unavailable: ' + $_.Exception.Message) -ForegroundColor DarkYellow }
}

Write-Host ''
Write-Host 'PROJECT SHELL | INSTALL / UPDATE' -ForegroundColor Cyan
Write-Host ('Program folder: ' + $installRoot)
Write-Host ('Profiles (preserved): ' + $profileStore)
Write-Host ''
Write-Host 'Always installed in the project folder:'
Write-Host '  Project Shell Manager.lnk                 (normal)' -ForegroundColor Green
Write-Host '  Project Shell Manager (Administrator).lnk (asks for UAC)' -ForegroundColor Yellow
Write-Host ''
Write-Host 'STANDARD / ADMIN LAUNCH POLICY' -ForegroundColor Cyan
Write-Host 'Admin: No  -> Windows PowerShell 5.1, no UAC requested.' -ForegroundColor Green
Write-Host 'Admin: Yes -> dedicated script requests UAC and uses PowerShell 7 when available.' -ForegroundColor Yellow
Write-Host 'This update repairs older NormalEngine=PowerShell7 settings for normal shortcuts.'
Show-EngineCompatibility ([string]$powerShell.Source)
Show-EngineCompatibility ([string]$systemPowerShell)
Write-Host ('Normal PowerShell executable: ' + (Get-NormalShellPath)) -ForegroundColor Green
Write-Host ''
Write-Host 'Which Manager launchers should ALSO be created/updated on the Desktop?'
Write-Host '  1. Normal only [recommended]'
Write-Host '  2. Normal AND Administrator'
Write-Host '  3. Administrator only'
Write-Host '  0. Skip desktop changes (existing desktop shortcuts unchanged)'
$choice = ''
do {
    $choice = (Read-Host 'Number [1]').Trim()
    if (-not $choice) { $choice = '1' }
    if ($choice -notin @('0','1','2','3')) {
        Write-Host 'Choose 0, 1, 2, or 3.' -ForegroundColor Yellow
    }
} while ($choice -notin @('0','1','2','3'))

# These two launcher links are always maintained side-by-side in the same stable
# installation folder, regardless of which optional desktop copies are chosen.
$folderNormal = Join-Path $installRoot 'Project Shell Manager.lnk'
$folderAdmin = Join-Path $installRoot 'Project Shell Manager (Administrator).lnk'
New-ManagerLink $folderNormal $false
Assert-ManagerLink $folderNormal $false
New-ManagerLink $folderAdmin $true
Assert-ManagerLink $folderAdmin $true

$desktop = ''
$desktopLinks = [System.Collections.Generic.List[string]]::new()
if ($choice -ne '0') {
    $desktop = Select-DesktopTarget
    if ($desktop) {
        if ($choice -in @('1','2')) {
            $desktopNormal = Join-Path $desktop 'Project Shell Manager.lnk'
            New-ManagerLink $desktopNormal $false
            Assert-ManagerLink $desktopNormal $false
            Notify-ExplorerShortcut $desktopNormal
            $desktopLinks.Add($desktopNormal)
        }
        if ($choice -in @('2','3')) {
            $desktopAdmin = Join-Path $desktop 'Project Shell Manager (Administrator).lnk'
            New-ManagerLink $desktopAdmin $true
            Assert-ManagerLink $desktopAdmin $true
            Notify-ExplorerShortcut $desktopAdmin
            $desktopLinks.Add($desktopAdmin)
        }
    }
    else {
        Write-Host 'Desktop shortcuts skipped. Folder launchers are ready.' -ForegroundColor Yellow
    }
    if ($desktop -and $choice -in @('1','3')) {
        # A previous installation may have left the OTHER desktop launcher.
        # Offer to remove it so the user's new placement choice is accurate.
        $unselectedName = if ($choice -eq '1') { 'Project Shell Manager (Administrator).lnk' } else { 'Project Shell Manager.lnk' }
        $oldDesktopLink = Join-Path $desktop $unselectedName
        if (Test-Path -LiteralPath $oldDesktopLink -PathType Leaf) {
            Write-Host ('Previous unselected Desktop launcher found: ' + $oldDesktopLink) -ForegroundColor Yellow
            $removeChoice = (Read-Host 'Move unselected desktop launcher to a backup? (Y/n)').Trim()
            if ($removeChoice -notin @('n','N','no','NO','No')) {
                $backupPath = Join-Path $dataRoot ('unselected-manager-backup-' + [guid]::NewGuid().ToString('N') + '.lnk')
                Move-Item -LiteralPath $oldDesktopLink -Destination $backupPath -Force
                Write-Host ('Backed up unused Desktop shortcut: ' + $backupPath) -ForegroundColor Green
                Notify-ExplorerShortcut $oldDesktopLink
            }
        }
    }
}

# Persist the standard/non-admin engine regardless of desktop shortcut placement.
# If the user skips desktop links, keep an earlier saved DesktopPath.
if (-not $desktop -and (Test-Path -LiteralPath $settingsFile -PathType Leaf)) {
    try {
        $priorSettings = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if (Test-Path -LiteralPath ([string]$priorSettings.DesktopPath) -PathType Container) {
            $desktop = [string]$priorSettings.DesktopPath
        }
    }
    catch { }
}
if (-not $desktop) { $desktop = [Environment]::GetFolderPath('DesktopDirectory') }
Save-DesktopTarget $desktop

# Profiles are intentionally still stored in AppData. Reusing the same profile store
# means project titles, startup actions, folders and admin options survive upgrades.
if (Test-Path -LiteralPath $profileStore -PathType Leaf) {
    $saved = Get-Content -LiteralPath $profileStore -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $saved -or $null -eq $saved.Profiles) { throw 'The existing profiles.json appears invalid. Nothing was reset.' }
    $profiles = @($saved.Profiles)
    if ($profiles.Count -gt 0) {
        $terminalCount = @($profiles | Where-Object { [string]$_.Terminal -eq 'WindowsTerminal' }).Count
        $convertToConsole = $false
        if ($terminalCount -gt 0) {
            Write-Host ''
            Write-Host ('Found ' + $terminalCount + ' Windows Terminal profile(s).') -ForegroundColor Yellow
            $answer = (Read-Host 'Switch these to classic PowerShell and refresh links? (Y/n)').Trim().ToLowerInvariant()
            $convertToConsole = ($answer -notin @('n', 'no'))
        }
        Write-Host ''
        Write-Host 'Rebuilding existing project links with verified standard/UAC launch rules...' -ForegroundColor Cyan
        & $targetProgram -RefreshLinks -MatchConsole:$convertToConsole
    }
}
Write-Host ''
Write-Host 'Project Shell updated successfully.' -ForegroundColor Green
Write-Host ('Installed program: ' + $targetProgram)
Write-Host ('Saved profiles:     ' + $profileStore)
Write-Host ('Normal launcher:    ' + $folderNormal)
Write-Host ('Admin launcher:     ' + $folderAdmin)
Write-Host ('Standard engine:    ' + (Get-NormalShellPath))
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'NOTE: Installer is elevated. Open the normal manager directly from non-elevated Explorer.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'No manager is auto-launched at the end of installation.' -ForegroundColor Cyan
if ($desktopLinks.Count -gt 0) {
    Write-Host ('Chosen Desktop folder: ' + $desktop) -ForegroundColor Cyan
    foreach ($path in $desktopLinks) {
        Write-Host ('Created/verified: ' + $path)
    }
    $openLocation = (Read-Host 'Open File Explorer with the first desktop shortcut selected? (y/N)').Trim().ToLowerInvariant()
    if ($openLocation -in @('y','yes')) {
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $desktopLinks[0] + '"') }
        catch { Write-Host ('Could not open File Explorer: ' + $_.Exception.Message) -ForegroundColor Yellow }
    }
    Write-Host 'If Explorer finds the file but the icon is not visible, check Desktop > View > Show desktop icons.' -ForegroundColor DarkCyan
}
