# ProjectShell -> Nathan's Catalogue Dependency Broker v1 (alpha.13).
# Independent, user-initiated, PREVIEW ONLY. Never grants install/elevation authority.
# Contract: Catalogue docs/DEPENDENCY_BROKER_V1.md (schema_version=1).

$script:CatalogueSettingsPath = Join-Path $script:AppRoot 'catalogue-integration.json'
$script:CatalogueRequestDirectory = Join-Path $script:AppRoot 'dependency-requests'

function Get-ProjectShellCatalogueRoot {
    if (Test-Path -LiteralPath $script:CatalogueSettingsPath -PathType Leaf) {
        try {
            $saved = Get-Content -LiteralPath $script:CatalogueSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace([string]$saved.CatalogueRoot)) {
                return [string]$saved.CatalogueRoot
            }
        }
        catch { Write-Warning ('Catalogue integration settings could not be read: ' + $_.Exception.Message) }
    }
    if (-not [string]::IsNullOrWhiteSpace($env:NATHANS_CATALOGUE_ROOT)) {
        return [string]$env:NATHANS_CATALOGUE_ROOT
    }
    return ''
}

function Set-ProjectShellCatalogueRoot {
    Write-Host 'Catalogue is optional. Choose the extracted/current Catalogue alpha folder.' -ForegroundColor Cyan
    Write-Host 'It must contain artifacts\NathansCatalogue.pyz. Old dist EXEs are not used in this preview.'
    $value = (Read-Host 'Catalogue folder (blank cancels)').Trim().Trim('"')
    if (-not $value) { return $false }
    $path = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($value))
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        Write-Host 'Folder not found. No setting was changed.' -ForegroundColor Yellow
        return $false
    }
    $pyz = Join-Path $path 'artifacts\NathansCatalogue.pyz'
    if (-not (Test-Path -LiteralPath $pyz -PathType Leaf) -or
        ((Get-Item -LiteralPath $pyz -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Write-Host 'Current Catalogue zipapp not found as a regular file. No setting was changed.' -ForegroundColor Yellow
        return $false
    }
    if (-not (Test-Path -LiteralPath $script:AppRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $script:AppRoot -Force | Out-Null
    }
    $data = @{ Version = 1; CatalogueRoot = $path } | ConvertTo-Json
    [IO.File]::WriteAllText($script:CatalogueSettingsPath,$data,(New-Object System.Text.UTF8Encoding($false)))
    Write-Host ('Saved Catalogue location: ' + $path) -ForegroundColor Green
    return $true
}

function Resolve-ProjectShellCatalogueCli {
    $root = Get-ProjectShellCatalogueRoot
    if (-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) { return $null }
    $pyz = Join-Path $root 'artifacts\NathansCatalogue.pyz'
    if (-not (Test-Path -LiteralPath $pyz -PathType Leaf)) { return $null }
    if ((Get-Item -LiteralPath $pyz -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { return $null }
    $py = Get-Command 'py.exe' -ErrorAction SilentlyContinue
    if ($py -and $py.CommandType -eq 'Application') {
        return [pscustomobject]@{ Program = [string]$py.Source; Arguments = @('-3', $pyz) }
    }
    $python = Get-Command 'python.exe' -ErrorAction SilentlyContinue
    if ($python -and $python.CommandType -eq 'Application') {
        return [pscustomobject]@{ Program = [string]$python.Source; Arguments = @($pyz) }
    }
    return $null
}

function Get-ProjectShellDependencyState([string]$Id) {
    switch ($Id) {
        '7zip' {
            $path = Get-SevenZipExe
            if ($path) { return [pscustomobject]@{ Status='Located'; Detail=$path } }
            return [pscustomobject]@{ Status='Missing'; Detail='7z.exe was not located in PATH or the usual Program Files locations.' }
        }
        'windows-sandbox' {
            if ($env:OS -ne 'Windows_NT') { return [pscustomobject]@{ Status='Unknown'; Detail='Windows-only optional feature.' } }
            try {
                $feature = Get-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -ErrorAction Stop
                if ([string]$feature.State -eq 'Enabled') {
                    return [pscustomobject]@{ Status='Located'; Detail='Windows Sandbox optional feature is enabled.' }
                }
                return [pscustomobject]@{ Status='Missing'; Detail=('Windows Sandbox feature state: ' + $feature.State) }
            }
            catch { return [pscustomobject]@{ Status='Unknown'; Detail='Cannot read optional-feature state here (may need administrative inspection, supported Windows edition, and virtualization).' } }
        }
        'winget' {
            $cmd = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.CommandType -eq 'Application') {
                return [pscustomobject]@{ Status='Located'; Detail=([string]$cmd.Source + ' (path presence only; version/publisher not verified)') }
            }
            return [pscustomobject]@{ Status='Missing'; Detail='WinGet executable not found in PATH.' }
        }
        'chocolatey' {
            $cmd = Get-Command 'choco.exe' -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.CommandType -eq 'Application') {
                return [pscustomobject]@{ Status='Located'; Detail=([string]$cmd.Source + ' (path presence only; version/publisher not verified)') }
            }
            return [pscustomobject]@{ Status='Missing'; Detail='Chocolatey executable not found in PATH.' }
        }
        default { throw ('Unsupported ProjectShell dependency identifier: ' + $Id) }
    }
}

function New-ProjectShellDependencyRequest([string]$Id) {
    $item = switch ($Id) {
        '7zip' {
            @{ provider='winget'; action='install'; package_id='7zip.7zip'
               reason='Optional 7-Zip support for importing RAR and 7Z workspaces into ProjectShell.' }
        }
        'windows-sandbox' {
            @{ provider='windows-feature'; action='enable'; feature_id='windows-sandbox'
               reason='Optional isolated Windows testing for developer workflows; requires edition and virtualization review.' }
        }
        'winget' {
            @{ provider='manual'; action='locate'; dependency_id='winget'
               reason='Locate an existing WinGet installation for optional ProjectShell developer workflows.' }
        }
        'chocolatey' {
            @{ provider='manual'; action='locate'; dependency_id='chocolatey'
               reason='Locate an existing Chocolatey installation for optional developer workflows.' }
        }
        default { throw ('Dependency Broker v1 cannot represent this dependency: ' + $Id) }
    }
    return @{ schema_version=1; app_id='project-shell'; app_name='ProjectShell'; requests=@($item) }
}

function Write-ProjectShellDependencyRequest([string]$Id) {
    $request = New-ProjectShellDependencyRequest $Id
    $json = ConvertTo-Json -InputObject $request -Depth 6
    $encoding = New-Object System.Text.UTF8Encoding($false)
    if ($encoding.GetByteCount($json) -gt 32768) { throw 'Catalogue request exceeds its 32 KiB contract.' }
    if (-not (Test-Path -LiteralPath $script:CatalogueRequestDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $script:CatalogueRequestDirectory -Force | Out-Null
    }
    $file = Join-Path $script:CatalogueRequestDirectory ('project-shell-' + $Id + '-' + [guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($file,$json,$encoding)
    return $file
}

function Invoke-ProjectShellCataloguePreview([string]$Id) {
    $before = Get-ProjectShellDependencyState $Id
    Write-Host ('Dependency ' + $Id + ': ' + $before.Status + ' | ' + $before.Detail)
    if ($Id -in @('7zip','windows-sandbox') -and $before.Status -eq 'Located') {
        Write-Host 'Already located/enabled. No installation request is necessary.' -ForegroundColor Green
        return
    }
    if ($Id -eq 'windows-sandbox') {
        Write-Host 'Sandbox availability also depends on Windows edition, virtualization, and reboot readiness.' -ForegroundColor Yellow
    }
    if ($Id -eq '7zip' -and (Get-ProjectShellDependencyState 'winget').Status -ne 'Located') {
        Write-Host 'WinGet is not located; Catalogue can preview the package but cannot install through an absent provider.' -ForegroundColor Yellow
    }
    $path = Write-ProjectShellDependencyRequest $Id
    Write-Host ('Broker v1 request saved: ' + $path) -ForegroundColor Cyan
    Write-Host 'Preview only: ProjectShell never installs, updates, repairs, removes or elevates dependencies.' -ForegroundColor Yellow
    $client = Resolve-ProjectShellCatalogueCli
    if (-not $client) {
        Write-Host 'Catalogue alpha.13 zipapp or a Python 3 runtime could not be located.' -ForegroundColor Yellow
        Write-Host 'Configure the Catalogue folder with menu 6, or open its Tool Manager > System Dependencies and review the saved request manually.'
        Write-Host 'Manual fallback: consult the vendor documentation and install/reconfigure outside ProjectShell only if you choose.'
        return
    }
    if (-not (Read-YesNo 'Open the independent Catalogue read-only review here now? (No system changes)' $false)) { return }
    try {
        $args = @($client.Arguments) + @('dependency-request', $path)
        & $client.Program @args
        if ($LASTEXITCODE -ne 0) {
            Write-Host ('Catalogue preview failed or returned code ' + $LASTEXITCODE + '; no install outcome is assumed.') -ForegroundColor Yellow
        }
    }
    catch { Write-Host ('Catalogue preview could not start: ' + $_.Exception.Message) -ForegroundColor Yellow }
    $after = Get-ProjectShellDependencyState $Id
    Write-Host ('Recheck after Catalogue: ' + $after.Status + ' | ' + $after.Detail) -ForegroundColor Cyan
    Write-Host 'The broker preview does not authorize installation. Actual system-change support is not production-approved.' -ForegroundColor Yellow
}

function Show-ProjectShellDependencyStatus {
    Write-Host ''
    Write-Host 'PROJECTSHELL | OPTIONAL SYSTEM DEPENDENCIES' -ForegroundColor Cyan
    foreach ($id in @('7zip','windows-sandbox','winget','chocolatey')) {
        $state = Get-ProjectShellDependencyState $id
        Write-Host ('  {0}: {1} | {2}' -f $id, $state.Status, $state.Detail)
    }
    $pwsh = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
    Write-Host ('  PowerShell 7: ' + $(if ($pwsh) { 'Located (version not verified)' } else { 'Optional / not located' }))
    Write-Host '  Other PowerShell modules, runtimes, and tools: unsupported by this broker mapping; locate/install manually.'
    Write-Host '  Presence checks are not publisher, version compatibility, or signature verification.' -ForegroundColor DarkYellow
}

function Show-ProjectShellCatalogueMenu {
    while ($true) {
        Write-Host ''
        Write-Host 'PROJECTSHELL | SYSTEM DEPENDENCIES (CATALOGUE v1 PREVIEW)' -ForegroundColor Cyan
        Write-Host '  1. Inspect locally available dependencies (read only)'
        Write-Host '  2. Review optional 7-Zip for RAR/7Z imports'
        Write-Host '  3. Review optional Windows Sandbox feature'
        Write-Host '  4. Ask Catalogue to locate WinGet (manual lookup)'
        Write-Host '  5. Ask Catalogue to locate Chocolatey (manual lookup)'
        Write-Host '  6. Set/change Nathan''s Catalogue folder'
        Write-Host '  7. Show unsupported dependencies / manual fallback'
        Write-Host '  0. Back'
        $selection = (Read-Host 'Number').Trim()
        try {
            switch ($selection) {
                '1' { Show-ProjectShellDependencyStatus }
                '2' { Invoke-ProjectShellCataloguePreview '7zip' }
                '3' { Invoke-ProjectShellCataloguePreview 'windows-sandbox' }
                '4' { Invoke-ProjectShellCataloguePreview 'winget' }
                '5' { Invoke-ProjectShellCataloguePreview 'chocolatey' }
                '6' { $null = Set-ProjectShellCatalogueRoot }
                '7' {
                    Write-Host 'Dependency Broker v1 does not offer arbitrary PowerShell module installation, Python/Node/Java runtimes, Chocolatey self-repair, generic package-manager upgrades, or unlisted Windows features.' -ForegroundColor Yellow
                    Write-Host 'ProjectShell continues to work without these optional tools. Consult the relevant official vendor documentation for manual setup; no installer is run by ProjectShell.'
                    Write-Host 'Windows Sandbox is an optional Windows feature, not a WinGet/Chocolatey package.'
                }
                '0' { return }
                default { Write-Host 'Choose a listed number.' -ForegroundColor Yellow }
            }
        }
        catch { Write-Host ('Dependency preview error: ' + $_.Exception.Message) -ForegroundColor Red }
    }
}
