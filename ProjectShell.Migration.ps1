# ProjectShell application-name migration v1.
# User-controlled metadata transition. Never renames source trees, repositories,
# EXEs, installers, workspace folders, or command/script contents.
$script:NameMigrationRoot = Join-Path $script:AppRoot 'name-migrations'

function Assert-ProjectNameTransitionName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Trim() -ne $Name -or
        $Name.Length -gt 80 -or $Name.Length -lt 3 -or
        $Name -match '[\\/:*?"<>|\x00-\x1f]' -or $Name.EndsWith('.')) {
        throw 'Enter a name of 3-80 characters without path separators, invalid filename characters or surrounding spaces.'
    }
}

function Convert-ProjectNameTransitionValue([string]$Value,[string]$OldName,[string]$NewName) {
    if ([string]::Equals($Value,$OldName,[StringComparison]::OrdinalIgnoreCase)) { return $NewName }
    if ($Value.Length -gt ($OldName.Length+3) -and
        $Value.Substring(0,$OldName.Length).Equals($OldName,[StringComparison]::OrdinalIgnoreCase) -and
        $Value.Substring($OldName.Length).StartsWith(' - ',[StringComparison]::Ordinal)) {
        return ($NewName + $Value.Substring($OldName.Length))
    }
    return $Value
}

