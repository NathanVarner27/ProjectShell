# Local DevTools workspaces and saved launch targets for ProjectShell.
# This module never downloads software or executes installers automatically.
$script:WorkspaceStorePath = Join-Path $script:AppRoot 'workspaces.json'

function Read-WorkspaceStore {
    if (-not (Test-Path -LiteralPath $script:WorkspaceStorePath -PathType Leaf)) {
        return [pscustomobject]@{ Version=1; DevToolsRoot=''; Workspaces=@() }
    }
    $saved = Get-Content -LiteralPath $script:WorkspaceStorePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $saved -or $null -eq $saved.Workspaces) { throw 'Invalid workspaces.json; no data was changed.' }
    return $saved
}

function Save-WorkspaceStore($Data) {
    Ensure-Store
    $tmp = Join-Path $script:AppRoot ('workspace-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $Data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $tmp -Encoding UTF8
        [IO.File]::Copy($tmp, $script:WorkspaceStorePath, $true)
    }
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } }
}

function ConvertTo-WorkspacePath([string]$Value, [string]$Base='') {
    $path = [Environment]::ExpandEnvironmentVariables($Value.Trim().Trim('"'))
    if (-not [IO.Path]::IsPathRooted($path)) {
        if (-not $Base) { throw 'Enter a complete folder path.' }
        $path = Join-Path $Base $path
    }
    return [IO.Path]::GetFullPath($path)
}

