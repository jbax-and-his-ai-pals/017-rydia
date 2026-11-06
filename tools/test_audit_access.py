"""Top-level audit handling of the headless runner's exit status."""

import csv
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[1]
TOOLS = REPO / "tools"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location("audit_access", TOOLS / "audit_access.py")
audit_access = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit_access)


class AuditRunnerStatusTests(unittest.TestCase):
    def setUp(self):
        build = REPO / "build"
        build.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=build)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "build").mkdir()
        (self.root / "notes").mkdir()
        self.rom = self.root / "build" / "rydia.sfc"
        self.rom.write_bytes(b"test rom")
        self.out_dir = self.root / "audit"
        self.loc = {"world": "surface", "x": 0x12, "y": 0x34, "map": 5,
                    "name": "Quiet map", "event": b"\xFE\x01\x00\x00\x00\xFF"}

    def run_audit(self, runner_side_effect):
        with patch.object(audit_access, "ROOT", self.root), \
                patch.object(audit_access, "OUT_DIR", self.out_dir), \
                patch.object(audit_access, "Rom", return_value=object()), \
                patch.object(audit_access, "locations", return_value=[self.loc]), \
                patch.object(audit_access.subprocess, "run", side_effect=runner_side_effect), \
                patch.object(sys, "argv", [str(TOOLS / "audit_access.py")]):
            return audit_access.main()

    def read_row(self):
        with (self.root / "notes" / "access.csv").open(newline="", encoding="utf-8") as f:
            return next(csv.DictReader(f))

    def test_nonzero_runner_fails_even_with_quiet_result(self):
        def launch(cmd, **kwargs):
            out = Path(cmd[3])
            out.mkdir(parents=True, exist_ok=True)
            (out / "result.txt").write_text("map=01:0000 end=01:0000 party=01\n", encoding="utf-8")
            return SimpleNamespace(returncode=9)

        with self.assertRaises(SystemExit) as raised:
            self.run_audit(launch)
        self.assertIn("incomplete", str(raised.exception))
        row = self.read_row()
        self.assertEqual(row["status"], "runner failed")
        self.assertIn("runner exit 9", row["details"])

    def test_failed_runner_with_empty_or_missing_result_writes_failure_row(self):
        for result_kind in ("empty", "missing"):
            with self.subTest(result_kind=result_kind):
                self.out_dir = self.root / f"audit-{result_kind}"

                def launch(cmd, **kwargs):
                    out = Path(cmd[3])
                    out.mkdir(parents=True, exist_ok=True)
                    if result_kind == "empty":
                        (out / "result.txt").write_text("", encoding="utf-8")
                    return SimpleNamespace(returncode=3)

                with self.assertRaises(SystemExit):
                    self.run_audit(launch)
                row = self.read_row()
                self.assertEqual(row["status"], "runner failed")
                self.assertEqual(row["start"], "(no result)")
                self.assertIn("runner exit 3", row["details"])

    def test_successful_quiet_result_passes(self):
        def launch(cmd, **kwargs):
            out = Path(cmd[3])
            out.mkdir(parents=True, exist_ok=True)
            (out / "result.txt").write_text("map=01:0000 end=01:0000 party=01\n", encoding="utf-8")
            return SimpleNamespace(returncode=0)

        self.assertIsNone(self.run_audit(launch))
        row = self.read_row()
        self.assertEqual(row["status"], "quiet")
        self.assertEqual(row["details"], "")


if __name__ == "__main__":
    unittest.main()