function Get-ProjectNameTransitionHash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function New-ProjectNameTransitionPlan([string]$OldName,[string]$NewName) {
    Assert-ProjectNameTransitionName $OldName
    Assert-ProjectNameTransitionName $NewName
    if ($OldName.Equals($NewName,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'The previous and proposed names must be different. Case-only renames are deferred.'
    }
    $profiles = @(Read-Store)
    $workspace = Read-WorkspaceStore
    $allWorkspaces = @($workspace.Workspaces)
    $profileChanges = [System.Collections.Generic.List[object]]::new()
    $workspaceChanges = [System.Collections.Generic.List[object]]::new()
    $plannedFiles = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($profile in $profiles) {
        $newTitle = Convert-ProjectNameTransitionValue ([string]$profile.Name) $OldName $NewName
        $newGroup = Convert-ProjectNameTransitionValue ([string]$profile.Group) $OldName $NewName
        if ($newTitle -cne [string]$profile.Name -or $newGroup -cne [string]$profile.Group) {
            if (@($profiles | Where-Object { $_.Id -ne $profile.Id -and $_.Name -ieq $newTitle }).Count -gt 0) {
                throw ('A project shortcut already uses the new name: ' + $newTitle)
            }
            $newLink = [string]$profile.ShortcutFile
            if ($newTitle -cne [string]$profile.Name) {
                $safeBase = 'ProjectShell - ' + (Get-SafeName $newTitle)
                $index = 1
                do {
                    $suffix = if ($index -eq 1) { '' } else { ' (' + $index + ')' }
                    $candidate = $safeBase + $suffix + '.lnk'
                    $target = Join-Path $script:Desktop $candidate
                    $taken = ((Test-Path -LiteralPath $target) -and
                        $candidate -ine [string]$profile.ShortcutFile) -or
                        $plannedFiles.Contains($candidate) -or
                        (@($profiles | Where-Object { $_.Id -ne $profile.Id -and $_.ShortcutFile -ieq $candidate }).Count -gt 0)
                    $index++
                } while ($taken -and $index -le 1000)
                if ($taken) { throw 'No safe desktop shortcut name available.' }
                $newLink = $candidate
            }
            [void]$plannedFiles.Add($newLink)
            $profileChanges.Add([pscustomobject]@{
                Id=[string]$profile.Id
                OldName=[string]$profile.Name
                NewName=$newTitle
                OldGroup=[string]$profile.Group
                NewGroup=$newGroup
                OldShortcut=[string]$profile.ShortcutFile
                NewShortcut=$newLink
                StartingFolder=[string]$profile.StartDirectory
                Launchable=[string]$profile.MainLaunchable
                StartupValue=[string]$profile.StartupValue
            })
        }
    }
    foreach ($item in $allWorkspaces) {
        $newLabel = Convert-ProjectNameTransitionValue ([string]$item.Name) $OldName $NewName
        if ($newLabel -cne [string]$item.Name) {
            if (@($allWorkspaces | Where-Object { $_.Id -ne $item.Id -and $_.Name -ieq $newLabel }).Count -gt 0) {
                throw ('A saved workspace already uses the new name: ' + $newLabel)
            }
            $workspaceChanges.Add([pscustomobject]@{
                Id=[string]$item.Id
                OldName=[string]$item.Name
                NewName=$newLabel
                Folder=[string]$item.Path
                Launchable=[string]$item.Launchable
                Installer=[string]$item.Installer
            })
        }
    }
    return [pscustomobject]@{
        SchemaVersion=1
        PreviousName=$OldName
        ProposedName=$NewName
        ProfileHash=(Get-ProjectNameTransitionHash $script:StorePath)
        WorkspaceHash=(Get-ProjectNameTransitionHash $script:WorkspaceStorePath)
        ProfileChanges=@($profileChanges.ToArray())
        WorkspaceChanges=@($workspaceChanges.ToArray())
    }
}

function Show-ProjectNameTransitionPlan($Plan) {
    Write-Host ''
    Write-Host 'PROJECTSHELL | APPLICATION NAME TRANSITION — PREVIEW' -ForegroundColor Cyan
    Write-Host ('Previous name: ' + $Plan.PreviousName)
    Write-Host ('Proposed name: ' + $Plan.ProposedName)
    Write-Host ('Saved shortcuts affected: ' + @($Plan.ProfileChanges).Count)
    foreach ($item in $Plan.ProfileChanges) {
        Write-Host ('  ' + $item.OldName + ' -> ' + $item.NewName)
        Write-Host ('    Desktop: ' + $item.OldShortcut + ' -> ' + $item.NewShortcut)
        Write-Host ('    Start folder stays: ' + $item.StartingFolder)
    }
    Write-Host ('Saved workspaces affected: ' + @($Plan.WorkspaceChanges).Count)
    foreach ($item in $Plan.WorkspaceChanges) {
        Write-Host ('  ' + $item.OldName + ' -> ' + $item.NewName)
        Write-Host ('    Folder stays: ' + $item.Folder)
    }
    Write-Host 'External identity checks needed for full transition:' -ForegroundColor Yellow
    Write-Host '  Source code identifiers, app title, package IDs and internal configuration'
    Write-Host '  EXE/ZIP/MSIX names, manifest/publisher data, installer/uninstaller/update paths'
    Write-Host '  README, help, tests, GitHub repository, CI, published release and backlinks'
    Write-Host '  Existing installs, backwards compatibility, rollback and Windows launch tests'
    Write-Host 'No application folders, source files, GitHub projects or installed programs are renamed.'
}

function Test-ProjectNameTransitionOwnedLink([string]$Path,[string]$Id) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $shell = $null; $link = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($Path)
        return ([string]$link.Arguments -match '(?i)(?:^|\s)-LaunchId(?:\s|$)' -and
            [string]$link.Arguments -match [regex]::Escape($Id) -and
            [string]$link.Arguments -match [regex]::Escape('ProjectShell.ps1'))
    }
    catch { return $false }
    finally {
        if ($null -ne $link) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
        if ($null -ne $shell) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
    }
}

