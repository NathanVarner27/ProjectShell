[CmdletBinding()]
param([switch]$ApproveBuild)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $root 'native\ManagerLauncher.c'
$installer = Join-Path $root 'native\InstallLauncher.c'
$manager = Join-Path $root 'ProjectShell.ps1'
foreach ($path in @($source,$installer,$manager)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing: $path" }
}
$native = Get-Content -LiteralPath $source -Raw
if (!$native.Contains('ProjectShell.ps1') -or $native.Contains('Install-ProjectShell.ps1')) {
    throw 'The manager launcher must target ProjectShell.ps1, not the installer.'
}
Write-Host 'PASS: Separate native manager entrypoint source' -ForegroundColor Green
Write-Host 'PASS: Existing traditional installer source preserved' -ForegroundColor Green
$clang = Get-Command clang-cl.exe -ErrorAction SilentlyContinue
$lld = Get-Command lld-link.exe -ErrorAction SilentlyContinue
if (!$clang -or !$lld) {
    $llvm = Join-Path $env:ProgramFiles 'LLVM\bin'
    if (!$clang -and (Test-Path -LiteralPath (Join-Path $llvm 'clang-cl.exe'))) {
        $clang = [pscustomobject]@{ Source = (Join-Path $llvm 'clang-cl.exe') }
    }
    if (!$lld -and (Test-Path -LiteralPath (Join-Path $llvm 'lld-link.exe'))) {
        $lld = [pscustomobject]@{ Source = (Join-Path $llvm 'lld-link.exe') }
    }
}
if (!$clang -or !$lld) {
    Write-Host 'LLVM clang-cl/lld-link not found. Review installation through Nathan''s Catalogue.' -ForegroundColor Yellow
    if ($ApproveBuild) { throw 'Compiler toolchain missing; no build attempted.' }
    Write-Host 'Source preview passed; binary build unavailable on this machine.'
    return
}
Write-Host "Compiler: $($clang.Source)"
Write-Host "Linker: $($lld.Source)"
if (!$ApproveBuild) {
    Write-Host 'Preview passed. Rerun with -ApproveBuild to compile experimental manager.'
    return
}
$work = Join-Path $env:TEMP ('ProjectShell-ManagerBuild-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $kernel = Join-Path $work 'kernel32.lib'
    $user = Join-Path $work 'user32.lib'
    $obj = Join-Path $work 'ManagerLauncher.obj'
    $out = Join-Path $root 'ProjectShell-Manager.exe'
    if (Test-Path -LiteralPath $out) { throw 'Refusing to overwrite existing manager EXE.' }
    & $lld.Source '/lib' "/def:$(Join-Path $root 'native\kernel32.def')" '/machine:x64' "/out:$kernel"
    if ($LASTEXITCODE -ne 0) { throw 'kernel32 import library failed.' }
    & $lld.Source '/lib' "/def:$(Join-Path $root 'native\user32.def')" '/machine:x64' "/out:$user"
    if ($LASTEXITCODE -ne 0) { throw 'user32 import library failed.' }
    & $clang.Source '--target=x86_64-pc-windows-msvc' '/nologo' '/O2' '/GS-' '/Zl' '/clang:-fno-builtin' '/c' "/Fo$obj" $source
    if ($LASTEXITCODE -ne 0) { throw 'Manager C compilation failed.' }
    & $lld.Source '/nologo' '/nodefaultlib' '/machine:x64' '/subsystem:windows' '/entry:ManagerEntry' '/manifest:embed' "/manifestuac:level='asInvoker' uiAccess='false'" "/out:$out" $obj $kernel $user
    if ($LASTEXITCODE -ne 0) { throw 'Manager executable link failed.' }
    & py -3 (Join-Path $root 'scripts\check-installer-pe.py') $out
    if ($LASTEXITCODE -ne 0) { throw 'Manager PE validation failed.' }
    Write-Host "BUILT: $out" -ForegroundColor Green
    Write-Host 'NOT installed, signed or packaged as MSIX.'
}
finally { Remove-Item -LiteralPath $work -Force -Recurse -ErrorAction SilentlyContinue }
