"""Capture the Godot process directly, including its exit code on Windows."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

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
with (root / ".local" / f"{stem}.out").open("wb") as out:
    with (root / ".local" / f"{stem}.err").open("wb") as err:
        result = subprocess.run(command, cwd=root, stdout=out, stderr=err, timeout=120)
crashed = result.returncode < 0 or (result.returncode & 0xFFFFFFFF) >= 0x80000000
metadata = {"kind": kind, "attempt": attempt, "exit_code": result.returncode, "exit_code_hex": f"0x{result.returncode & 0xFFFFFFFF:08X}", "result": "크래시" if crashed else ("정상 종료" if result.returncode == 0 else "실패"), "command": command}
(root / ".local" / f"{stem}.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
print(f"{stem}: exit_code={result.returncode}; attempt={attempt}")
print((root / ".local" / f"{stem}.out").read_text(encoding="utf-8", errors="strict"))
print((root / ".local" / f"{stem}.err").read_text(encoding="utf-8", errors="strict"))
sys.exit(result.returncode)
