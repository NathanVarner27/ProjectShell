"""Read-only Windows acceptance for the current ProjectShell x64 installer ZIP.

The tested artifact is produced by the same CI run and source revision.
Checks ZIP integrity, exact contents, EXE PE structure and companion scripts.
Does NOT execute the installer, write user settings, or publish a release.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zipfile

REQUIRED = {
    "Install-ProjectShell.exe",
    "Install-ProjectShell.ps1",
    "ProjectShell.ps1",
    "ProjectShell.Workspaces.ps1",
    "Diagnose-Launch.ps1",
    "README.md",
    "SECURITY.md",
    "CODE_SIGNING_POLICY.md",
    "CHANGELOG.md",
    "LICENSE",
}

def main() -> None:
    if sys.platform != "win32":
        raise RuntimeError("Windows-only installer verification")
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    args = parser.parse_args()
    archive = args.zip.resolve(strict=True)
    source = args.source.resolve(strict=True)
    if not archive.is_file() or not source.is_dir():
        raise RuntimeError("Required ZIP or source folder missing")
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise RuntimeError("ZIP CRC verification failed")
        names = [i.filename for i in z.infolist()]
        if len(names) != len(set(names)) or set(names) != REQUIRED:
            raise RuntimeError("Unexpected or missing Windows installer contents: " + repr(names))
        if any(z.getinfo(name).file_size == 0 for name in REQUIRED):
            raise RuntimeError("Empty required package file")
        for name in REQUIRED - {"Install-ProjectShell.exe"}:
            upstream = source / name
            if not upstream.is_file():
                raise RuntimeError("Missing ProjectShell source file: " + name)
            # Windows Git can check out LICENSE with CRLF. Compare against the
            # committed Git blob, which is the exact source used by the Linux
            # cross-compiler to build this *Windows* x64 executable.
            blob = subprocess.run(
                ["git", "-C", str(source), "show", "HEAD:" + name],
                capture_output=True, timeout=20,
            )
            if blob.returncode or z.read(name) != blob.stdout:
                raise RuntimeError("ZIP companion file does not match committed source: " + name)
        exe = z.read("Install-ProjectShell.exe")
        if exe[:2] != b"MZ":
            raise RuntimeError("Windows EXE DOS signature missing")
        pe = struct.unpack_from("<I", exe, 0x3c)[0]
        if exe[pe:pe+4] != b"PE\x00\x00" or struct.unpack_from("<H", exe, pe+4)[0] != 0x8664:
            raise RuntimeError("Windows x64 PE signature/architecture invalid")
        for value in (b"requestedExecutionLevel", b"level='asInvoker'",
                      b"KERNEL32.dll", b"USER32.dll", b"CreateProcessW"):
            if value not in exe:
                raise RuntimeError("Installer missing required Windows PE attribute: " + repr(value))
        with tempfile.TemporaryDirectory(prefix="ProjectShell-Windows-Artifact-") as t:
            z.extractall(t)
            root = Path(t)
            if not all((root / name).is_file() for name in REQUIRED):
                raise RuntimeError("Extracted installer is incomplete")
            check = subprocess.run(
                [sys.executable, str(source / "scripts/check-installer-pe.py"),
                 str(root / "Install-ProjectShell.exe")],
                text=True, capture_output=True, timeout=30,
            )
            if check.returncode:
                raise RuntimeError("Native Windows PE check failed: " + check.stdout + check.stderr)
    print(json.dumps({
        "status": "WINDOWS_PROJECTSHELL_INSTALLER_ZIP_STRUCTURALLY_VERIFIED",
        "expected_source_commit": subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip(),
        "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "package_files": len(REQUIRED),
        "windows_x64_pe": True,
        "as_invoker": True,
        "companion_files_match_current_source": True,
        "interactive_installer_executed": False,
        "desktop_and_uac_tested": False,
        "published": False
    }, indent=2))

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("WINDOWS_INSTALLER_PACKAGE_FAILED: " + str(exc), file=sys.stderr)
        sys.exit(1)
