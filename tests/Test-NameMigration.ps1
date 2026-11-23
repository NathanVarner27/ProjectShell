# Isolated Windows PowerShell 5.1 / PowerShell 7 tests for ProjectShell migration.
# No real Desktop, existing profiles, GitHub repositories, or external project files touched.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent
$temp = Join-Path $env:TEMP ('ProjectShell-NameMigration-' + [guid]::NewGuid().ToString('N'))
New-Item -Path $temp -ItemType Directory -Force | Out-Null
function Assert([bool]$OK,[string]$Description) {
    if (-not $OK) { throw ('FAIL: ' + $Description) }
    Write-Host ('PASS: ' + $Description) -ForegroundColor Green
}

try {
    $script:AppRoot = Join-Path $temp 'AppData'
    $script:StorePath = Join-Path $script:AppRoot 'profiles.json'
    $script:WorkspaceStorePath = Join-Path $script:AppRoot 'workspaces.json'
    $script:Desktop = Join-Path $temp 'FakeDesktop'
    $script:ProgramPath = Join-Path $temp 'ProjectShell.ps1'
    $project = Join-Path $temp 'GitHubPackageBuilder'
    $script:NameMigrationRoot = Join-Path $script:AppRoot 'name-migrations'
    New-Item -Path $script:Desktop,$script:AppRoot,$project -ItemType Directory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $project 'package_config.json') -Value '{"app_name":"GitHub Package Builder"}'
    $sourceHash = (Get-FileHash (Join-Path $project 'package_config.json') -Algorithm SHA256).Hash

    function Ensure-Store {
        New-Item -Path $script:AppRoot -ItemType Directory -Force | Out-Null
    }
    function Read-Store {
        if (-not (Test-Path -LiteralPath $script:StorePath -PathType Leaf)) { return @() }
        $data = Get-Content -LiteralPath $script:StorePath -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($data.Profiles)
    }
    function Save-Store([object[]]$Profiles) {
        ([pscustomobject]@{ Version=1; Profiles=@($Profiles) } | ConvertTo-Json -Depth 10) |
            Set-Content -LiteralPath $script:StorePath -Encoding UTF8
    }
    function Read-WorkspaceStore {
        return (Get-Content -LiteralPath $script:WorkspaceStorePath -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    function Save-WorkspaceStore($Data) {
        $Data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:WorkspaceStorePath -Encoding UTF8
    }
    function Get-SafeName([string]$Name) {
        return ($Name -replace '[\\/:*?"<>|]', '-')
    }
    function Write-ProfileLink($Entry) {
        $path = Join-Path $script:Desktop $Entry.ShortcutFile
        $shell = New-Object -ComObject WScript.Shell
        $link = $null
        try {
            $link = $shell.CreateShortcut($path)
            $link.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $link.Arguments = '-NoLogo -File "' + $script:ProgramPath + '" -LaunchId "' + $Entry.Id + '"'
            $link.WorkingDirectory = $Entry.StartDirectory
            $link.Save()
        }
        finally {
            if ($link) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
        }
    }

    . (Join-Path $root 'ProjectShell.Migration.ps1')
    $old = 'GitHub Package Builder'
    $new = 'Distribution Builder Pilot'
    $profiles = @(
        [pscustomobject]@{ Id='gpb-main'; Name=$old; Group=$old; ShortcutFile='ProjectShell - GitHub Package Builder.lnk'; StartDirectory=$project; MainLaunchable=(Join-Path $project 'GPB.exe'); StartupValue=''; Admin=$false; Terminal='Console' },
        [pscustomobject]@{ Id='gpb-test'; Name=($old+' - Testing'); Group='GPB'; ShortcutFile='ProjectShell - GitHub Package Builder - Testing.lnk'; StartDirectory=$project; MainLaunchable=''; StartupValue=''; Admin=$false; Terminal='Console' },
        [pscustomobject]@{ Id='other'; Name='Universal Game Audio'; Group='UGA'; ShortcutFile='ProjectShell - Universal Game Audio.lnk'; StartDirectory=$temp; MainLaunchable=''; StartupValue=''; Admin=$false; Terminal='Console' }
    )
    Save-Store $profiles
    Save-WorkspaceStore ([pscustomobject]@{
        Version=1; DevToolsRoot=$temp; Workspaces=@(
            [pscustomobject]@{ Id='gpb-ws'; Name=$old; Path=$project; Launchable=(Join-Path $project 'GPB.exe'); Installer=''; OtherState='preserve' },
            [pscustomobject]@{ Id='other-ws'; Name='Another App'; Path=$temp; Launchable=''; Installer='' }
        )
    })
    foreach ($p in $profiles) { Write-ProfileLink $p }
    $beforeProfile = Get-ProjectNameTransitionHash $script:StorePath
    $beforeWorkspace = Get-ProjectNameTransitionHash $script:WorkspaceStorePath

    $plan = New-ProjectNameTransitionPlan $old $new
    Assert (@($plan.ProfileChanges).Count -eq 2) 'Pilot previews the main + testing ProjectShell shortcuts'
    Assert (@($plan.WorkspaceChanges).Count -eq 1) 'Pilot previews the workspace identity change'
    Assert ((Get-ProjectNameTransitionHash $script:StorePath) -eq $beforeProfile) 'Preview does not change existing profiles'
    Assert ((Get-ProjectNameTransitionHash $script:WorkspaceStorePath) -eq $beforeWorkspace) 'Preview does not change workspace registry'
    Assert (-not (Test-Path -LiteralPath $script:NameMigrationRoot)) 'Preview creates no migration backup or receipt'
    Assert ((Get-FileHash (Join-Path $project 'package_config.json') -Algorithm SHA256).Hash -eq $sourceHash) 'Preview preserves external application contents'

    $rejected = $false
    try { $null = Invoke-ProjectNameTransition $plan 'yes' } catch { $rejected = $true }
    Assert $rejected 'Apply requires exact RENAME <old-name> confirmation'
    $receipt = Invoke-ProjectNameTransition $plan ('RENAME ' + $old)
    Assert ($receipt.Id -and (Test-Path -LiteralPath (Join-Path $script:NameMigrationRoot $receipt.Id) -PathType Container)) 'Apply creates rollback receipt and backups'

    $actual = @(Read-Store)
    Assert (@($actual | Where-Object { $_.Name -eq $new }).Count -eq 1) 'Main profile renamed'
    Assert (@($actual | Where-Object { $_.Name -eq ($new+' - Testing') }).Count -eq 1) 'Suffix profile renamed'
    Assert (@($actual | Where-Object { $_.Name -eq 'Universal Game Audio' }).Count -eq 1) 'Unrelated profile preserved'
    Assert ((@($actual | Where-Object { $_.Id -eq 'gpb-main' })[0].StartDirectory -eq $project)) 'Start directory not moved'
    Assert ((@($actual | Where-Object { $_.Id -eq 'gpb-test' })[0].Group -eq 'GPB')) 'Abbreviated group not silently changed'
    Assert ((@((Read-WorkspaceStore).Workspaces | Where-Object { $_.Name -eq $new }).Count -eq 1)) 'Workspace display name changed'
    Assert ((@((Read-WorkspaceStore).Workspaces | Where-Object { $_.Id -eq 'gpb-ws' })[0].OtherState -eq 'preserve')) 'Unrelated workspace metadata preserved'
    Assert (-not (Test-Path -LiteralPath (Join-Path $script:Desktop 'ProjectShell - GitHub Package Builder.lnk'))) 'Verified owned former shortcut removed'
    Assert (Test-Path -LiteralPath (Join-Path $script:Desktop 'ProjectShell - Distribution Builder Pilot.lnk') -PathType Leaf) 'New launch shortcut created'
    Assert ((Get-FileHash (Join-Path $project 'package_config.json') -Algorithm SHA256).Hash -eq $sourceHash) 'Apply did not edit external source code'

    $latest = Get-ProjectNameTransitionLatest
    $check = Test-ProjectNameTransition $latest
    Assert ($check.ProjectShellMetadataVerified) 'Post-migration state verifies'
    Assert (-not $check.ExternalApplicationRenameVerified) 'Full GPB rename remains pending outside ProjectShell'
    $badRollback = $false
    try { Undo-ProjectNameTransition $latest 'ROLLBACK wrong' } catch { $badRollback = $true }
    Assert $badRollback 'Rollback requires exact receipt confirmation'
    Undo-ProjectNameTransition $latest ('ROLLBACK ' + $receipt.Id)
    Assert ((Get-ProjectNameTransitionHash $script:StorePath) -eq $beforeProfile) 'Rollback restores original profiles byte-for-byte'
    Assert ((Get-ProjectNameTransitionHash $script:WorkspaceStorePath) -eq $beforeWorkspace) 'Rollback restores original workspaces byte-for-byte'
    Assert (Test-Path -LiteralPath (Join-Path $script:Desktop 'ProjectShell - GitHub Package Builder.lnk') -PathType Leaf) 'Rollback restores original owned shortcut'
    Assert (-not (Test-Path -LiteralPath (Join-Path $script:Desktop 'ProjectShell - Distribution Builder Pilot.lnk'))) 'Rollback removes new owned shortcut'
    Assert (-not (Get-ProjectNameTransitionLatest)) 'Rolled-back receipt no longer eligible for duplicate rollback'

    $invalid = $false
    try { $null = New-ProjectNameTransitionPlan 'GitHub Package Builder' '..\unsafe' } catch { $invalid = $true }
    Assert $invalid 'Invalid names and paths rejected'
    $stale = New-ProjectNameTransitionPlan $old $new
    $saved = @(Read-Store)
    $saved[2].Group = 'Unrelated profile edited after preview'
    Save-Store $saved
    $refused = $false
    try { $null = Invoke-ProjectNameTransition $stale ('RENAME ' + $old) } catch { $refused = $true }
    Assert $refused 'Stale plan refuses overwriting user edits'
    # One explicitly supplied legacy alias can be mapped in the same reviewed plan.
    $saved[2].Group = 'UGA'
    Save-Store $saved
    $aliasPlan = New-ProjectNameTransitionPlan $old $new 'GPB' 'DBP'
    Assert (@($aliasPlan.ProfileChanges).Count -eq 2) 'Explicit GPB alias is included in the pilot preview'
    $aliasReceipt = Invoke-ProjectNameTransition $aliasPlan ('RENAME ' + $old)
    $testingProfile = @((Read-Store) | Where-Object { $_.Id -eq 'gpb-test' })[0]
    Assert ($testingProfile.Group -eq 'DBP') 'Only explicitly mapped legacy short name changes'
    Assert ((@((Read-Store) | Where-Object { $_.Id -eq 'other' })[0].Group -eq 'UGA')) 'Unrelated short name is preserved'
    $aliasLatest = Get-ProjectNameTransitionLatest
    Undo-ProjectNameTransition $aliasLatest ('ROLLBACK ' + $aliasReceipt.Id)
    Assert ((Get-ProjectNameTransitionHash $script:StorePath) -eq $beforeProfile) 'Alias test rollback also restores all original settings'
    Write-Host 'PROJECTSHELL_NAME_MIGRATION_PILOT_TESTS_PASSED' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
