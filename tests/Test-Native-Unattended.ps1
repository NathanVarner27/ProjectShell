# Execute native installers only on disposable GitHub-hosted Windows CI.
param([Parameter(Mandatory=$true)][string]$ZipPath,[Parameter(Mandatory=$true)][string]$SetupPath)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT' -or $env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or -not $env:RUNNER_TEMP) { throw 'Disposable GitHub-hosted Windows runner required.' }
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProjectShell'
if (Test-Path -LiteralPath $key) { throw 'Pre-existing ProjectShell registration; no test executed.' }
$base = Join-Path $env:RUNNER_TEMP ('ProjectShell-Native-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $base 'Package'
$data = Join-Path $base 'AppData'
$installed = Join-Path $data 'Programs\ProjectShell'
$oldData = $env:LOCALAPPDATA
New-Item -ItemType Directory -Path $package,(Join-Path $data 'ProjectShell') -Force | Out-Null
$env:LOCALAPPDATA = $data
$profileFile = Join-Path $data 'ProjectShell\profiles.json'
Set-Content -LiteralPath $profileFile -Value '{"Profiles":[{"Id":"native-ci","Terminal":"WindowsTerminal"}]}' -Encoding UTF8
$profileHash = (Get-FileHash -LiteralPath $profileFile).Hash
function Invoke-Bounded([string]$File,[string]$Arguments,[int]$Expected=0) {
    $si = New-Object Diagnostics.ProcessStartInfo
    $si.FileName = $File
    $si.Arguments = $Arguments
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $p = [Diagnostics.Process]::Start($si)
    try {
        if (-not $p.WaitForExit(120000)) { $p.Kill(); throw 'Native process timed out.' }
        if ($p.ExitCode -ne $Expected) { throw ('Unexpected exit: '+$p.ExitCode+' from '+$File) }
    } finally { $p.Dispose() }
}
try {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $package
    $launchers = @((Join-Path $package 'Install-ProjectShell.exe'),(Resolve-Path -LiteralPath $SetupPath).Path)
    foreach ($launcher in $launchers) {
        Invoke-Bounded $launcher '--unknown' 87
        if (Test-Path -LiteralPath $key) { throw 'Unknown argument caused installation.' }
        Invoke-Bounded $launcher '--silent'
        Invoke-Bounded $launcher '--silent-with-progress'
        $r = Get-ItemProperty -LiteralPath $key
        if ($r.InstallLocation -ne $installed -or $r.DisplayVersion -ne '1.2.0' -or -not $r.QuietUninstallString) { throw 'Registration mismatch.' }
        foreach ($name in @('ProjectShell.ps1','Install-ProjectShell.ps1','Install-ProjectShell.exe','ProjectShell.Workspaces.ps1','ProjectShell.Catalogue.ps1','ProjectShell.Migration.ps1','Diagnose-Launch.ps1')) {
            if ((Get-FileHash -LiteralPath (Join-Path $installed $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $package $name)).Hash) { throw ('Installed file mismatch: '+$name) }
        }
        $sentinel = Join-Path $installed 'unrelated-user-file.txt'
        Set-Content -LiteralPath $sentinel -Value 'preserve'
        $shell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $uninstaller = Join-Path $installed 'Uninstall-ProjectShell.ps1'
        $uninstallArgs = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$uninstaller+'"'
        if ($r.QuietUninstallString -ne ('"'+$shell+'" '+$uninstallArgs)) { throw 'Unexpected registered uninstall command.' }
        Invoke-Bounded $shell $uninstallArgs
        if ((Test-Path -LiteralPath $key) -or -not (Test-Path -LiteralPath $sentinel) -or (Get-FileHash -LiteralPath $profileFile).Hash -ne $profileHash) { throw 'Uninstall or preservation failure.' }
        if (@(Get-ChildItem -LiteralPath $installed -Force).Count -ne 1) { throw 'Unexpected remaining managed install files.' }
        Remove-Item -LiteralPath $sentinel -Force
        [IO.Directory]::Delete($installed,$false)
    }
    Write-Host 'PROJECTSHELL_NATIVE_INSTALL_REINSTALL_UNINSTALL_PASSED'
} finally {
    $env:LOCALAPPDATA = $oldData
    # Do not blindly delete a registration or recursively erase arbitrary paths.
    # The disposable runner is discarded; failed evidence remains in the job log.
}
