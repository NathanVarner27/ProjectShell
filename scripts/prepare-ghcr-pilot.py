#!/usr/bin/env python3
"""Validate and stage ProjectShell distribution files for an OCI/GHCR pilot.

This is a publication transport test, NOT MSIX installation or Store acceptance.
Input artifacts must come from successful CI runs on one reviewed source commit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import struct
import zipfile
from pathlib import Path

ZIP_NAME = "ProjectShell-v1.2.0-Windows-x64.zip"
EXE_NAME = "ProjectShell-v1.2.0-Windows-x64-Setup.exe"
SUM_NAME = "SHA256SUMS.txt"
MSIX_NAME = "ProjectShell-v1.2.0-CI-UNSIGNED-STRUCTURAL-ONLY.msix"
MSIX_RECEIPT = "ci-msix-acceptance.json"
METADATA_NAME = "distribution-metadata.json"
EXPECTED = {ZIP_NAME, EXE_NAME}
REQUIRED_ZIP_FILES = {
    "Install-ProjectShell.ps1", "Install-ProjectShell.exe", "ProjectShell.ps1",
    "ProjectShell.Workspaces.ps1", "ProjectShell.Catalogue.ps1",
    "ProjectShell.Migration.ps1", "Diagnose-Launch.ps1",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def verify_pe(path: Path) -> None:
    data = path.read_bytes()
    if len(data) < 0x48 or data[:2] != b"MZ":
        raise ValueError("Setup EXE missing DOS header")
    offset = struct.unpack_from("<I", data, 0x3C)[0]
    if offset + 6 > len(data) or data[offset:offset + 4] != b"PE\x00\x00":
        raise ValueError("Setup EXE missing valid PE signature")
    if struct.unpack_from("<H", data, offset + 4)[0] != 0x8664:
        raise ValueError("Setup EXE is not x64")


def check_checksums(path: Path, base: Path) -> None:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r"([a-fA-F0-9]{64})\s+\*?([^\r\n]+)", line)
        if match is None:
            raise ValueError("Malformed SHA256SUMS entry")
        name = match.group(2).strip()
        if name not in EXPECTED or name in entries:
            raise ValueError(f"Unexpected or duplicate checksum: {name}")
        entries[name] = match.group(1).upper()
    if set(entries) != EXPECTED:
        raise ValueError("Missing expected checksums")
    for name, digest in entries.items():
        if sha256(base / name) != digest:
            raise ValueError(f"Checksum mismatch: {name}")


def verify_msix(msix: Path, receipt_path: Path) -> dict:
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    for key, expected in {
        "status": "CI_MSIX_STRUCTURAL_VERIFIED",
        "signed": False, "installed": False, "runtime_msix_verified": False,
        "store_ready": False, "published": False, "source_derived": True,
        "identity": "ProjectShell.CI.Preview",
    }.items():
        if receipt.get(key) != expected:
            raise ValueError(f"Unexpected MSIX structural receipt: {key}")
    if receipt.get("sha256", "").upper() != sha256(msix):
        raise ValueError("MSIX does not match CI structural receipt")
    with zipfile.ZipFile(msix) as z:
        if z.testzip() is not None:
            raise ValueError("MSIX archive CRC mismatch")
        names = set(z.namelist())
        if "AppxManifest.xml" not in names or "ProjectShell-Manager.exe" not in names:
            raise ValueError("MSIX preview files missing")
        if "AppxSignature.p7x" in names:
            raise ValueError("Expected an unsigned MSIX structural preview")
        manifest = z.read("AppxManifest.xml")
        if b"ProjectShell.CI.Preview" not in manifest:
            raise ValueError("Unexpected MSIX preview identity")
    return receipt


def stage(installer_dir: Path, msix_dir: Path, output: Path, source_sha: str) -> dict:
    if not re.fullmatch(r"[a-fA-F0-9]{40}", source_sha):
        raise ValueError("source_sha must be a full 40-character Git commit SHA")
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite output folder: {output}")
    for name in (ZIP_NAME, EXE_NAME, SUM_NAME):
        if not (installer_dir / name).is_file():
            raise FileNotFoundError(installer_dir / name)
    for name in (MSIX_NAME, MSIX_RECEIPT):
        if not (msix_dir / name).is_file():
            raise FileNotFoundError(msix_dir / name)

    check_checksums(installer_dir / SUM_NAME, installer_dir)
    verify_pe(installer_dir / EXE_NAME)
    with zipfile.ZipFile(installer_dir / ZIP_NAME) as z:
        if z.testzip() is not None:
            raise ValueError("Release ZIP archive CRC mismatch")
        if not REQUIRED_ZIP_FILES.issubset(set(z.namelist())):
            raise ValueError("Release ZIP missing ProjectShell components")
    verify_msix(msix_dir / MSIX_NAME, msix_dir / MSIX_RECEIPT)

    output.mkdir(parents=True)
    try:
        for name in (ZIP_NAME, EXE_NAME, SUM_NAME):
            shutil.copy2(installer_dir / name, output / name)
        for name in (MSIX_NAME, MSIX_RECEIPT):
            shutil.copy2(msix_dir / name, output / name)
        metadata = {
            "schema": 1,
            "project": "ProjectShell",
            "purpose": "DBP end-to-end registry transport and distribution acceptance",
            "source_commit": source_sha.lower(),
            "github_packages_kind": "GHCR OCI non-container artifact",
            "not_a_runnable_docker_image": True,
            "test_only": True,
            "setup_exe_runtime_warning": "v1.2.0 standalone bootstrap has not passed clean-exit retesting",
            "msix_kind": "UNSIGNED_CI_STRUCTURAL_ONLY",
            "msix_signed": False,
            "msix_installed": False,
            "msix_store_ready": False,
            "not_a_public_stable_release": True,
            "files": {name: sha256(output / name) for name in
                      (ZIP_NAME, EXE_NAME, SUM_NAME, MSIX_NAME, MSIX_RECEIPT)},
        }
        (output / METADATA_NAME).write_text(
            json.dumps(metadata, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        return metadata
    except Exception:
        shutil.rmtree(output)
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--installer-dir", type=Path, required=True)
    parser.add_argument("--msix-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    meta = stage(args.installer_dir, args.msix_dir, args.out, args.source_sha)
    print("PASS: DBP ProjectShell GHCR pilot payload verified")
    print("Source:", meta["source_commit"])
    print("Files:", len(meta["files"]))
    print("Unsigned MSIX structural only; no installation or Store submission.")


if __name__ == "__main__":
    main()
