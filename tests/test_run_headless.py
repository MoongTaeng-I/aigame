"""Exercise capture paths and crash metadata without crashing a real Godot process."""
import contextlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


class HeadlessCaptureP0(unittest.TestCase):
    def test_attempt_logs_survive_and_crash_is_not_success(self):
        source = Path(__file__).with_name("run_headless.py").read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            script = root / "tests/run_headless.py"
            script.parent.mkdir()
            script.write_bytes(source)
            local = root / ".local"
            local.mkdir()
            executable = root / "fake-godot.exe"
            executable.touch()
            (local / "godot_path.txt").write_text(str(executable), encoding="utf-8")

            def capture(command, **kwargs):
                log = Path(command[command.index("--log-file") + 1])
                log.write_text(str(exit_code), encoding="utf-8")
                kwargs["stdout"].write(b"captured stdout\n")
                return subprocess.CompletedProcess(command, exit_code)

            for kind in ("p0", "runtime"):
                for attempt, exit_code in enumerate((0, 1, 3221225477, -1073741819), 1):
                    with patch.object(sys, "argv", [str(script), "capture-test", kind, str(attempt)]):
                        with patch("subprocess.run", side_effect=capture):
                            with contextlib.redirect_stdout(io.StringIO()):
                                with self.assertRaises(SystemExit) as result:
                                    runpy.run_path(str(script), run_name="__main__")
                    self.assertEqual(result.exception.code, exit_code)
                    stem = f"capture-test-{kind}-attempt{attempt}"
                    metadata = json.loads((local / f"{stem}.json").read_text())
                    self.assertEqual(metadata["result"], "크래시" if attempt >= 3 else ("정상 종료" if attempt == 1 else "실패"))
                    if attempt >= 3:
                        self.assertEqual(metadata["exit_code_hex"], "0xC0000005")
                    for previous in range(1, attempt + 1):
                        path = local / "godot_logs" / f"capture-test-{kind}-attempt{previous}.log"
                        self.assertEqual(path.read_text(), str((0, 1, 3221225477, -1073741819)[previous - 1]))


if __name__ == "__main__":
    unittest.main()