function Invoke-ProjectNameTransition($Plan,[string]$Confirmation) {
    if ($Confirmation -cne ('RENAME ' + $Plan.PreviousName)) {
        throw ('To proceed, enter exactly: RENAME ' + $Plan.PreviousName)
    }
    if (@($Plan.ProfileChanges).Count + @($Plan.WorkspaceChanges).Count -eq 0) {
        throw 'No exact/prefix ProjectShell names match. Nothing to rename.'
    }
    if ($Plan.ProfileHash -cne (Get-ProjectNameTransitionHash $script:StorePath) -or
        $Plan.WorkspaceHash -cne (Get-ProjectNameTransitionHash $script:WorkspaceStorePath)) {
        throw 'Saved projects changed after the preview. Create a new plan before applying.'
    }
    foreach ($change in $Plan.ProfileChanges) {
        $target = Join-Path $script:Desktop $change.NewShortcut
        if ($change.NewShortcut -ine $change.OldShortcut -and (Test-Path -LiteralPath $target)) {
            throw ('Desktop shortcut already exists; preview again: ' + $target)
        }
    }
    Ensure-Store
    $id = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + [guid]::NewGuid().ToString('N')
    $folder = Join-Path $script:NameMigrationRoot $id
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
    $profilesBefore = Join-Path $folder 'profiles.before.json'
    $workspacesBefore = Join-Path $folder 'workspaces.before.json'
    $oldLinks = [System.Collections.Generic.List[object]]::new()
    $newLinks = [System.Collections.Generic.List[string]]::new()
    $profileTouched = (@($Plan.ProfileChanges).Count -gt 0)
    $workspaceTouched = (@($Plan.WorkspaceChanges).Count -gt 0)
    $profilesAfterHash = ''; $workspacesAfterHash = ''
    $committed = $false
    try {
        if ($profileTouched) { Copy-Item -LiteralPath $script:StorePath -Destination $profilesBefore -ErrorAction Stop }
        if ($workspaceTouched) { Copy-Item -LiteralPath $script:WorkspaceStorePath -Destination $workspacesBefore -ErrorAction Stop }
        foreach ($change in $Plan.ProfileChanges) {
            if ($change.OldShortcut -ine $change.NewShortcut) {
                $oldPath = Join-Path $script:Desktop $change.OldShortcut
                $backupFile = Join-Path $folder ('shortcut-' + [guid]::NewGuid().ToString('N') + '.lnk')
                $owned = Test-ProjectNameTransitionOwnedLink $oldPath $change.Id
                if ($owned) { Copy-Item -LiteralPath $oldPath -Destination $backupFile -ErrorAction Stop }
                $oldLinks.Add([pscustomobject]@{
                    Path=$oldPath
                    Backup=$(if ($owned) { $backupFile } else { '' })
                    Owned=$owned
                })
            }
        }
        if ($profileTouched) {
            $profiles = @(Read-Store)
            foreach ($profile in $profiles) {
                foreach ($change in $Plan.ProfileChanges) {
                    if ([string]$profile.Id -eq $change.Id) {
                        $profile.Name = $change.NewName
                        $profile.Group = $change.NewGroup
                        $profile.ShortcutFile = $change.NewShortcut
                    }
                }
            }
            Save-Store $profiles
            foreach ($change in $Plan.ProfileChanges) {
                if ($change.NewShortcut -ine $change.OldShortcut) {
                    $entry = @($profiles | Where-Object { $_.Id -eq $change.Id })[0]
                    $newPath = Join-Path $script:Desktop $change.NewShortcut
                    [void]$newLinks.Add($newPath)
                    Write-ProfileLink $entry
                    if (-not (Test-Path -LiteralPath $newPath -PathType Leaf)) {
                        throw ('New shortcut was not created: ' + $newPath)
                    }
                }
            }
            $profilesAfterHash = Get-ProjectNameTransitionHash $script:StorePath
        }
        if ($workspaceTouched) {
            $data = Read-WorkspaceStore
            foreach ($item in $data.Workspaces) {
                foreach ($change in $Plan.WorkspaceChanges) {
                    if ([string]$item.Id -eq $change.Id) { $item.Name = $change.NewName }
                }
            }
            Save-WorkspaceStore $data
            $workspacesAfterHash = Get-ProjectNameTransitionHash $script:WorkspaceStorePath
        }
        $receipt = [pscustomobject]@{
            SchemaVersion=1; Id=$id; PreviousName=$Plan.PreviousName; ProposedName=$Plan.ProposedName
            ProfileTouched=$profileTouched; WorkspaceTouched=$workspaceTouched
            ProfilesBeforeHash=$Plan.ProfileHash; WorkspacesBeforeHash=$Plan.WorkspaceHash
            ProfilesAfterHash=$profilesAfterHash; WorkspacesAfterHash=$workspacesAfterHash
            ProfileChanges=@($Plan.ProfileChanges); WorkspaceChanges=@($Plan.WorkspaceChanges)
            OldLinks=@($oldLinks.ToArray()); NewLinks=@($newLinks.ToArray())
            ExternalNamingVerified=$false
        }
        $manifestPath = Join-Path $folder 'migration.json'
        $receipt | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8 -ErrorAction Stop
        # Only remove a previous ProjectShell-owned link after the new link and
        # receipt exist. Leave ambiguous/unowned links untouched.
        foreach ($link in $oldLinks) {
            if ($link.Owned -and (Test-Path -LiteralPath $link.Path -PathType Leaf)) {
                Remove-Item -LiteralPath $link.Path -Force -ErrorAction Stop
            }
        }
        $committed = $true
        Write-Host ('Migration receipt and backups: ' + $folder) -ForegroundColor Green
        return $receipt
    }
    finally {
        if (-not $committed) {
            if ($profileTouched -and (Test-Path -LiteralPath $profilesBefore -PathType Leaf)) {
                Copy-Item -LiteralPath $profilesBefore -Destination $script:StorePath -Force
            }
            if ($workspaceTouched -and (Test-Path -LiteralPath $workspacesBefore -PathType Leaf)) {
                Copy-Item -LiteralPath $workspacesBefore -Destination $script:WorkspaceStorePath -Force
            }
            foreach ($newLink in $newLinks) {
                if (Test-Path -LiteralPath $newLink -PathType Leaf) { Remove-Item -LiteralPath $newLink -Force }
            }
            foreach ($old in $oldLinks) {
                if ($old.Backup -and -not (Test-Path -LiteralPath $old.Path) -and
                    (Test-Path -LiteralPath $old.Backup -PathType Leaf)) {
                    Copy-Item -LiteralPath $old.Backup -Destination $old.Path
                }
            }
        }
    }
}

