#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_LOCAL_READINESS="${RUN_LOCAL_READINESS:-1}"
RUN_SIGNING_PREREQUISITES="${RUN_SIGNING_PREREQUISITES:-1}"
RUN_SIGNED_ARTIFACTS="${RUN_SIGNED_ARTIFACTS:-1}"
RUN_TRACKED_ARTIFACTS="${RUN_TRACKED_ARTIFACTS:-1}"
RUN_CLEAN_WORKTREE="${RUN_CLEAN_WORKTREE:-1}"
RUN_PUBLIC_DOCS="${RUN_PUBLIC_DOCS:-1}"
RUN_SCREENSHOTS="${RUN_SCREENSHOTS:-1}"
MIN_SCREENSHOTS_PER_DEVICE="${MIN_SCREENSHOTS_PER_DEVICE:-8}"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_app_store_submission_ready.sh

Environment:
  RUN_LOCAL_READINESS          Run scripts/verify_app_store_readiness.sh. Default: 1
  RUN_SIGNING_PREREQUISITES   Run scripts/verify_app_store_signing_prerequisites.sh. Default: 1
  RUN_SIGNED_ARTIFACTS        Run scripts/verify_signed_app_store_artifacts.sh. Default: 1
  RUN_TRACKED_ARTIFACTS       Run scripts/verify_release_artifacts_tracked.sh. Default: 1
  RUN_CLEAN_WORKTREE          Run scripts/verify_release_worktree_clean.sh. Default: 1
  RUN_PUBLIC_DOCS             Run scripts/verify_public_app_store_docs.sh. Default: 1
  RUN_SCREENSHOTS             Run scripts/verify_app_store_screenshots.sh. Default: 1
  MIN_SCREENSHOTS_PER_DEVICE  Minimum screenshot count per device set for final gate. Default: 8

This is the final local gate before uploading a signed archive to TestFlight or
submitting to App Review. It uploads nothing. Unlike the individual scripts, it
runs every enabled check and reports all failing gates at the end.

By default this requires a real signed archive, so pass ARCHIVE_PATH plus
optional EXPORT_PATH for the produced artifacts. For a pre-certificate dry run
only, set RUN_SIGNED_ARTIFACTS=0 explicitly. If any RUN_* gate is disabled, a
successful run is only a partial check and must not be treated as upload-ready.
RUN_* values must be explicit booleans: 1, 0, true, false, yes, or no.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

failures=()
failure_hints=()
enabled_gate_count=0

normalize_bool() {
  local name="$1"
  local value="$2"
  case "$value" in
    1|true|yes) printf '1' ;;
    0|false|no) printf '0' ;;
    *)
      printf 'ERROR: %s must be one of 1, 0, true, false, yes, or no; got %q\n' "$name" "$value" >&2
      return 1
      ;;
  esac
}

assert_final_gate_environment() {
  [[ "$MIN_SCREENSHOTS_PER_DEVICE" =~ ^[0-9]+$ ]] || {
    printf 'ERROR: MIN_SCREENSHOTS_PER_DEVICE must be an integer from 1 to 10; got %q\n' "$MIN_SCREENSHOTS_PER_DEVICE" >&2
    exit 1
  }
  (( MIN_SCREENSHOTS_PER_DEVICE >= 1 && MIN_SCREENSHOTS_PER_DEVICE <= 10 )) || {
    printf 'ERROR: MIN_SCREENSHOTS_PER_DEVICE must be from 1 to 10; got %s\n' "$MIN_SCREENSHOTS_PER_DEVICE" >&2
    exit 1
  }

  RUN_LOCAL_READINESS="$(normalize_bool RUN_LOCAL_READINESS "$RUN_LOCAL_READINESS")" || exit 1
  RUN_SIGNING_PREREQUISITES="$(normalize_bool RUN_SIGNING_PREREQUISITES "$RUN_SIGNING_PREREQUISITES")" || exit 1
  RUN_SIGNED_ARTIFACTS="$(normalize_bool RUN_SIGNED_ARTIFACTS "$RUN_SIGNED_ARTIFACTS")" || exit 1
  RUN_TRACKED_ARTIFACTS="$(normalize_bool RUN_TRACKED_ARTIFACTS "$RUN_TRACKED_ARTIFACTS")" || exit 1
  RUN_CLEAN_WORKTREE="$(normalize_bool RUN_CLEAN_WORKTREE "$RUN_CLEAN_WORKTREE")" || exit 1
  RUN_PUBLIC_DOCS="$(normalize_bool RUN_PUBLIC_DOCS "$RUN_PUBLIC_DOCS")" || exit 1
  RUN_SCREENSHOTS="$(normalize_bool RUN_SCREENSHOTS "$RUN_SCREENSHOTS")" || exit 1
}

