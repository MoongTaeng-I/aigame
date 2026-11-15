"""Test-only Godot execution: suppress dialogs; validate fresh done, log native exit."""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def execute(command, root, out, err, timeout):
    root = Path(root)
    name = Path(command[command.index("--script") + 1]).stem
    done = root / ".local" / (name + "-done.json")
    done.unlink(missing_ok=True)
    if os.name == "nt":
        ctypes.windll.kernel32.SetErrorMode(0x0001 | 0x0002 | 0x8000)
    started = time.perf_counter()
    timed_out = False
    try:
        result = subprocess.run(command, cwd=root, stdout=out, stderr=err, timeout=timeout,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        native = result.returncode
    except subprocess.TimeoutExpired:
        native = None
        timed_out = True
    state = None
    try:
        state = json.loads(done.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        pass
    valid = isinstance(state, dict) and state.get("name") == name and type(state.get("code")) is int
    code = state["code"] if valid and not timed_out else 1
    return {"exit_code": native, "exit_code_hex": None if native is None else f"0x{native & 0xffffffff:08X}",
            "done": str(done), "done_state": state, "code": code, "timeout": timed_out,
            "elapsed_sec": time.perf_counter() - started, "command": command}


if __name__ == "__main__":
    executable, log, *arguments = sys.argv[1:]
    root = Path(arguments[arguments.index("--path") + 1])
    with open(log + ".process.out", "wb") as captured:
        record = execute([executable, *arguments], root, captured, subprocess.STDOUT, 120)
    Path(log + ".process.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    sys.stdout.buffer.write(Path(log + ".process.out").read_bytes())
    sys.exit(0 if record["code"] == 0 else 1)
