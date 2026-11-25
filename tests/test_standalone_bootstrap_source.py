"""Regression gate for the standalone Setup EXE PowerShell bootstrap source.

The old builder appended a NUL byte after the script; Windows PowerShell 5.1
reported an empty command after a successful upgrade. This source test is not
a substitute for an interactive or automated standalone EXE runtime test.
"""
from __future__ import annotations

import ast
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "scripts" / "build-standalone-installer.py"


class StandaloneBootstrapSourceTests(unittest.TestCase):
    def test_no_terminal_nul_added_to_generated_bootstrap(self):
        source = BUILDER.read_text(encoding="utf-8")
        module = ast.parse(source)
        main = next(
            node for node in module.body
            if isinstance(node, ast.FunctionDef) and node.name == "main"
        )
        assignments = [
            node for node in ast.walk(main)
            if isinstance(node, ast.Assign)
            and any(isinstance(target, ast.Name) and target.id == "bootstrap"
                    for target in node.targets)
        ]
        self.assertEqual(len(assignments), 1)
        expr = assignments[0].value
        self.assertIsInstance(expr, ast.Call, "Bootstrap should be encoded directly")
        self.assertIsInstance(expr.func, ast.Attribute)
        self.assertEqual(expr.func.attr, "encode")
        self.assertEqual(expr.args[0].value, "ascii")

    def test_bootstrap_source_is_clean_ascii_with_final_newline(self):
        spec = importlib.util.spec_from_file_location("psh_builder", BUILDER)
        assert spec and spec.loader
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        data = builder.BOOTSTRAP.replace("__SHA__", "A" * 64).encode("ascii")
        self.assertNotIn(b"\x00", data)
        self.assertTrue(data.endswith(b"\n"))
        self.assertIn(b"Installer finished.", data)


if __name__ == "__main__":
    unittest.main()
