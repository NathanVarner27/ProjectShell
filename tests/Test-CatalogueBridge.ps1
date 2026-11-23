# Windows PowerShell 5.1 / PowerShell 7 no-install Catalogue integration tests.
# Does not start Catalogue, any package manager, DISM, or elevated operations.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent
$temp = Join-Path $env:TEMP ('ProjectShell-CatalogueTest-' + [guid]::NewGuid().ToString('N'))
$originalCatalogue = $env:NATHANS_CATALOGUE_ROOT
New-Item -ItemType Directory -Path $temp -Force | Out-Null

function Assert([bool]$Pass,[string]$Description) {
    if (-not $Pass) { throw ('FAIL: ' + $Description) }
    Write-Host ('PASS: ' + $Description) -ForegroundColor Green
}

try {
    $script:AppRoot = Join-Path $temp 'AppData'
    $script:MockSevenZip = ''
    function Get-SevenZipExe { return $script:MockSevenZip }
    . (Join-Path $root 'ProjectShell.Catalogue.ps1')
    $kinds = @('7zip','windows-sandbox','winget','chocolatey')
    $providers = @('winget','windows-feature','manual','manual')
    foreach ($i in 0..3) {
        $request = New-ProjectShellDependencyRequest $kinds[$i]
        Assert ($request.schema_version -eq 1) ('Broker schema v1 for ' + $kinds[$i])
        Assert ($request.app_id -eq 'project-shell' -and $request.app_name -eq 'ProjectShell') 'Caller identity is a claim, not signing authority'
        Assert ($request.requests.Count -eq 1) ('One bounded request for ' + $kinds[$i])
        $one = @($request.requests)[0]
        Assert ($one.provider -eq $providers[$i]) ('Supported provider for ' + $kinds[$i])
        Assert (@($one.Keys | Where-Object { $_ -notin @('provider','action','package_id','feature_id','dependency_id','reason') }).Count -eq 0) 'No commands, URLs or approval controls'
        $file = Write-ProjectShellDependencyRequest $kinds[$i]
        Assert (Test-Path -LiteralPath $file -PathType Leaf) 'Request saved to private AppData'
        $bytes = [IO.File]::ReadAllBytes($file)
        Assert ($bytes.Length -gt 0 -and $bytes.Length -le 32768) 'Request within Catalogue 32 KiB limit'
        Assert (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf)) 'Request is UTF-8 without BOM'
        $parsed = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert ($parsed.schema_version -eq 1 -and $parsed.requests.Count -eq 1) 'Request decodes with exact broker shape'
    }
    $zip = New-ProjectShellDependencyRequest '7zip'
    Assert ($zip.requests[0].package_id -eq '7zip.7zip') '7-Zip exact WinGet package ID'
    $sandbox = New-ProjectShellDependencyRequest 'windows-sandbox'
    Assert ($sandbox.requests[0].feature_id -eq 'windows-sandbox' -and $sandbox.requests[0].action -eq 'enable') 'Sandbox is a Windows feature, not a package-manager package'

    $unsupported = $false
    try { $null = New-ProjectShellDependencyRequest 'pwsh' } catch { $unsupported = $true }
    Assert $unsupported 'Unmapped PowerShell module/runtime requests are rejected'

    $env:NATHANS_CATALOGUE_ROOT = ''
    Assert (-not (Get-ProjectShellCatalogueRoot)) 'No fixed D-drive Catalogue install assumption'
    Assert ($null -eq (Resolve-ProjectShellCatalogueCli)) 'Absent Catalogue preserves independent operation'
    $script:MockSevenZip = 'C:\Test\7z.exe'
    Assert ((Get-ProjectShellDependencyState '7zip').Status -eq 'Located') 'Detected 7-Zip does not require a package request'
    $script:MockSevenZip = ''
    Assert ((Get-ProjectShellDependencyState '7zip').Status -eq 'Missing') 'Missing 7-Zip is detected without invoking an installer'

    $fakeRoot = Join-Path $temp 'Catalogue'
    New-Item -Path (Join-Path $fakeRoot 'artifacts') -ItemType Directory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeRoot 'artifacts\NathansCatalogue.pyz') -Value 'mock only' -Encoding Ascii
    $script:ChosenCatalogueRoot = $fakeRoot
    function Read-Host { param([string]$Prompt) return $script:ChosenCatalogueRoot }
    Assert (Set-ProjectShellCatalogueRoot) 'Explicitly selected Catalogue folder is persisted'
    $actualRoot = Get-ProjectShellCatalogueRoot
    Write-Host ('Catalogue root test: expected=[' + $fakeRoot + '] actual=[' + [string]$actualRoot + '] settings=[' + (Get-Content -LiteralPath $script:CatalogueSettingsPath -Raw) + ']')
    Assert ($actualRoot -eq $fakeRoot) 'Catalogue root reused without requiring default D:\ path'
    Assert (Test-Path -LiteralPath $script:CatalogueSettingsPath -PathType Leaf) 'Only opt-in Catalogue setting is written'

    $source = Get-Content -LiteralPath (Join-Path $root 'ProjectShell.Catalogue.ps1') -Raw
    Assert (-not $source.Contains('--interactive-apply')) 'ProjectShell never requests Catalogue apply mode'
    Assert (-not ($source -match '(?i)Start-Process|Enable-WindowsOptionalFeature|winget install|choco install|--accept|Verb RunAs')) 'No direct system installation or silent elevation in bridge'
    Write-Host 'PROJECTSHELL_CATALOGUE_PREVIEW_TESTS_PASSED' -ForegroundColor Green
}
finally {
    $env:NATHANS_CATALOGUE_ROOT = $originalCatalogue
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
