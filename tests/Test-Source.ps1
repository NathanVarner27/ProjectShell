# Read-only validation: parse application scripts and check release invariants.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent
$files = @('ProjectShell.ps1', 'ProjectShell.Workspaces.ps1', 'ProjectShell.Catalogue.ps1', 'Install-ProjectShell.ps1', 'Diagnose-Launch.ps1')
foreach ($relative in $files) {
    $file = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing: $relative" }
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        foreach ($problem in $errors) { Write-Host ("$relative $($problem.Extent.StartLineNumber): $($problem.Message)") -ForegroundColor Red }
        throw "PowerShell parse failed: $relative"
    }
    Write-Host "PASS: $relative parsed under $($PSVersionTable.PSVersion)"
}

$app = Get-Content -LiteralPath (Join-Path $root 'ProjectShell.ps1') -Raw
$installer = Get-Content -LiteralPath (Join-Path $root 'Install-ProjectShell.ps1') -Raw
$diagnostic = Get-Content -LiteralPath (Join-Path $root 'Diagnose-Launch.ps1') -Raw
$workspace = Get-Content -LiteralPath (Join-Path $root 'ProjectShell.Workspaces.ps1') -Raw
$catalogue = Get-Content -LiteralPath (Join-Path $root 'ProjectShell.Catalogue.ps1') -Raw
$checks = @(
    @{ Name='Standard shell selection'; Pass=($app -match 'function Get-StandardPowerShellExe' -and $app.Contains('WindowsPowerShell\v1.0\powershell.exe')) },
    @{ Name='Explicit manager UAC'; Pass=($app -match '-ElevateManager' -and $app -match '-Verb RunAs') },
    @{ Name='Unexpected elevated task blocked'; Pass=($app -match 'No project startup command was run' -and $app -match 'Automatic startup task skipped') },
    @{ Name='Window titles and session home'; Pass=($app -match 'function Set-ProjectTitle' -and $app -match 'function Enter-UserProfileFolder') },
    @{ Name='Configurable install path'; Pass=($installer -match '\[string\]\$InstallRoot' -and $installer.Contains('Programs\ProjectShell')) },
    @{ Name='Guided EXE install path'; Pass=($installer -match '\[switch\]\$Guided' -and $installer.Contains('Install-ProjectShell.exe')) },
    @{ Name='Native launcher build scripts'; Pass=((Test-Path -LiteralPath (Join-Path $root 'native/InstallLauncher.c')) -and (Test-Path -LiteralPath (Join-Path $root 'scripts/build-native-installer.sh'))) },
    @{ Name='Diagnostic uses actual script folder'; Pass=($diagnostic -match '\$PSScriptRoot') },
    @{ Name='Application profiles stored outside installation'; Pass=($app -match 'Join-Path \$env:LOCALAPPDATA') },
    @{ Name='Catalogue broker module installed'; Pass=($installer.Contains('ProjectShell.Catalogue.ps1') -and $app.Contains('. $script:CatalogueModule')) },
    @{ Name='Catalogue preview only'; Pass=($catalogue.Contains('schema_version=1') -and $catalogue.Contains('dependency-request') -and -not $catalogue.Contains('--interactive-apply') -and -not $catalogue.Contains('Start-Process')) },
    @{ Name='Workspace module installed'; Pass=($installer.Contains('ProjectShell.Workspaces.ps1') -and $app.Contains('. $script:WorkspaceModule')) },
    @{ Name='Session tool launch and update menu'; Pass=($app.Contains('Start-ProfileLaunchable $entry') -and $app.Contains('Set-ProfileLaunchable $entry')) },
    @{ Name='Process-local ProjectShell folder handoff'; Pass=($app.Contains('function Set-ProjectShellLaunchContext') -and $app.Contains('$env:PROJECTSHELL_START_DIRECTORY') -and $app.Contains('Set-ProjectShellLaunchContext $entry') -and $workspace.Contains('Set-ProjectShellLaunchContext $Profile')) },
    @{ Name='Workspace source transfer approval'; Pass=($workspace.Contains('Assert-CopiedFolder') -and $workspace.Contains('Confirm original deletion after verifying copied content?')) },
    @{ Name='Tools stored independently from app'; Pass=($workspace.Contains('workspaces.json') -and $workspace.Contains('Save-WorkspaceStore')) },
    @{ Name='Installers never auto-run'; Pass=($workspace.Contains('not executed') -and $workspace.Contains('Invoke-SavedTool')) }
)
foreach ($check in $checks) {
    if (-not $check.Pass) { throw ('FAIL: ' + $check.Name) }
    Write-Host ('PASS: ' + $check.Name) -ForegroundColor Green
}
$nativeInstaller = Get-Content -LiteralPath (Join-Path $root 'native/InstallLauncher.c') -Raw
if (-not $installer.Contains('RawUI.WindowTitle = ''Project Shell | Installer''') -or
    -not $nativeInstaller.Contains('si.lpTitle = L"Project Shell | Installer";')) {
    throw 'FAIL: Project Shell installer title is missing.'
}
Write-Host 'PASS: Installer window title' -ForegroundColor Green
Write-Host 'Source validation completed. Windows desktop/UAC behavior requires separate manual verification.' -ForegroundColor Cyan