run_gate() {
  local label="$1"
  local hint="$2"
  shift
  shift

  enabled_gate_count=$((enabled_gate_count + 1))
  printf '\n==> %s\n' "$label"
  if "$@"; then
    printf 'OK: %s passed\n' "$label"
  else
    local exit_code="$?"
    printf 'ERROR: %s failed with exit code %s\n' "$label" "$exit_code" >&2
    failures+=("$label")
    failure_hints+=("$hint")
  fi
}

enabled() {
  [[ "${1:-}" == "1" ]]
}

all_required_gates_enabled() {
  enabled "$RUN_LOCAL_READINESS" &&
    enabled "$RUN_SIGNING_PREREQUISITES" &&
    enabled "$RUN_SIGNED_ARTIFACTS" &&
    enabled "$RUN_TRACKED_ARTIFACTS" &&
    enabled "$RUN_CLEAN_WORKTREE" &&
    enabled "$RUN_PUBLIC_DOCS" &&
    enabled "$RUN_SCREENSHOTS"
}

assert_final_gate_environment

if enabled "$RUN_LOCAL_READINESS"; then
  run_gate \
    "Local App Store readiness" \
    "Fix the source, metadata, privacy, simulator, device Release, or unsigned archive issue reported above, then rerun scripts/verify_app_store_readiness.sh." \
    "$ROOT_DIR/scripts/verify_app_store_readiness.sh"
fi
if enabled "$RUN_SIGNING_PREREQUISITES"; then
  run_gate \
    "Apple Developer signing prerequisites" \
    "Join/configure the Apple Developer Program team in Xcode and install a valid Apple Distribution certificate in the local keychain." \
    "$ROOT_DIR/scripts/verify_app_store_signing_prerequisites.sh"
fi
if enabled "$RUN_SIGNED_ARTIFACTS"; then
  run_gate \
    "Signed App Store archive/export artifacts" \
    "Create a real signed App Store archive, then rerun with ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive and optional EXPORT_PATH=/path/to/export." \
    "$ROOT_DIR/scripts/verify_signed_app_store_artifacts.sh"
fi
if enabled "$RUN_TRACKED_ARTIFACTS"; then
  run_gate \
    "Release artifacts tracked by Git" \
    "When ready for a release checkpoint, stage and commit the release-critical files reported above once, then publish public docs/materials from that committed state." \
    "$ROOT_DIR/scripts/verify_release_artifacts_tracked.sh"
fi
if enabled "$RUN_CLEAN_WORKTREE"; then
  run_gate \
    "Release worktree clean" \
    "Review the local changes, then stage and commit the intended release state once before treating the App Store gate as upload-ready." \
    "$ROOT_DIR/scripts/verify_release_worktree_clean.sh"
fi
if enabled "$RUN_PUBLIC_DOCS"; then
  run_gate \
    "Published Privacy Policy and Support docs" \
    "Publish the current docs/app-store materials to the public URL used in metadata, or update metadata to a public URL whose content exactly matches local release documents." \
    "$ROOT_DIR/scripts/verify_public_app_store_docs.sh"
fi
if enabled "$RUN_SCREENSHOTS"; then
  run_gate \
    "App Store screenshot package" \
    "Provide nonduplicate final screenshots for every required file in docs/app-store/screenshot-plan.md, then rerun MIN_SCREENSHOTS_PER_DEVICE=$MIN_SCREENSHOTS_PER_DEVICE scripts/verify_app_store_screenshots.sh." \
    env MIN_SCREENSHOTS_PER_DEVICE="$MIN_SCREENSHOTS_PER_DEVICE" "$ROOT_DIR/scripts/verify_app_store_screenshots.sh"
fi

printf '\n==> Submission readiness summary\n'
if ((enabled_gate_count == 0)); then
  printf 'ERROR: App Store submission readiness ran zero gates. Enable at least one RUN_* check.\n' >&2
  exit 1
fi

if ((${#failures[@]} > 0)); then
  printf 'ERROR: App Store submission is not ready. Failing gates:\n' >&2
  for index in "${!failures[@]}"; do
    printf '  - %s\n' "${failures[$index]}" >&2
    printf '    Next action: %s\n' "${failure_hints[$index]}" >&2
  done
  exit 1
fi

if all_required_gates_enabled; then
  printf 'OK: All App Store submission gates passed. The local gate is upload-ready.\n'
else
  printf 'OK: All enabled App Store submission gates passed.\n'
  printf 'WARNING: This was a partial submission readiness run because at least one RUN_* gate was disabled. Do not upload to TestFlight or submit to App Review based on this partial run.\n' >&2
fi
