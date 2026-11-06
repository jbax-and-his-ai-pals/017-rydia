"""Runner completion-contract tests that do not require Mesen."""

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


RUN_PATH = Path(__file__).with_name("run.py")
SPEC = importlib.util.spec_from_file_location("mesen_run", RUN_PATH)
mesen_run = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mesen_run)


class RunnerContractTests(unittest.TestCase):
    def setUp(self):
        # The managed Windows runner restricts writes under the system temp
        # directory, so keep test fixtures inside the writable repository.
        self.temp = tempfile.TemporaryDirectory(dir=RUN_PATH.parents[2])
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.rom = self.root / "fixture.sfc"
        self.rom.write_bytes(b"test rom")
        self.out = self.root / "out"
        self.out.mkdir()

    def run_main(self, side_effect):
        argv = [str(RUN_PATH), "probe.lua", str(self.out), "--rom", str(self.rom), "--timeout", "3"]
        with patch.object(sys, "argv", argv), patch.object(mesen_run, "MESEN", "mesen-test"), \
                patch.object(mesen_run.subprocess, "run", side_effect=side_effect):
            return mesen_run.main()

    def test_exit_zero_without_completion_marker_fails(self):
        result = self.run_main(lambda *args, **kwargs: SimpleNamespace(returncode=0))
        self.assertEqual(result, 1)

    def test_stale_passed_status_log_and_result_are_removed_before_launch(self):
        for name, content in (("harness-status.txt", "passed\n"), ("log.txt", "stale log"),
                              ("result.txt", "stale result")):
            (self.out / name).write_text(content, encoding="ascii")

        def launch(cmd, env, timeout):
            self.assertEqual(timeout, 3)
            for name in ("harness-status.txt", "log.txt", "result.txt"):
                self.assertFalse((self.out / name).exists(), name)
            return SimpleNamespace(returncode=0)

        self.assertEqual(self.run_main(launch), 1)

    def test_fresh_pass_marker_and_exit_zero_pass(self):
        def launch(cmd, env, timeout):
            (self.out / "harness-status.txt").write_text("passed\n", encoding="ascii")
            return SimpleNamespace(returncode=0)

        self.assertEqual(self.run_main(launch), 0)

    def test_nonzero_emulator_exit_is_not_hidden_by_pass_marker(self):
        def launch(cmd, env, timeout):
            (self.out / "harness-status.txt").write_text("passed\n", encoding="ascii")
            return SimpleNamespace(returncode=7)

        self.assertEqual(self.run_main(launch), 7)

    def test_subprocess_timeout_fails(self):
        def launch(cmd, env, timeout):
            raise subprocess.TimeoutExpired(cmd, timeout)

        self.assertEqual(self.run_main(launch), 124)


if __name__ == "__main__":
    unittest.main()
