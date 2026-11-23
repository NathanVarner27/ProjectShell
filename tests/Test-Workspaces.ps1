# Windows-only functional smoke checks for the local workspace module.
# Uses temporary directories; does not touch the user's DevTools root, shortcuts or profiles.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent
$temp = Join-Path $env:TEMP ('ProjectShell-Workspace-Test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null

function Assert([bool]$Condition, [string]$Description) {
    if (-not $Condition) { throw ('FAIL: ' + $Description) }
    Write-Host ('PASS: ' + $Description) -ForegroundColor Green
}

try {
    $script:AppRoot = Join-Path $temp 'AppData'
    $script:ProgramPath = Join-Path $temp 'ProjectShell.ps1'
    $script:AnswerQueue = New-Object 'System.Collections.Generic.Queue[string]'
    $script:ConfirmQueue = New-Object 'System.Collections.Generic.Queue[bool]'
    $script:ChosenFolder = ''

    function Ensure-Store { New-Item -ItemType Directory -Path $script:AppRoot -Force | Out-Null }
    function Read-Host {
        param([string]$Prompt)
        if ($script:AnswerQueue.Count -eq 0) { throw ('Unexpected Read-Host prompt: ' + $Prompt) }
        return $script:AnswerQueue.Dequeue()
    }
    function Read-YesNo {
        param([string]$Question, [bool]$Default=$false)
        if ($script:ConfirmQueue.Count -eq 0) { throw ('Unexpected confirmation prompt: ' + $Question) }
        return $script:ConfirmQueue.Dequeue()
    }
    function Read-Folder { return $script:ChosenFolder }
    function New-Profile { throw 'Unexpected desktop shortcut creation in test.' }
    function Queue-Inputs([string[]]$Answers, [bool[]]$Confirms) {
        $script:AnswerQueue.Clear()
        $script:ConfirmQueue.Clear()
        foreach ($answer in $Answers) { $script:AnswerQueue.Enqueue($answer) }
        foreach ($confirmation in $Confirms) { $script:ConfirmQueue.Enqueue($confirmation) }
    }
    function Assert-QueuesEmpty {
        Assert ($script:AnswerQueue.Count -eq 0 -and $script:ConfirmQueue.Count -eq 0) 'Expected only the documented wizard prompts'
    }

    . (Join-Path $root 'ProjectShell.Workspaces.ps1')
    $devRoot = Join-Path $temp 'DevTools'
    New-Item -ItemType Directory -Path $devRoot -Force | Out-Null
    Save-WorkspaceStore ([pscustomobject]@{ Version=1; DevToolsRoot=$devRoot; Workspaces=@() })
    Assert ((Read-WorkspaceStore).DevToolsRoot -eq $devRoot) 'DevTools root persisted independently'
    Assert (Test-PathUnder (Join-Path $devRoot 'Child') $devRoot) 'Workspace containment check'
    Assert (-not (Test-PathUnder $temp (Join-Path $devRoot 'Child'))) 'Workspace containment rejects parent'

    Queue-Inputs @('BlankProject','1') @($true,$false,$false,$false)
    New-DevWorkspace
    Assert (Test-Path -LiteralPath (Join-Path $devRoot 'BlankProject') -PathType Container) 'Empty workspace created'
    Assert-QueuesEmpty

    $already = Join-Path $devRoot 'ExistingProject'
    New-Item -ItemType Directory -Path $already -Force | Out-Null
    Queue-Inputs @('ExistingProject','4') @($true,$false,$false,$false)
    New-DevWorkspace
    Assert (@((Read-WorkspaceStore).Workspaces | Where-Object { $_.Name -eq 'ExistingProject' }).Count -eq 1) 'Existing workspace registered without moving data'
    Assert-QueuesEmpty

    $source = Join-Path $temp 'SourceFolder'
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'run.ps1') -Value "Write-Host 'hello'" -Encoding UTF8
    $script:ChosenFolder = $source
    Queue-Inputs @('CopiedProject','2','1') @($true,$false,$false,$false)
    New-DevWorkspace
    Assert (Test-Path -LiteralPath $source -PathType Container) 'Copy leaves original folder untouched'
    Assert (Test-Path -LiteralPath (Join-Path $devRoot 'CopiedProject\run.ps1') -PathType Leaf) 'Folder content copied'
    Assert-QueuesEmpty

    $moveSource = Join-Path $temp 'MoveSource'
    New-Item -ItemType Directory -Path $moveSource -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $moveSource 'main.py') -Value "print('ok')" -Encoding UTF8
    $script:ChosenFolder = $moveSource
    Queue-Inputs @('MovedProject','2','2') @($true,$true,$false,$false,$false)
    New-DevWorkspace
    Assert (-not (Test-Path -LiteralPath $moveSource)) 'Verified move deletes original only after confirmation'
    Assert (Test-Path -LiteralPath (Join-Path $devRoot 'MovedProject\main.py') -PathType Leaf) 'Moved workspace preserves files'
    Assert-QueuesEmpty

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archiveSource = Join-Path $temp 'ArchiveInput'
    New-Item -ItemType Directory -Path $archiveSource -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $archiveSource 'Start-App.ps1') -Value "Write-Host 'from ZIP'" -Encoding UTF8
    $zip = Join-Path $temp 'demo.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($archiveSource,$zip)
    Queue-Inputs @('ZipProject','3',$zip,'1') @($true,$false,$false,$false)
    New-DevWorkspace
    Assert (Test-Path -LiteralPath (Join-Path $devRoot 'ZipProject\Start-App.ps1') -PathType Leaf) 'ZIP content extracted'
    Assert (Test-Path -LiteralPath (Join-Path $devRoot 'ZipProject\_source\demo.zip') -PathType Leaf) 'Original archive copied into _source'
    Assert (Test-Path -LiteralPath $zip -PathType Leaf) 'ZIP copy leaves original archive'
    Assert-QueuesEmpty

    $badZip = Join-Path $temp 'bad.zip'
    $badArchive = [IO.Compression.ZipFile]::Open($badZip,[IO.Compression.ZipArchiveMode]::Create)
    try { $null = $badArchive.CreateEntry('../outside.txt') }
    finally { $badArchive.Dispose() }
    $badDest = Join-Path $temp 'BadExtract'
    New-Item -ItemType Directory -Path $badDest | Out-Null
    $rejected = $false
    try { Expand-ToolArchive $badZip $badDest }
    catch { $rejected = $true }
    Assert $rejected 'ZIP parent-directory traversal rejected'
    Assert (-not (Test-Path -LiteralPath (Join-Path $temp 'outside.txt'))) 'ZIP traversal created no outside file'

    $saved = @((Read-WorkspaceStore).Workspaces | Where-Object { $_.Name -eq 'CopiedProject' })[0]
    $saved.Launchable = Join-Path $saved.Path 'run.ps1'
    $data = Read-WorkspaceStore
    $record = @($data.Workspaces | Where-Object { $_.Id -eq $saved.Id })[0]
    $record.Launchable = $saved.Launchable
    Save-WorkspaceStore $data
    $profile = [pscustomobject]@{ WorkspaceId=$saved.Id; MainLaunchable='' }
    Assert ((Get-ProfileLaunchable $profile) -eq $saved.Launchable) 'Linked shortcut resolves current workspace launchable'
    $profile.MainLaunchable = 'C:\Custom\override.ps1'
    Assert ((Get-ProfileLaunchable $profile) -eq $profile.MainLaunchable) 'Per-shortcut launchable overrides workspace default'

    Write-Host 'Workspace functional checks completed.' -ForegroundColor Cyan
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
