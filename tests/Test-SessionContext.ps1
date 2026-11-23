# Test only the process-local ProjectShell starting-folder handoff, not UI/install.
$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ProjectShell.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath, [ref]$tokens, [ref]$errors
)
if ($errors.Count -ne 0) { throw 'Cannot parse ProjectShell source.' }
$fn = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Set-ProjectShellLaunchContext'
}, $true)
if (-not $fn) { throw 'ProjectShell session-context function is absent.' }

# Import only this one function, avoiding loading profiles or invoking the manager.
. ([scriptblock]::Create($fn.Extent.Text))
$key = 'PROJECTSHELL_START_DIRECTORY'
$before = [Environment]::GetEnvironmentVariable($key, 'Process')
$userBefore = [Environment]::GetEnvironmentVariable($key, 'User')
$machineBefore = [Environment]::GetEnvironmentVariable($key, 'Machine')

try {
    $target = Split-Path -Parent $PSScriptRoot
    Set-ProjectShellLaunchContext ([pscustomobject]@{ StartDirectory = $target })
    $actual = [Environment]::GetEnvironmentVariable($key, 'Process')
    if ([IO.Path]::GetFullPath($actual).TrimEnd('\') -ne [IO.Path]::GetFullPath($target).TrimEnd('\')) {
        throw 'Process-local starting-folder handoff does not match the saved profile.'
    }
    $nonexistent = Join-Path $target ('No-Such-ProjectShell-Folder-' + [guid]::NewGuid().ToString('N'))
    try {
        Set-ProjectShellLaunchContext ([pscustomobject]@{ StartDirectory = $nonexistent })
        throw 'Invalid starting folder did not fail closed.'
    }
    catch {
        if ($_.Exception.Message -match 'Invalid starting folder did not fail closed') { throw }
    }
    if ([Environment]::GetEnvironmentVariable($key, 'Process') -ne $actual) {
        throw 'Invalid folder unexpectedly changed the existing process context.'
    }
    if ([Environment]::GetEnvironmentVariable($key, 'User') -ne $userBefore -or
        [Environment]::GetEnvironmentVariable($key, 'Machine') -ne $machineBefore) {
        throw 'Profile handoff wrote persistent User/Machine environment variables.'
    }
    Write-Host 'PROJECTSHELL_PROCESS_STARTDIRECTORY_HANDOFF_PASSED' -ForegroundColor Green
}
finally {
    [Environment]::SetEnvironmentVariable($key, $before, 'Process')
}