function Test-PathUnder([string]$Path, [string]$Parent) {
    $pathFull = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\')
    return ($pathFull -ieq $parentFull -or $pathFull.StartsWith($parentFull + '\', [StringComparison]::OrdinalIgnoreCase))
}

function Assert-WorkspaceRoot([string]$Path) {
    if ($Path -notmatch '^[a-zA-Z]:\\') { throw 'Select a local drive path, not a UNC/network location.' }
    if ($Path.TrimEnd('\') -ieq [IO.Path]::GetPathRoot($Path).TrimEnd('\')) {
        throw 'Do not select the root of a drive.'
    }
    $protected = @($env:SystemRoot, $env:ProgramFiles, [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'), $script:AppRoot)
    foreach ($folder in $protected) {
        if ($folder -and (Test-PathUnder $Path $folder)) { throw ('Protected workspace location: ' + $folder) }
    }
}

function Set-DevToolsRoot {
    $data = Read-WorkspaceStore
    $default = if ($data.DevToolsRoot) { [string]$data.DevToolsRoot }
        elseif (Test-Path -LiteralPath 'D:\' -PathType Container) { 'D:\DevTools' }
        else { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'DevTools' }
    Write-Host ''
    Write-Host ('DevTools folder: ' + $(if ($data.DevToolsRoot) { $data.DevToolsRoot } else { '(not configured)' })) -ForegroundColor Cyan
    $typed = (Read-Host "New root [$default] (0 cancels)").Trim()
    if ($typed -eq '0') { return $false }
    if (-not $typed) { $typed = $default }
    $root = ConvertTo-WorkspacePath $typed
    Assert-WorkspaceRoot $root
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        if (-not (Read-YesNo ("Create folder '$root'?") $true)) { return $false }
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    if ((Get-Item -LiteralPath $root -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'DevTools root cannot be a junction or symbolic link.'
    }
    $data.DevToolsRoot = $root
    Save-WorkspaceStore $data
    Write-Host ('Saved: ' + $root) -ForegroundColor Green
    return $true
}

function Assert-ArchiveName([string]$Entry, [string]$Root) {
    if (-not $Entry -or $Entry -match '^[\\/]' -or $Entry.Contains(':')) { throw ('Unsafe archive entry: ' + $Entry) }
    $normalized = $Entry.Replace('/', '\')
    if (@($normalized.Split('\') | Where-Object { $_ -eq '..' }).Count -gt 0) {
        throw ('Archive parent traversal blocked: ' + $Entry)
    }
    $target = [IO.Path]::GetFullPath((Join-Path $Root $normalized))
    if (-not (Test-PathUnder $target $Root)) { throw ('Archive escape blocked: ' + $Entry) }
    return $target
}

function Get-SevenZipExe {
    $found = Get-Command '7z.exe' -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    foreach ($base in @($env:ProgramFiles, [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'))) {
        if ($base) {
            $guess = Join-Path $base '7-Zip\7z.exe'
            if (Test-Path -LiteralPath $guess -PathType Leaf) { return $guess }
        }
    }
    return ''
}

function Expand-ToolArchive([string]$Source, [string]$Folder) {
    $extension = [IO.Path]::GetExtension($Source).ToLowerInvariant()
    if ($extension -eq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($Source)
        try {
            foreach ($entry in $archive.Entries) {
                $dest = Assert-ArchiveName $entry.FullName $Folder
                if ((($entry.ExternalAttributes -shr 16) -band 61440) -eq 40960) {
                    throw 'ZIP symlinks cannot be imported.'
                }
                if (-not $entry.Name) { New-Item -Path $dest -ItemType Directory -Force | Out-Null }
                else {
                    New-Item -Path (Split-Path -Path $dest -Parent) -ItemType Directory -Force | Out-Null
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $false)
                }
            }
        }
        finally { $archive.Dispose() }
    }
    elseif ($extension -in @('.rar','.7z')) {
        $sevenZip = Get-SevenZipExe
        if (-not $sevenZip) {
            Write-Host '7-Zip (7z.exe) is not installed or could not be located.' -ForegroundColor Yellow
            Write-Host 'ProjectShell will not install or download it itself.' -ForegroundColor Yellow
            if ((Get-Command Invoke-ProjectShellCataloguePreview -ErrorAction SilentlyContinue) -and
                (Read-YesNo 'Review the optional 7-Zip prerequisite in Catalogue (preview only)?' $false)) {
                Invoke-ProjectShellCataloguePreview '7zip'
                $sevenZip = Get-SevenZipExe
            }
            if (-not $sevenZip) {
                throw 'RAR and 7Z imports need 7-Zip. Use Catalogue to preview the dependency or install/locate it manually; retry the import after verification.'
            }
        }
        $listing = @(& $sevenZip l '-slt' $Source 2>&1)
        if ($LASTEXITCODE -ne 0) { throw '7-Zip failed to read archive entries.' }
        $entries = $false
        foreach ($line in $listing) {
            if ($line -match '^-{6,}\s*$') { $entries = $true; continue }
            if ($entries -and $line -match '^Path = (.*)$') { $null = Assert-ArchiveName $Matches[1] $Folder }
            if ($entries -and $line -match '^(Symbolic Link|Hard Link) = ') { throw 'Archive links are not accepted.' }
        }
        if (-not $entries) { throw 'Archive listing was not validated.' }
        & $sevenZip x '-y' ("-o$Folder") $Source | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Archive extraction failed.' }
    }
    else { throw 'Supported archive types: .zip, .rar, .7z.' }
    $links = @(Get-ChildItem -LiteralPath $Folder -Recurse -Force | Where-Object {
        $_.Attributes -band [IO.FileAttributes]::ReparsePoint
    })
    if ($links.Count -gt 0) { throw 'Imported symbolic links/junctions are not allowed.' }
}

function Assert-CopiedFolder([string]$Original, [string]$Copy) {
    $files = @(Get-ChildItem -LiteralPath $Original -Recurse -File -Force)
    $copies = @(Get-ChildItem -LiteralPath $Copy -Recurse -File -Force)
    if ($files.Count -ne $copies.Count) { throw 'File count mismatch. Original folder retained.' }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Original.TrimEnd('\').Length).TrimStart('\')
        $dest = Join-Path $Copy $relative
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) { throw ('Missing copied file: ' + $relative) }
        if ($file.Length -ne (Get-Item -LiteralPath $dest).Length) { throw ('Size mismatch: ' + $relative) }
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash) {
            throw ('Hash mismatch: ' + $relative)
        }
    }
}

function Get-LaunchableCandidates([string]$Folder) {
    $found = New-Object 'System.Collections.Generic.List[string]'
    foreach ($sub in @('', 'bin', 'dist', 'scripts', 'build', 'release')) {
        $dir = if ($sub) { Join-Path $Folder $sub } else { $Folder }
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue)) {
            if ($file.Extension.ToLowerInvariant() -in @('.exe','.ps1','.cmd','.bat','.py','.js','.jar')) {
                $found.Add($file.FullName)
                if ($found.Count -ge 30) { return @($found.ToArray()) }
            }
        }
    }
    return @($found.ToArray())
}

function Browse-ToolFile([string]$Kind) {
    $dialog = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Locate ' + $Kind + ' file'
        $dialog.Filter = 'Executable and script files|*.exe;*.msi;*.ps1;*.cmd;*.bat;*.py;*.js;*.jar|All files|*.*'
        $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return [string]$dialog.FileName }
    }
    catch {
        Write-Host ('File picker unavailable; paste the path instead: ' + $_.Exception.Message) -ForegroundColor Yellow
    }
    finally { if ($dialog) { $dialog.Dispose() } }
    return $null
}

function Read-ToolTarget([string]$Base, [string]$Kind, [string]$Current='') {
    $extensions = if ($Kind -eq 'installer') { @('.exe','.msi','.ps1','.cmd','.bat') }
        else { @('.exe','.ps1','.cmd','.bat','.py','.js','.jar') }
    while ($true) {
        Write-Host ''
        Write-Host ('SET ' + $Kind.ToUpperInvariant()) -ForegroundColor Cyan
        if ($Current) { Write-Host ('Current: ' + $Current) }
        $options = if ($Kind -eq 'installer') { @() } else { @(Get-LaunchableCandidates $Base) }
        for ($i=0; $i -lt $options.Count; $i++) { Write-Host ("  {0}. {1}" -f ($i+1),$options[$i]) }
        Write-Host '  90. Browse using the Windows file picker'
        Write-Host '  91. Type/paste an absolute or workspace-relative file path'
        Write-Host '  92. Clear saved selection'
        Write-Host '   0. Cancel'
        $choice = (Read-Host 'Number').Trim()
        if ($choice -eq '0') { return $null }
        if ($choice -eq '92') { return '' }
        if ($choice -eq '90') {
            $typed = Browse-ToolFile $Kind
            if (-not $typed) { continue }
        }
        elseif ($choice -eq '91') { $typed = (Read-Host 'File path').Trim() }
        else {
            $n = 0
            if (-not [int]::TryParse($choice,[ref]$n) -or $n -lt 1 -or $n -gt $options.Count) {
                Write-Host 'Choose a listed number.' -ForegroundColor Yellow
                continue
            }
            $typed = $options[$n-1]
        }
        try {
            $path = ConvertTo-WorkspacePath $typed $Base
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'File not found.' }
            if ([IO.Path]::GetExtension($path).ToLowerInvariant() -notin $extensions) { throw 'Unsupported file extension.' }
            return $path
        }
        catch { Write-Host ('Invalid selection: ' + $_.Exception.Message) -ForegroundColor Yellow }
    }
}

function Select-Workspace {
    $items = @((Read-WorkspaceStore).Workspaces | Sort-Object Name)
    if ($items.Count -eq 0) { Write-Host 'No saved workspaces.' -ForegroundColor Yellow; return $null }
    for ($i=0; $i -lt $items.Count; $i++) {
        Write-Host ("  {0}. {1} - {2}" -f ($i+1),$items[$i].Name,$items[$i].Path)
    }
    Write-Host '  0. Cancel'
    while ($true) {
        $v = (Read-Host 'Number').Trim()
        if ($v -eq '0') { return $null }
        $n=0
        if ([int]::TryParse($v,[ref]$n) -and $n -ge 1 -and $n -le $items.Count) { return $items[$n-1] }
        Write-Host 'Choose a listed number.' -ForegroundColor Yellow
    }
}

function Save-WorkspaceTarget([string]$Id, [string]$Kind) {
    $data = Read-WorkspaceStore
    $matches = @($data.Workspaces | Where-Object { $_.Id -eq $Id })
    if ($matches.Count -ne 1) { throw 'Workspace not found.' }
    $entry = $matches[0]
    $property = if ($Kind -eq 'installer') { 'Installer' } else { 'Launchable' }
    $selected = Read-ToolTarget ([string]$entry.Path) $Kind ([string]$entry.$property)
    if ($null -eq $selected) { return }
    $entry | Add-Member -NotePropertyName $property -NotePropertyValue $selected -Force
    Save-WorkspaceStore $data
    Write-Host ('Saved ' + $Kind + ': ' + $(if ($selected) { $selected } else { '(cleared)' })) -ForegroundColor Green
}

function New-DevWorkspace {
    $data = Read-WorkspaceStore
    if (-not $data.DevToolsRoot -or -not (Test-Path -LiteralPath ([string]$data.DevToolsRoot) -PathType Container)) {
        if (-not (Set-DevToolsRoot)) { return }
        $data = Read-WorkspaceStore
    }
    $root = [string]$data.DevToolsRoot
    Assert-WorkspaceRoot $root
    $name = (Read-Host 'Workspace name / folder name (0 cancels)').Trim()
    if ($name -eq '0') { return }
    if ($name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9 _.-]{0,79}$' -or $name -match '[. ]$' -or $name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') {
        throw 'Use a simple safe folder name (letters, digits, spaces, dots, underscores, hyphens).'
    }
    $destination = Join-Path $root $name
    if (@($data.Workspaces | Where-Object { $_.Name -ieq $name }).Count -gt 0) { throw 'Duplicate workspace name.' }
    Write-Host '  1. Create an empty workspace'
    Write-Host '  2. Copy/move an existing folder into workspace'
    Write-Host '  3. Import a ZIP, RAR, or 7Z archive'
    Write-Host '  4. Register an existing folder under DevTools (leave files in place)'
    Write-Host '  0. Cancel'
    $mode = (Read-Host 'Number').Trim()
    if ($mode -notin @('1','2','3','4')) { return }
    if ($mode -eq '4' -and -not (Test-Path -LiteralPath $destination -PathType Container)) { throw 'Existing workspace folder not found under DevTools root.' }
    if ($mode -ne '4' -and (Test-Path -LiteralPath $destination)) { throw 'Destination already exists. No overwrite is allowed.' }
    $source = ''
    if ($mode -eq '2') {
        $source = Read-Folder
        if (-not $source) { return }
        $source = ConvertTo-WorkspacePath $source
        if ((Get-Item -LiteralPath $source).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Cannot import a linked folder.' }
        if ($source.TrimEnd('\') -ieq [IO.Path]::GetPathRoot($source).TrimEnd('\')) { throw 'Cannot import a drive root.' }
        foreach ($protected in @($env:SystemRoot,$env:ProgramFiles,[Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),$script:AppRoot,(Split-Path -Path $script:ProgramPath -Parent))) {
            if ($protected -and (Test-PathUnder $source $protected)) { throw 'Cannot import system or ProjectShell installation directories.' }
        }
        foreach ($protected in @($env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA)) {
            if ($protected -and (Test-PathUnder $protected $source)) { throw 'Cannot import an entire user profile or AppData root.' }
        }
        $links = @(Get-ChildItem -LiteralPath $source -Recurse -Force | Where-Object {
            $_.Attributes -band [IO.FileAttributes]::ReparsePoint
        })
        if ($links.Count -gt 0) { throw 'Source folder contains a junction/symlink; import blocked.' }
    }
    if ($mode -eq '3') {
        $inputPath = (Read-Host 'Archive file path (0 cancels)').Trim()
        if ($inputPath -eq '0') { return }
        $source = ConvertTo-WorkspacePath $inputPath
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Archive not found.' }
        if ([IO.Path]::GetExtension($source).ToLowerInvariant() -notin @('.zip','.rar','.7z')) { throw 'Supported archives: ZIP, RAR, 7Z.' }
    }
    if ($source -and (Test-PathUnder $destination $source)) { throw 'Cannot import a parent folder into itself.' }
    $move = $false
    if ($source) {
        Write-Host '  1. Copy and preserve original [recommended]'
        Write-Host '  2. Move: delete original only after verified import'
        Write-Host '  0. Cancel'
        $transfer = (Read-Host 'Number [1]').Trim()
        if (-not $transfer) { $transfer = '1' }
        if ($transfer -eq '0') { return }
        if ($transfer -notin @('1','2')) { return }
        $move = ($transfer -eq '2')
        if ($move -and -not (Read-YesNo 'Confirm original deletion after verifying copied content?' $false)) { return }
    }
    Write-Host ('New workspace: ' + $destination) -ForegroundColor Cyan
    if (-not (Read-YesNo 'Create/import now?' $true)) { return }
    $stage = Join-Path $root ('.ps-import-' + [guid]::NewGuid().ToString('N'))
    try {
        if ($mode -ne '4') { New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null }
        if ($mode -eq '2') {
            foreach ($file in @(Get-ChildItem -LiteralPath $source -Force -ErrorAction Stop)) {
                Copy-Item -LiteralPath $file.FullName -Destination $stage -Recurse -Force -ErrorAction Stop
            }
            if ($move) { Assert-CopiedFolder $source $stage }
        }
        if ($mode -eq '3') {
            Expand-ToolArchive $source $stage
            $savedSource = Join-Path $stage '_source'
            New-Item -ItemType Directory -Path $savedSource -Force | Out-Null
            $copiedArchive = Join-Path $savedSource ([IO.Path]::GetFileName($source))
            Copy-Item -LiteralPath $source -Destination $copiedArchive -ErrorAction Stop
            if ($move -and (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $copiedArchive -Algorithm SHA256).Hash) {
                throw 'Archive checksum mismatch; original retained.'
            }
        }
        if ($mode -ne '4') { Move-Item -LiteralPath $stage -Destination $destination -ErrorAction Stop }
    }
    finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $item = [pscustomobject]@{ Id=[guid]::NewGuid().ToString('D'); Name=$name; Path=$destination; Launchable=''; Installer='' }
    $data.Workspaces = @($data.Workspaces) + @($item)
    Save-WorkspaceStore $data
    Write-Host ('Workspace ready: ' + $destination) -ForegroundColor Green
    if ($move) {
        try {
            if ($mode -eq '2') { Remove-Item -LiteralPath $source -Recurse -Force -ErrorAction Stop }
            else { Remove-Item -LiteralPath $source -Force -ErrorAction Stop }
            Write-Host 'Original source deleted after verification.' -ForegroundColor Green
        }
        catch { Write-Warning ('Original could not be deleted. Imported workspace is preserved: ' + $_.Exception.Message) }
    }
    if (Read-YesNo 'Save a main launchable now?' $true) { Save-WorkspaceTarget $item.Id 'launchable' }
    if (Read-YesNo 'Save installer path separately (not executed)?' $false) { Save-WorkspaceTarget $item.Id 'installer' }
    if (Read-YesNo 'Create a ProjectShell desktop shortcut?' $true) {
        $null = New-Profile @(Read-Store) $null $item.Path $item.Name $item.Id
    }
}

function Invoke-SavedTool([string]$Target, [string]$WorkingFolder) {
    if (-not $Target) { Write-Host 'No launchable saved. Select the set-launchable option.' -ForegroundColor Yellow; return }
    if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) { Write-Host ('File not found: ' + $Target) -ForegroundColor Yellow; return }
    $ext = [IO.Path]::GetExtension($Target).ToLowerInvariant()
    Write-Host ('Running: ' + $Target) -ForegroundColor Cyan
    Push-Location -LiteralPath $WorkingFolder
    try {
        switch ($ext) {
            '.ps1' { & $Target; break }
            '.exe' { & $Target; break }
            '.cmd' { & $Target; break }
            '.bat' { & $Target; break }
            '.py' {
                $runner = Get-Command py.exe -ErrorAction SilentlyContinue
                if (-not $runner) { $runner = Get-Command python.exe -ErrorAction Stop }
                & $runner.Source $Target; break
            }
            '.js' { $runner = Get-Command node.exe -ErrorAction Stop; & $runner.Source $Target; break }
            '.jar' { $runner = Get-Command java.exe -ErrorAction Stop; & $runner.Source '-jar' $Target; break }
            default { throw 'Unsupported launchable format; nothing was executed.' }
        }
    }
    finally { Pop-Location }
}

function Get-ProfileLaunchable($Profile) {
    if ($Profile.MainLaunchable) { return [string]$Profile.MainLaunchable }
    if ($Profile.WorkspaceId) {
        $matches = @((Read-WorkspaceStore).Workspaces | Where-Object { $_.Id -eq [string]$Profile.WorkspaceId })
        if ($matches.Count -eq 1) { return [string]$matches[0].Launchable }
    }
    return ''
}

function Set-ProfileLaunchable($Profile) {
    $value = Read-ToolTarget ([string]$Profile.StartDirectory) 'launchable' ([string]$Profile.MainLaunchable)
    if ($null -eq $value) { return }
    $profiles = @(Read-Store)
    foreach ($item in $profiles) {
        if ($item.Id -eq $Profile.Id) { $item | Add-Member -NotePropertyName MainLaunchable -NotePropertyValue $value -Force }
    }
    $Profile | Add-Member -NotePropertyName MainLaunchable -NotePropertyValue $value -Force
    Save-Store $profiles
    Write-Host 'Primary launchable saved for this shortcut.' -ForegroundColor Green
}

function Start-ProfileLaunchable($Profile) {
    if (-not [bool]$Profile.Admin -and (Test-IsAdmin)) {
        Write-Host 'A standard profile launch cannot run from an elevated session.' -ForegroundColor Yellow
        return
    }
    Invoke-SavedTool (Get-ProfileLaunchable $Profile) ([string]$Profile.StartDirectory)
}

function Show-WorkspaceToolsMenu {
    while ($true) {
        $data = Read-WorkspaceStore
        Write-Host ''
        Write-Host 'PROJECT SHELL | DEVTOOLS AND SAVED TOOL LOOKUPS' -ForegroundColor Cyan
        Write-Host ('Default root: ' + $(if ($data.DevToolsRoot) { $data.DevToolsRoot } else { '(not configured)' }))
        Write-Host ('Saved workspaces: ' + @($data.Workspaces).Count)
        Write-Host '  1. Set/change DevTools folder'
        Write-Host '  2. Create/import a workspace'
        Write-Host '  3. Inspect saved workspace'
        Write-Host '  4. Launch saved workspace tool'
        Write-Host '  5. Set workspace main launchable'
        Write-Host '  6. Save workspace installer location'
        Write-Host '  7. Make ProjectShell desktop shortcut'
        Write-Host '  8. Check archive dependencies / Catalogue preview'
        Write-Host '  0. Back'
        $choice = (Read-Host 'Number').Trim()
        try {
            switch ($choice) {
                '1' { $null = Set-DevToolsRoot }
                '2' { New-DevWorkspace }
                '3' {
                    $selected = Select-Workspace
                    if ($selected) {
                        Write-Host ('Folder: ' + $selected.Path)
                        Write-Host ('Launchable: ' + $(if ($selected.Launchable) { $selected.Launchable } else { '(not set)' }))
                        Write-Host ('Installer: ' + $(if ($selected.Installer) { $selected.Installer } else { '(not set)' }))
                    }
                }
                '4' {
                    $selected = Select-Workspace
                    if ($selected) { Invoke-SavedTool ([string]$selected.Launchable) ([string]$selected.Path) }
                }
                '5' {
                    $selected = Select-Workspace
                    if ($selected) { Save-WorkspaceTarget ([string]$selected.Id) 'launchable' }
                }
                '6' {
                    $selected = Select-Workspace
                    if ($selected) { Save-WorkspaceTarget ([string]$selected.Id) 'installer' }
                }
                '7' {
                    $selected = Select-Workspace
                    if ($selected) { $null = New-Profile @(Read-Store) $null ([string]$selected.Path) ([string]$selected.Name) ([string]$selected.Id) }
                }
                '8' { Show-ProjectShellCatalogueMenu }
                '0' { return }
                default { Write-Host 'Choose a listed number.' -ForegroundColor Yellow }
            }
        }
        catch { Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red }
    }
}
