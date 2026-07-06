#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_xcodebuild_with_timeout.sh <timeout-seconds> <log-file> -- xcodebuild ...

Runs an xcodebuild command, writes combined stdout/stderr to the given log, and
terminates the command process group if it exceeds the timeout.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

[[ "$#" -ge 4 ]] || {
  usage >&2
  exit 2
}

TIMEOUT_SECONDS="$1"
LOG_FILE="$2"
shift 2
[[ "${1:-}" == "--" ]] || {
  usage >&2
  exit 2
}
shift

[[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ && "$TIMEOUT_SECONDS" -gt 0 ]] || {
  printf 'ERROR: timeout must be a positive integer, got %s\n' "$TIMEOUT_SECONDS" >&2
  exit 2
}

mkdir -p "$(dirname "$LOG_FILE")"

python3 - "$TIMEOUT_SECONDS" "$LOG_FILE" "$@" <<'PY'
import os
import signal
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
log_file = sys.argv[2]
command = sys.argv[3:]

with open(log_file, "wb") as log:
    process = subprocess.Popen(
        command,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    try:
        process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        message = (
            f"\nERROR: command timed out after {timeout_seconds} seconds: "
            + " ".join(command)
            + "\n"
        )
        log.write(message.encode("utf-8", errors="replace"))
        log.flush()
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=10)
        except Exception:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except Exception:
                pass
        sys.exit(124)

sys.exit(process.returncode)
PY
