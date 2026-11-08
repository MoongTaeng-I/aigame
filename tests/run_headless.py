"""Capture the Godot process directly, including its exit code on Windows."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
task = "s3-impl-02"
kind = sys.argv[1]
attempt = int(sys.argv[2]) if len(sys.argv) > 2 else 1
executable = Path((root / ".local/godot_path.txt").read_text(encoding="utf-8-sig").strip())
if not executable.is_file():
    raise SystemExit("Configured Godot executable does not exist")
stem = f"{task}-p0" if kind == "p0" else f"{task}-run{attempt}"
log = root / ".local/godot_logs" / f"{stem}.log"
log.parent.mkdir(parents=True, exist_ok=True)
command = [str(executable), "--headless", "--path", str(root)]
command += ["--script", "tests/p0_runner.gd"] if kind == "p0" else ["--quit-after", "300"]
command += ["--log-file", str(log)]
with (root / ".local" / f"{stem}.out").open("wb") as out:
    with (root / ".local" / f"{stem}.err").open("wb") as err:
        result = subprocess.run(command, cwd=root, stdout=out, stderr=err, timeout=120)
metadata = {"kind": kind, "attempt": attempt, "exit_code": result.returncode, "command": command}
(root / ".local" / f"{stem}.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
if kind == "p0":
    for suffix in ["out", "err", "json"]:
        (root / ".local" / f"{task}-p0-attempt{attempt}.{suffix}").write_bytes(
            (root / ".local" / f"{stem}.{suffix}").read_bytes()
        )
print(f"{stem}: exit_code={result.returncode}; attempt={attempt}")
print((root / ".local" / f"{stem}.out").read_text(encoding="utf-8", errors="strict"))
print((root / ".local" / f"{stem}.err").read_text(encoding="utf-8", errors="strict"))
sys.exit(result.returncode)
