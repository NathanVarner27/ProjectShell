#!/usr/bin/env bash
# Build only the experimental Manager EXE; never invoke the installer.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for tool in clang-cl lld-link python3; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 2; }; done
lld-link /lib /def:"$ROOT/native/kernel32.def" /machine:x64 /out:"$BUILD/kernel32.lib"
lld-link /lib /def:"$ROOT/native/user32.def" /machine:x64 /out:"$BUILD/user32.lib"
clang-cl --target=x86_64-pc-windows-msvc /nologo /O2 /GS- /Zl /clang:-fno-builtin /c \
  "/Fo$BUILD/ManagerLauncher.obj" "$ROOT/native/ManagerLauncher.c"
lld-link /nologo /nodefaultlib /machine:x64 /subsystem:windows \
  /entry:ManagerEntry /manifest:embed \
  "/manifestuac:level='asInvoker' uiAccess='false'" \
  /out:"$ROOT/ProjectShell-Manager.exe" "$BUILD/ManagerLauncher.obj" \
  "$BUILD/kernel32.lib" "$BUILD/user32.lib"
python3 "$ROOT/scripts/check-installer-pe.py" "$ROOT/ProjectShell-Manager.exe"
printf 'Built %s\n' "$ROOT/ProjectShell-Manager.exe"
