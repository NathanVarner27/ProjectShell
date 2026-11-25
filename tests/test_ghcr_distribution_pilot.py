"""Offline validation of GHCR pilot staging, including rejection of unsafe inputs."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "ghcr_pilot", ROOT / "scripts" / "prepare-ghcr-pilot.py"
)
assert spec is not None and spec.loader is not None
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class PilotStagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.installer = self.root / "installer"
        self.msix = self.root / "msix"
        self.installer.mkdir()
        self.msix.mkdir()
        self.output = self.root / "out"
        self.commit = "a" * 40

        data = bytearray(256)
        data[:2] = b"MZ"
        struct.pack_into("<I", data, 0x3C, 128)
        data[128:132] = b"PE\x00\x00"
        struct.pack_into("<H", data, 132, 0x8664)
        (self.installer / pilot.EXE_NAME).write_bytes(data)

        with zipfile.ZipFile(self.installer / pilot.ZIP_NAME, "w") as z:
            for name in pilot.REQUIRED_ZIP_FILES:
                z.writestr(name, "test fixture")

        with (self.installer / pilot.SUM_NAME).open("w") as f:
            for name in (pilot.EXE_NAME, pilot.ZIP_NAME):
                f.write(f"{digest(self.installer / name)}  {name}\n")

        with zipfile.ZipFile(self.msix / pilot.MSIX_NAME, "w") as z:
            z.writestr("AppxManifest.xml", "<Identity Name='ProjectShell.CI.Preview'/>")
            z.writestr("ProjectShell-Manager.exe", "fixture")

        receipt = {
            "status": "CI_MSIX_STRUCTURAL_VERIFIED",
            "signed": False,
            "installed": False,
            "runtime_msix_verified": False,
            "store_ready": False,
            "published": False,
            "source_derived": True,
            "identity": "ProjectShell.CI.Preview",
            "sha256": digest(self.msix / pilot.MSIX_NAME),
        }
        (self.msix / pilot.MSIX_RECEIPT).write_text(json.dumps(receipt))

    def do_stage(self):
        return pilot.stage(self.installer, self.msix, self.output, self.commit)

    def test_valid_test_only_payload(self):
        metadata = self.do_stage()
        self.assertEqual(len(metadata["files"]), 5)
        self.assertTrue(metadata["test_only"])
        self.assertFalse(metadata["msix_store_ready"])
        self.assertFalse(metadata["msix_signed"])
        self.assertEqual(metadata["source_commit"], self.commit)
        self.assertTrue((self.output / pilot.METADATA_NAME).is_file())

    def test_reject_checksum_tampering(self):
        (self.installer / pilot.EXE_NAME).write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
            self.do_stage()
        self.assertFalse(self.output.exists())

    def test_reject_signed_or_misrepresented_msix(self):
        path = self.msix / pilot.MSIX_RECEIPT
        receipt = json.loads(path.read_text())
        receipt["store_ready"] = True
        path.write_text(json.dumps(receipt))
        with self.assertRaisesRegex(ValueError, "store_ready"):
            self.do_stage()
        self.assertFalse(self.output.exists())

    def test_reject_wrong_msix_digest(self):
        with zipfile.ZipFile(self.msix / pilot.MSIX_NAME, "a") as z:
            z.writestr("tampered.txt", "unexpected")
        with self.assertRaisesRegex(ValueError, "structural receipt"):
            self.do_stage()
        self.assertFalse(self.output.exists())

    def test_refuses_existing_destination(self):
        self.output.mkdir()
        with self.assertRaises(FileExistsError):
            self.do_stage()


if __name__ == "__main__":
    unittest.main()