function Get-ProjectNameTransitionLatest {
    if (-not (Test-Path -LiteralPath $script:NameMigrationRoot -PathType Container)) { return $null }
    $folders = @(Get-ChildItem -LiteralPath $script:NameMigrationRoot -Directory |
        Sort-Object -Property Name -Descending)
    foreach ($dir in $folders) {
        $manifest = Join-Path $dir.FullName 'migration.json'
        $rollback = Join-Path $dir.FullName 'rolled-back.txt'
        if ((Test-Path -LiteralPath $manifest -PathType Leaf) -and
            -not (Test-Path -LiteralPath $rollback -PathType Leaf)) {
            return [pscustomobject]@{ Folder=$dir.FullName; Receipt=(Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json) }
        }
    }
    return $null
}

function Test-ProjectNameTransition($Record) {
    if (-not $Record) { throw 'No completed migration receipt is available.' }
    $r = $Record.Receipt
    $profileHashOK = (-not $r.ProfileTouched) -or ($r.ProfilesAfterHash -ceq (Get-ProjectNameTransitionHash $script:StorePath))
    $workspaceHashOK = (-not $r.WorkspaceTouched) -or ($r.WorkspacesAfterHash -ceq (Get-ProjectNameTransitionHash $script:WorkspaceStorePath))
    $newLinksOK = $true
    foreach ($link in $r.NewLinks) {
        if (-not (Test-Path -LiteralPath ([string]$link) -PathType Leaf)) { $newLinksOK = $false }
    }
    $remainingOld = @($r.OldLinks | Where-Object { Test-Path -LiteralPath ([string]$_.Path) -PathType Leaf })
    return [pscustomobject]@{
        ProjectShellMetadataVerified=($profileHashOK -and $workspaceHashOK -and $newLinksOK)
        OldShortcutLinksRemaining=$remainingOld.Count
        ExternalApplicationRenameVerified=$false
        ReceiptFolder=$Record.Folder
    }
}

