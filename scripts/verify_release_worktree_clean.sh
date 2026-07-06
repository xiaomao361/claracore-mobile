#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_release_worktree_clean.sh

Checks that the Git worktree is clean before treating an App Store submission
gate as upload-ready. This script does not stage, commit, reset, clean, push, or
otherwise mutate the worktree.

Run this only for final release/upload readiness. Day-to-day local readiness can
pass with local changes, but a TestFlight/App Review upload should come from a
committed, reproducible release checkpoint.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

status="$(git -C "$ROOT_DIR" status --porcelain)"
if [[ -n "$status" ]]; then
  printf 'ERROR: Release worktree is not clean. Uncommitted changes would make the upload package non-reproducible:\n' >&2
  printf '%s\n' "$status" >&2
  printf 'Next action: when you are ready for a release checkpoint, review the changes, then stage and commit the intended release state once. This script did not modify Git.\n' >&2
  exit 1
fi

printf 'OK: Release worktree is clean\n'
