#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
SCHEME="ClaraCoreMobile"
CONFIGURATION="${CONFIGURATION:-Release}"
EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-com.claracore.mobile}"
EXPECTED_DEVELOPMENT_TEAM="${EXPECTED_DEVELOPMENT_TEAM:-}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT_DIR/.xcode-source-packages}"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-120}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-signing.XXXXXX")"
BUILD_SETTINGS_LOG="$WORK_DIR/xcodebuild-show-build-settings.log"
PRESERVE_WORK_DIR=0

cleanup() {
  if [[ "$PRESERVE_WORK_DIR" == "1" ]]; then
    printf 'Signing prerequisite artifacts kept at: %s\n' "$WORK_DIR" >&2
  else
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_app_store_signing_prerequisites.sh

Environment:
  CONFIGURATION                Xcode build configuration. Default: Release
  EXPECTED_BUNDLE_ID           Expected app bundle id. Default: com.claracore.mobile
  EXPECTED_DEVELOPMENT_TEAM    Optional expected Apple Developer Team ID.
  SOURCE_PACKAGES_DIR          Reused SwiftPM package checkout/cache directory. Default: .xcode-source-packages
  XCODEBUILD_TIMEOUT_SECONDS   Timeout for xcodebuild -showBuildSettings. Default: 120

Checks local prerequisites for a real signed App Store archive/TestFlight upload.
This does not upload anything. It should pass only after the Apple Developer
Program account, Xcode signing team, and local Apple Distribution certificate are
ready on this Mac.
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
  PRESERVE_WORK_DIR=1
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

setting_value() {
  local key="$1"
  awk -F' = ' -v key="$key" '$1 ~ "^[[:space:]]*" key "$" { print $2; exit }' "$BUILD_SETTINGS_LOG"
}

assert_setting() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(setting_value "$key")"
  [[ "$actual" == "$expected" ]] || fail "$key expected '$expected' but got '${actual:-<missing>}'"
  pass "$key = $expected"
}

assert_nonempty_setting() {
  local key="$1"
  local actual
  actual="$(setting_value "$key")"
  [[ -n "$actual" ]] || fail "$key must not be empty for App Store signing"
  pass "$key = $actual"
}

mkdir -p "$SOURCE_PACKAGES_DIR"

if ! "$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh" "$XCODEBUILD_TIMEOUT_SECONDS" "$BUILD_SETTINGS_LOG" -- \
  xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  -showBuildSettings; then
  tail -n 120 "$BUILD_SETTINGS_LOG" >&2
  fail "Could not read Release iOS build settings. Full log: $BUILD_SETTINGS_LOG"
fi

assert_setting "PRODUCT_BUNDLE_IDENTIFIER" "$EXPECTED_BUNDLE_ID"
assert_setting "CODE_SIGN_STYLE" "Automatic"
assert_nonempty_setting "DEVELOPMENT_TEAM"
assert_nonempty_setting "MARKETING_VERSION"
assert_nonempty_setting "CURRENT_PROJECT_VERSION"

development_team="$(setting_value DEVELOPMENT_TEAM)"
if [[ -n "$EXPECTED_DEVELOPMENT_TEAM" ]]; then
  [[ "$development_team" == "$EXPECTED_DEVELOPMENT_TEAM" ]] || fail "DEVELOPMENT_TEAM expected '$EXPECTED_DEVELOPMENT_TEAM' but got '$development_team'"
  pass "DEVELOPMENT_TEAM matches EXPECTED_DEVELOPMENT_TEAM"
fi

supported_platforms="$(setting_value SUPPORTED_PLATFORMS)"
case " $supported_platforms " in
  *" iphoneos "*) pass "SUPPORTED_PLATFORMS includes iphoneos" ;;
  *) fail "SUPPORTED_PLATFORMS must include iphoneos, got '${supported_platforms:-<missing>}'" ;;
esac

identities="$(security find-identity -p codesigning -v 2>/dev/null || true)"
matching_identity="$(
  printf '%s\n' "$identities" |
    grep -E "\"(Apple Distribution|iPhone Distribution): .*\\($development_team\\)\"" |
    head -n 1 || true
)"
if [[ -z "$matching_identity" ]]; then
  fail "No valid Apple Distribution signing identity for DEVELOPMENT_TEAM '$development_team' found in the local keychain. Install/create one after joining the Apple Developer Program."
fi
pass "A valid Apple Distribution signing identity for DEVELOPMENT_TEAM $development_team is available in the local keychain"

pass "App Store signing prerequisites are ready for a real signed archive/TestFlight upload"
