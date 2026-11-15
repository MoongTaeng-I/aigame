"""Capture native Godot exit separately from test completion-marker status."""
import argparse
import json
import re
from pathlib import Path
import sys
import time
sys.dont_write_bytecode = True
from probe_process import execute

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("task", help="Task ID used in output file names")
parser.add_argument("kind", choices=("p0", "runtime"))
parser.add_argument("attempt", type=int)
args = parser.parse_args()
task = args.task.lower()
kind = args.kind
attempt = args.attempt
if not task or attempt < 1:
    parser.error("task must not be empty and attempt must be positive")
executable = Path((root / ".local/godot_path.txt").read_text(encoding="utf-8-sig").strip())
if not executable.is_file():
    raise SystemExit("Configured Godot executable does not exist")
stem = f"{task}-{kind}-attempt{attempt}"
log = root / ".local/godot_logs" / f"{stem}.log"
log.parent.mkdir(parents=True, exist_ok=True)
command = [str(executable), "--headless", "--path", str(root)]
command += ["--script", "tests/p0_runner.gd" if kind == "p0" else "tests/runtime_probe.gd"]
command += ["--log-file", str(log)]
timeout_sec = 300 if kind == "p0" else 120
started_at = time.perf_counter()
timed_out = False
with (root / ".local" / f"{stem}.out").open("wb") as out:
    with (root / ".local" / f"{stem}.err").open("wb") as err:
        result = execute(command, root, out, err, timeout_sec)
        timed_out = result["timeout"]
elapsed_sec = time.perf_counter() - started_at
exit_code = result["exit_code"]
crashed = exit_code is not None and (exit_code < 0 or (exit_code & 0xFFFFFFFF) >= 0x80000000)
metadata = {"kind": kind, "attempt": attempt, "exit_code": exit_code, "exit_code_hex": None if exit_code is None else f"0x{exit_code & 0xFFFFFFFF:08X}", "result": "시간 초과" if timed_out else ("크래시" if crashed else ("정상 종료" if exit_code == 0 else "실패")), "elapsed_sec": elapsed_sec, "timeout_sec": timeout_sec, "command": command}
metadata.update(result)
stdout = (root / ".local" / f"{stem}.out").read_text(encoding="utf-8", errors="strict")
stderr = (root / ".local" / f"{stem}.err").read_text(encoding="utf-8", errors="strict")
# Preserve the existing no-unexpected-diagnostics requirement alongside done.
certificate = "ERROR: Failed to read the root certificate store.\n   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)\n"
metadata["output_valid"] = not stderr.replace(certificate, "", 1).strip() and not re.search(r"(?m)^FAIL\b|SCRIPT ERROR|Parse Error", stdout)
passed = result["code"] == 0 and metadata["output_valid"]
metadata["result"] = "시간 초과" if timed_out else ("통과" if passed else "실패")
(root / ".local" / f"{stem}.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
print(f"{stem}: exit_code={exit_code}; attempt={attempt}; elapsed_sec={elapsed_sec:.3f}")
print(stdout)
print(stderr)
sys.exit(124 if timed_out else (0 if passed else 1))
