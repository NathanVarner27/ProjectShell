"""Structural safety gates for a no-write GHCR existing-artifact recovery workflow."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "ghcr-existing-readback.yml"


class ReadOnlyGHCRWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WORKFLOW.read_text(encoding="utf-8")

    def test_only_manual_event_can_use_registry(self):
        self.assertIn("workflow_dispatch:", self.text)
        self.assertIn("if: github.event_name == 'workflow_dispatch'", self.text)

    def test_registry_write_operations_not_permitted(self):
        self.assertIn("packages: read", self.text)
        self.assertNotIn("packages: write", self.text)
        # Keep this audit absolutely separate from publication and mutation.
        for forbidden in (
            "oras push ", "oras tag ", "oras manifest delete",
            "gh release create ", "gh release edit ",
            "docker push ", "gh api --method POST",
        ):
            self.assertNotIn(forbidden, self.text)

    def test_requires_exact_manifest_and_source(self):
        for required in (
            "source_sha:", "expected_digest:", "package_tag:",
            "installer_run_id:", "msix_run_id:",
            "oras resolve", "oras pull", 'cmp "dist/pilot/$file"',
            '[[ "$resolved" != "$EXPECTED_DIGEST" ]]',
        ):
            self.assertIn(required, self.text)

    def test_rechecks_github_attestation_and_msix_receipt(self):
        self.assertIn("gh attestation verify", self.text)
        self.assertIn("prepare-ghcr-pilot.py", self.text)
        self.assertIn("CI-MSIX-STRUCTURAL-ONLY", self.text)


if __name__ == "__main__":
    unittest.main()
