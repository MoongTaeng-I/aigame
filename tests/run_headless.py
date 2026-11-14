"""Capture the Godot process directly, including its exit code on Windows."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

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
command += ["--script", "tests/p0_runner.gd"] if kind == "p0" else ["--quit-after", "300"]
command += ["--log-file", str(log)]
timeout_sec = 300 if kind == "p0" else 120
started_at = time.perf_counter()
timed_out = False
with (root / ".local" / f"{stem}.out").open("wb") as out:
    with (root / ".local" / f"{stem}.err").open("wb") as err:
        try:
            result = subprocess.run(command, cwd=root, stdout=out, stderr=err, timeout=timeout_sec)
        except subprocess.TimeoutExpired:
            timed_out = True
elapsed_sec = time.perf_counter() - started_at
exit_code = None if timed_out else result.returncode
crashed = exit_code is not None and (exit_code < 0 or (exit_code & 0xFFFFFFFF) >= 0x80000000)
metadata = {"kind": kind, "attempt": attempt, "exit_code": exit_code, "exit_code_hex": None if exit_code is None else f"0x{exit_code & 0xFFFFFFFF:08X}", "result": "시간 초과" if timed_out else ("크래시" if crashed else ("정상 종료" if exit_code == 0 else "실패")), "elapsed_sec": elapsed_sec, "timeout_sec": timeout_sec, "command": command}
(root / ".local" / f"{stem}.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
print(f"{stem}: exit_code={exit_code}; attempt={attempt}; elapsed_sec={elapsed_sec:.3f}")
print((root / ".local" / f"{stem}.out").read_text(encoding="utf-8", errors="strict"))
print((root / ".local" / f"{stem}.err").read_text(encoding="utf-8", errors="strict"))
sys.exit(124 if timed_out else exit_code)
