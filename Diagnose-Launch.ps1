# Read-only shortcut and PowerShell elevation diagnostics.
# Does not change Windows security or Project Shell profiles.
$ErrorActionPreference = 'Stop'
$root = 'D:\DevTools\ProjectShell'
$data = Join-Path $env:LOCALAPPDATA 'ProjectShell'
Write-Host 'PROJECT SHELL | LAUNCH DIAGNOSTICS' -ForegroundColor Cyan
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
Write-Host ('Current PowerShell: ' + (Get-Process -Id $PID).Path)
Write-Host ('Current session elevated: ' + $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
Write-Host ('Process __COMPAT_LAYER: ' + [string]$env:__COMPAT_LAYER)
Write-Host ''
$normal = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
$executables = @($normal)
if ($pwsh) { $executables += $pwsh.Source }
$locations = @($root)
$desktop = [Environment]::GetFolderPath('DesktopDirectory')
$locations += $desktop
$settingsFile = Join-Path $data 'settings.json'
if (Test-Path -LiteralPath $settingsFile) {
    try {
        $settings = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host ('Configured normal engine: ' + [string]$settings.NormalEngine)
        Write-Host ('Configured Desktop: ' + [string]$settings.DesktopPath)
        if (Test-Path -LiteralPath ([string]$settings.DesktopPath) -PathType Container) {
            $locations += [string]$settings.DesktopPath
        }
    }
    catch { Write-Host ('Settings warning: ' + $_.Exception.Message) -ForegroundColor Yellow }
}
Write-Host ''
foreach ($path in ($executables | Select-Object -Unique)) {
    Write-Host ('Executable: ' + $path)
    Write-Host ('Exists: ' + (Test-Path -LiteralPath $path -PathType Leaf))
    foreach ($regPath in @('HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
                           'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers')) {
        try {
            $values = Get-ItemProperty -LiteralPath $regPath -ErrorAction Stop
            $flag = $values.PSObject.Properties[$path]
            if ($null -ne $flag) { Write-Host ('  Compatibility [' + $regPath + ']: ' + $flag.Value) }
        }
        catch { }
    }
}
Write-Host ''
$names = @('Project Shell Manager.lnk', 'Project Shell Manager (Administrator).lnk')
$shell = New-Object -ComObject WScript.Shell
try {
    foreach ($location in ($locations | Select-Object -Unique)) {
        foreach ($name in $names) {
            $file = Join-Path $location $name
            Write-Host ('Shortcut: ' + $file)
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
                Write-Host '  Missing' -ForegroundColor Yellow
                continue
            }
            $lnk = $shell.CreateShortcut($file)
            try {
                Write-Host ('  Target: ' + $lnk.TargetPath)
                Write-Host ('  Arguments: ' + $lnk.Arguments)
                Write-Host ('  Working directory: ' + $lnk.WorkingDirectory)
                $bytes = [IO.File]::ReadAllBytes($file)
                if ($bytes.Length -ge 0x4c) {
                    $flag = (([BitConverter]::ToUInt32($bytes, 0x14) -band 0x2000) -ne 0)
                    Write-Host ('  Shortcut RunAs flag: ' + $flag)
                }
            }
            finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($lnk) }
        }
    }
}
finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
Write-Host ''
Write-Host 'NOTE: A normal shortcut can still elevate if its executable is configured RUNASADMIN.' -ForegroundColor Yellow
Write-Host 'Launch directly from a normal Windows desktop/Explorer session to test standard mode.'

Write-Host ''
Write-Host 'SAVED PROJECT SHORTCUTS | ACTUAL TARGET AUDIT' -ForegroundColor Cyan
$profileFile = Join-Path $data 'profiles.json'
if (Test-Path -LiteralPath $profileFile -PathType Leaf) {
    try {
        $savedProfiles = Get-Content -LiteralPath $profileFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $targetDesktop = $desktop
        if (Test-Path -LiteralPath $settingsFile -PathType Leaf) {
            $savedOptions = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if (Test-Path -LiteralPath ([string]$savedOptions.DesktopPath) -PathType Container) {
                $targetDesktop = [string]$savedOptions.DesktopPath
            }
        }
        $wsh = New-Object -ComObject WScript.Shell
        try {
            foreach ($entry in @($savedProfiles.Profiles)) {
                $path = Join-Path $targetDesktop ([string]$entry.ShortcutFile)
                $mode = if ([bool]$entry.Admin) { 'ADMIN: YES / requires UAC' } else { 'ADMIN: NO / must be standard' }
                Write-Host ('Project: ' + $entry.Name + ' | ' + $mode)
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                    Write-Host ('  MISSING: ' + $path) -ForegroundColor Yellow
                    continue
                }
                $link = $wsh.CreateShortcut($path)
                try {
                    Write-Host ('  Target: ' + $link.TargetPath)
                    Write-Host ('  Arguments: ' + $link.Arguments)
                    $bytes = [IO.File]::ReadAllBytes($path)
                    $flagged = $bytes.Length -ge 0x4C -and
                        (([BitConverter]::ToUInt32($bytes, 0x14) -band 0x2000) -ne 0)
                    $safeExe = [string]::Equals([string]$link.TargetPath, [string]$normal, [StringComparison]::OrdinalIgnoreCase)
                    $hasId = [string]$link.Arguments -match '(?i)(?:^|\s)-LaunchId(?:\s|$)'
                    $passed = $safeExe -and -not $flagged -and $hasId
                    Write-Host ('  Standard initial executable: ' + $safeExe)
                    Write-Host ('  Shortcut RunAs flag: ' + $flagged)
                    Write-Host ('  Audit: ' + $(if ($passed) { 'PASS' } else { 'CHECK - repair with manager menu 6' })) -ForegroundColor $(if ($passed) { 'Green' } else { 'Yellow' })
                }
                finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
            }
        }
        finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($wsh) }
    }
    catch { Write-Host ('Project shortcut audit failed: ' + $_.Exception.Message) -ForegroundColor Yellow }
}
