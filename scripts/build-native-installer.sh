#!/usr/bin/env bash
# Reproducible cross-build for the Windows x64 installer launcher.
# Requires clang-cl and lld-link (LLVM). No Windows SDK or .NET SDK needed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/native"
OUT="$ROOT/Install-ProjectShell.exe"
BUILD="${TMPDIR:-/tmp}/projectshell-installer-build"
mkdir -p "$BUILD"

lld-link /lib /def:"$SRC/kernel32.def" /machine:x64 /out:"$BUILD/kernel32.lib"
lld-link /lib /def:"$SRC/user32.def" /machine:x64 /out:"$BUILD/user32.lib"
clang-cl --target=x86_64-pc-windows-msvc /nologo /O2 /GS- /Zl /clang:-fno-builtin /c \
    "/Fo$BUILD/InstallLauncher.obj" "$SRC/InstallLauncher.c"
lld-link /nologo /nodefaultlib /machine:x64 /subsystem:windows \
    /entry:InstallEntry /manifest:embed \
    "/manifestuac:level='asInvoker' uiAccess='false'" \
    /out:"$OUT" "$BUILD/InstallLauncher.obj" \
    "$BUILD/kernel32.lib" "$BUILD/user32.lib"
python3 "$ROOT/scripts/check-installer-pe.py" "$OUT"
printf 'Created %s\n' "$OUT"
