"""Read-only source gates; no PowerShell or install invocation."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parent.parent
SRC=(ROOT/'native'/'ManagerLauncher.c').read_text(encoding='ascii')
INSTALLER=(ROOT/'native'/'InstallLauncher.c').read_text(encoding='utf-8')
class ManagerLauncherSourceTests(unittest.TestCase):
    def test_manager_has_separate_entrypoint(self):
        self.assertIn('void WINAPI ManagerEntry(void)',SRC)
        self.assertIn('void WINAPI InstallEntry(void)', INSTALLER)
    def test_manager_loads_adjacent_script(self):
        self.assertIn('L"ProjectShell.ps1"',SRC)
        self.assertNotIn('Install-ProjectShell.ps1',SRC)
    def test_manager_no_guided_installer(self):
        self.assertNotIn('-Guided',SRC)
    def test_standard_user(self):
        self.assertIn("/manifestuac:level='asInvoker'", (ROOT/'scripts'/'build-manager-launcher.sh').read_text())
    def test_console_and_exit_code(self):
        self.assertIn('CREATE_NEW_CONSOLE',SRC)
        self.assertIn('GetExitCodeProcess',SRC)
    def test_manager_exits_with_child_shell(self):
        self.assertNotIn('-NoExit',SRC)
        self.assertIn('-NoLogo -NoProfile',SRC)
    def test_packaging_gate_not_claimed(self):
        self.assertFalse((ROOT/'AppxManifest.xml').exists())
        self.assertTrue((ROOT/'ProjectShell.ps1').exists())
if __name__=='__main__':unittest.main()
