# Windows-only isolated installer smoke test.
# The package is extracted to a disposable location and the installer is
# run as a standard script with LOCALAPPDATA redirected to a disposable folder.
# Desktop link creation is explicitly skipped. No UAC/GUI/exe launcher executed.
param([Parameter(Mandatory=$true)][string]$ZipPath)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Windows-only test.' }
if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw 'Installer ZIP missing.' }

$sandbox = Join-Path $env:RUNNER_TEMP ('ProjectShell-IsolatedInstall-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $sandbox 'Package'
$installed = Join-Path $sandbox 'Installed'
$data = Join-Path $sandbox 'AppData'
New-Item -ItemType Directory -Path $package,$data -Force | Out-Null

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory([IO.Path]::GetFullPath($ZipPath), $package)
    $installer = Join-Path $package 'Install-ProjectShell.ps1'
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'Installer script missing from ZIP.' }
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $si = New-Object System.Diagnostics.ProcessStartInfo
    $si.FileName = $powershell
    $si.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $installer + '" -InstallRoot "' + $installed + '"'
    $si.WorkingDirectory = $package
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $si.RedirectStandardInput = $true
    $si.RedirectStandardOutput = $true
    $si.RedirectStandardError = $true
    $si.EnvironmentVariables['LOCALAPPDATA'] = $data

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $si
    if (-not $process.Start()) { throw 'Failed to start isolated installer.' }
    try {
        $process.StandardInput.WriteLine('0') # Never create or modify real Desktop links.
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(90000)) {
            $process.Kill()
            throw 'Installer timed out; desktop prompts or launch hang.'
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        if ($process.ExitCode -ne 0) {
            throw ('Installer failed: ' + $process.ExitCode + [Environment]::NewLine + $stdout + [Environment]::NewLine + $stderr)
        }
        if ($stdout -notmatch 'Project Shell updated successfully') {
            throw ('Installer did not report successful completion: ' + $stdout)
        }
    }
    finally { $process.Dispose() }

    foreach ($file in @('ProjectShell.ps1', 'ProjectShell.Workspaces.ps1',
                         'Install-ProjectShell.ps1', 'Diagnose-Launch.ps1', 'Install-ProjectShell.exe')) {
        $path = Join-Path $installed $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Installed file missing: ' + $file) }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath (Join-Path $package $file) -Algorithm SHA256).Hash) {
            throw ('Installed file hash differs from ZIP: ' + $file)
        }
    }

    $normal = Join-Path $installed 'Project Shell Manager.lnk'
    $admin = Join-Path $installed 'Project Shell Manager (Administrator).lnk'
    $com = New-Object -ComObject WScript.Shell
    try {
        foreach ($link in @(@($normal,$false),@($admin,$true))) {
            $shortcutPath = [string]$link[0]
            $isAdmin = [bool]$link[1]
            if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
                throw ('Manager shortcut missing: ' + $shortcutPath)
            }
            $lnk = $com.CreateShortcut($shortcutPath)
            if ($lnk.Arguments -notmatch 'ProjectShell.ps1') { throw 'Shortcut does not launch ProjectShell.ps1.' }
            if (($lnk.Arguments -match '-ElevateManager') -ne $isAdmin) {
                throw 'Manager shortcut requested incorrect elevation.'
            }
            $header = [IO.File]::ReadAllBytes($shortcutPath)
            if ($header.Length -lt 0x4c -or (([BitConverter]::ToUInt32($header,0x14) -band 0x2000) -ne 0)) {
                throw 'Manager shortcut has unsafe persistent RunAs flag.'
            }
        }
    }
    finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($com) }
    $settings = Join-Path $data 'ProjectShell\settings.json'
    if (-not (Test-Path -LiteralPath $settings -PathType Leaf)) { throw 'Temporary settings were not written.' }
    $prefs = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    if ($prefs.NormalEngine -ne 'WindowsPowerShell') { throw 'Normal manager is not configured for Windows PowerShell.' }
    Write-Host 'PROJECTSHELL_WINDOWS_ISOLATED_INSTALL_PASSED' -ForegroundColor Green
    Write-Host 'Verified installed scripts, native EXE copy, two manager shortcuts, and temporary preferences.'
    Write-Host 'No real Desktop changes. No UAC/GUI or EXE launcher execution.'
}
finally {
    if (Test-Path -LiteralPath $sandbox) {
        Remove-Item -LiteralPath $sandbox -Force -Recurse -ErrorAction SilentlyContinue
    }
}
