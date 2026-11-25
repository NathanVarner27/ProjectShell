"""Safe source/manifest gates for nonpublishing MSIX preview."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SOURCE=Path(__file__).resolve().parent.parent
SPEC=importlib.util.spec_from_file_location('msix_preview_ci', SOURCE/'scripts/msix_preview_ci.py')
mod=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

class TestMsixPreview(unittest.TestCase):
    def test_manifest_well_formed(self):
        mod.check_manifest(mod.manifest())
    def test_preview_identity(self):
        self.assertEqual(mod.NAME, 'ProjectShell.CI.Preview')
        self.assertNotIn('OID.2.25.', mod.PUBLISHER)
    def test_direct_manager_entry(self):
        m=mod.manifest().decode()
        self.assertIn('Executable="ProjectShell-Manager.exe"',m)
        self.assertNotIn('Install-ProjectShell.exe',m)
    def test_full_trust(self):
        m=mod.manifest().decode()
        self.assertIn('runFullTrust',m)
        self.assertIn('packagedClassicApp',m)
        self.assertIn('mediumIL',m)
    def test_missing_full_trust_rejected(self):
        with self.assertRaises(ValueError):
            mod.check_manifest(mod.manifest().replace(b'runFullTrust',b'runNoTrust'))
    def test_installer_entry_rejected(self):
        with self.assertRaises(ValueError):
            mod.check_manifest(mod.manifest().replace(b'Executable="ProjectShell-Manager.exe"',b'Executable="Install-ProjectShell.exe"'))
    def test_assets_exist(self):
        for n in mod.LOGOS:
            self.assertGreater((mod.ASSETS/n).stat().st_size,100)
    def test_refuse_overwrite_stage(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises((FileNotFoundError, ValueError, FileExistsError)):
                mod.stage(Path(d),Path(d)/'missing.exe',Path(d)/'stage')
    def test_no_publication_code(self):
        workflow=(SOURCE/'.github/workflows/manager-msix-preview.yml').read_text()
        self.assertIn('contents: read',workflow)
        self.assertNotIn('packages: write',workflow)
        self.assertNotIn('gh release create',workflow)
        self.assertNotIn('Add-AppxPackage',workflow)
        self.assertNotIn('workflow_release',workflow)

if __name__=='__main__': unittest.main()
