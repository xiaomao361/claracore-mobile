#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
SCHEME="ClaraCoreMobile"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_ID="${1:-${SIMULATOR_ID:-}}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT_DIR/.xcode-source-packages}"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-xctest.XXXXXX")"
TEST_LOG="$DERIVED_DATA/xcodebuild-test.log"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-900}"
PRESERVE_DERIVED_DATA=0

cleanup() {
  if [[ "$PRESERVE_DERIVED_DATA" == "1" ]]; then
    printf 'XCTest artifacts kept at: %s\n' "$DERIVED_DATA" >&2
  else
    rm -rf "$DERIVED_DATA"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_unit_tests.sh [simulator-udid]

Environment:
  SIMULATOR_ID       Optional simulator UDID.
  SIMULATOR_NAME     Simulator name to find when no UDID is provided. Default: iPhone 17 Pro
  SOURCE_PACKAGES_DIR
                     Reused SwiftPM package checkout/cache directory. Default: .xcode-source-packages
  XCODEBUILD_TIMEOUT_SECONDS
                     Timeout for xcodebuild test. Default: 900

This runs the ClaraCoreMobile XCTest suite on an iOS simulator. It is intended
as a local release-readiness gate before TestFlight or App Store submission.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

pass() {
  printf 'OK: %s\n' "$1"
}

fail() {
  PRESERVE_DERIVED_DATA=1
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

find_simulator_id() {
  xcrun simctl list devices available |
    sed -n "s/^[[:space:]]*${SIMULATOR_NAME} (\([0-9A-F-]*\)) (.*/\1/p" |
    head -n 1
}

if [[ -z "$SIMULATOR_ID" ]]; then
  SIMULATOR_ID="$(find_simulator_id)"
fi
[[ -n "$SIMULATOR_ID" ]] || fail "No available simulator found for SIMULATOR_NAME='$SIMULATOR_NAME'"

pass "Using simulator $SIMULATOR_ID"

xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b >/dev/null
pass "Simulator is booted"
mkdir -p "$SOURCE_PACKAGES_DIR"

if ! "$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh" "$XCODEBUILD_TIMEOUT_SECONDS" "$TEST_LOG" -- \
  xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  test; then
  tail -n 160 "$TEST_LOG" >&2
  fail "XCTest suite failed or timed out after ${XCODEBUILD_TIMEOUT_SECONDS}s. Full log: $TEST_LOG"
fi

pass "XCTest suite succeeded"
