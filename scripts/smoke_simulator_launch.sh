#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
SCHEME="ClaraCoreMobile"
BUNDLE_ID="com.claracore.mobile"
CONFIGURATION="${CONFIGURATION:-Release}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SIMULATOR_ID="${1:-${SIMULATOR_ID:-}}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT_DIR/.xcode-source-packages}"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-sim-smoke.XXXXXX")"
BUILD_LOG="$DERIVED_DATA/xcodebuild-${CONFIGURATION}.log"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-900}"
PRESERVE_DERIVED_DATA=0

cleanup() {
  if [[ -n "${SIMULATOR_ID:-}" ]]; then
    xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi
  if [[ "$PRESERVE_DERIVED_DATA" == "1" ]]; then
    printf 'Simulator smoke artifacts kept at: %s\n' "$DERIVED_DATA" >&2
  else
    rm -rf "$DERIVED_DATA"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  scripts/smoke_simulator_launch.sh [simulator-udid]

Environment:
  SIMULATOR_ID       Optional simulator UDID.
  SIMULATOR_NAME     Simulator name to find when no UDID is provided. Default: iPhone 17
  CONFIGURATION      Xcode build configuration. Default: Release
  SOURCE_PACKAGES_DIR
                     Reused SwiftPM package checkout/cache directory. Default: .xcode-source-packages
  XCODEBUILD_TIMEOUT_SECONDS
                     Timeout for xcodebuild build. Default: 900

This builds, installs, launches, checks that the app process is running, then
terminates ClaraCore Mobile. It may boot the selected simulator, but it does not
shut the simulator down.
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

if ! "$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh" "$XCODEBUILD_TIMEOUT_SECONDS" "$BUILD_LOG" -- \
  xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  build; then
  tail -n 120 "$BUILD_LOG" >&2
  fail "Simulator smoke build failed or timed out after ${XCODEBUILD_TIMEOUT_SECONDS}s. Full log: $BUILD_LOG"
fi
pass "$CONFIGURATION simulator build succeeded"

APP_PATH="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphonesimulator/ClaraCoreMobile.app"
[[ -d "$APP_PATH" ]] || fail "Built app bundle not found at $APP_PATH"

xcrun simctl uninstall "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
pass "Installed $BUNDLE_ID"

launch_output="$(xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID" 2>&1)" || {
  printf '%s\n' "$launch_output" >&2
  fail "Simulator failed to launch $BUNDLE_ID"
}
printf '%s\n' "$launch_output"
launch_pid="$(printf '%s\n' "$launch_output" | awk -F': ' -v bundle="$BUNDLE_ID" '$1 == bundle { print $2; exit }')"
[[ "$launch_pid" =~ ^[0-9]+$ ]] || fail "Could not parse launch pid from simctl output"

sleep 2
if ! xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1; then
  fail "$BUNDLE_ID launched with pid $launch_pid, but was not running two seconds later"
fi
pass "$BUNDLE_ID launched and remained terminable after startup preflight"