function Undo-ProjectNameTransition($Record,[string]$Confirmation) {
    if (-not $Record) { throw 'No completed migration to roll back.' }
    $r = $Record.Receipt
    if ($Confirmation -cne ('ROLLBACK ' + $r.Id)) { throw ('Type exactly: ROLLBACK ' + $r.Id) }
    $check = Test-ProjectNameTransition $Record
    if (-not $check.ProjectShellMetadataVerified) {
        throw 'Projects or shortcuts changed since migration. Rollback refuses to overwrite them.'
    }
    if ($r.ProfileTouched) {
        $before = Join-Path $Record.Folder 'profiles.before.json'
        if ((Get-ProjectNameTransitionHash $before) -cne $r.ProfilesBeforeHash) { throw 'Profile backup checksum mismatch.' }
    }
    if ($r.WorkspaceTouched) {
        $before = Join-Path $Record.Folder 'workspaces.before.json'
        if ((Get-ProjectNameTransitionHash $before) -cne $r.WorkspacesBeforeHash) { throw 'Workspace backup checksum mismatch.' }
    }
    foreach ($old in $r.OldLinks) {
        if ($old.Backup -and (Test-Path -LiteralPath ([string]$old.Path))) {
            throw ('Old desktop shortcut path has been reused; rollback stopped: ' + $old.Path)
        }
    }
    foreach ($link in $r.NewLinks) {
        if (-not (Test-ProjectNameTransitionOwnedLink ([string]$link) ([string](@($r.ProfileChanges | Where-Object {
            (Join-Path $script:Desktop $_.NewShortcut) -eq [string]$link })[0].Id)))) {
            throw ('New shortcut ownership cannot be verified; rollback stopped: ' + $link)
        }
    }
    if ($r.ProfileTouched) {
        Copy-Item -LiteralPath (Join-Path $Record.Folder 'profiles.before.json') -Destination $script:StorePath -Force
    }
    if ($r.WorkspaceTouched) {
        Copy-Item -LiteralPath (Join-Path $Record.Folder 'workspaces.before.json') -Destination $script:WorkspaceStorePath -Force
    }
    foreach ($link in $r.NewLinks) { Remove-Item -LiteralPath ([string]$link) -Force }
    foreach ($old in $r.OldLinks) {
        if ($old.Backup) { Copy-Item -LiteralPath ([string]$old.Backup) -Destination ([string]$old.Path) -Force }
    }
    'Rolled back by explicit user request.' | Set-Content -LiteralPath (Join-Path $Record.Folder 'rolled-back.txt')
    Write-Host ('ProjectShell metadata restored from: ' + $Record.Folder) -ForegroundColor Green
}

function Show-ProjectNameTransitionMenu {
    $plan = $null
    while ($true) {
        Write-Host ''
        Write-Host 'PROJECTSHELL | APPLICATION NAME TRANSITION' -ForegroundColor Cyan
        Write-Host '  1. Plan/preview a name transition (read-only)'
        Write-Host '  2. Apply only ProjectShell-managed names (backup + exact approval)'
        Write-Host '  3. Verify latest ProjectShell-managed transition'
        Write-Host '  4. Roll back latest transition (only if no later changes)'
        Write-Host '  0. Back'
        $choice = (Read-Host 'Number').Trim()
        try {
            switch ($choice) {
                '1' {
                    $old = (Read-Host 'Current application name').Trim()
                    $next = (Read-Host 'Proposed application name').Trim()
                    $plan = New-ProjectNameTransitionPlan $old $next
                    Show-ProjectNameTransitionPlan $plan
                }
                '2' {
                    if (-not $plan) { Write-Host 'Use option 1 to preview first.' -ForegroundColor Yellow; continue }
                    if (-not (Read-YesNo 'Backups will be created. Apply only ProjectShell names?' $false)) { continue }
                    $typed = Read-Host ('Type RENAME ' + $plan.PreviousName)
                    $null = Invoke-ProjectNameTransition $plan $typed
                    $plan = $null
                    Write-Host 'Only ProjectShell-managed names changed. External identity checks are still pending.' -ForegroundColor Yellow
                }
                '3' {
                    $latest = Get-ProjectNameTransitionLatest
                    if (-not $latest) { Write-Host 'No completed transition.'; continue }
                    $result = Test-ProjectNameTransition $latest
                    Write-Host ('ProjectShell metadata verified: ' + $result.ProjectShellMetadataVerified)
                    Write-Host ('Previous desktop shortcuts remaining: ' + $result.OldShortcutLinksRemaining)
                    Write-Host 'Full application naming transition: NOT VERIFIED (external gates need separate review).' -ForegroundColor Yellow
                    Write-Host ('Receipt: ' + $result.ReceiptFolder)
                }
                '4' {
                    $latest = Get-ProjectNameTransitionLatest
                    if (-not $latest) { Write-Host 'No completed transition to roll back.'; continue }
                    Write-Host ('Selected receipt: ' + $latest.Receipt.Id)
                    if (-not (Read-YesNo 'Restore the saved ProjectShell metadata and links?' $false)) { continue }
                    $typed = Read-Host ('Type ROLLBACK ' + $latest.Receipt.Id)
                    Undo-ProjectNameTransition $latest $typed
                }
                '0' { return }
                default { Write-Host 'Choose a listed number.' -ForegroundColor Yellow }
            }
        }
        catch { Write-Host ('MIGRATION ERROR: ' + $_.Exception.Message) -ForegroundColor Red }
    }
}
