#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
PROJECT_FILE="$PROJECT_PATH/project.pbxproj"
SCHEME="ClaraCoreMobile"
BUNDLE_ID="com.claracore.mobile"
CONFIGURATION="${CONFIGURATION:-Release}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT_DIR/.xcode-source-packages}"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-device-release.XXXXXX")"
BUILD_LOG="$DERIVED_DATA/xcodebuild-${CONFIGURATION}-iphoneos.log"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-900}"
PRESERVE_DERIVED_DATA=0

cleanup() {
  if [[ "$PRESERVE_DERIVED_DATA" == "1" ]]; then
    printf 'Device Release build artifacts kept at: %s\n' "$DERIVED_DATA" >&2
  else
    rm -rf "$DERIVED_DATA"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_device_release_build.sh

Environment:
  CONFIGURATION      Xcode build configuration. Default: Release
  SOURCE_PACKAGES_DIR
                     Reused SwiftPM package checkout/cache directory. Default: .xcode-source-packages
  XCODEBUILD_TIMEOUT_SECONDS
                     Timeout for xcodebuild build. Default: 900

This builds ClaraCore Mobile for generic iOS devices with CODE_SIGNING_ALLOWED=NO.
It does not create an uploadable App Store archive and does not replace a real
Developer Program signing/TestFlight pass. It catches Release iphoneos compile,
bundle, Info.plist, and PrivacyInfo issues before upload.
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

assert_plist_value() {
  local plist="$1"
  local key_path="$2"
  local expected="$3"
  local actual
  actual="$(/usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]] || fail "$plist $key_path expected '$expected' but got '${actual:-<missing>}'"
  pass "$plist $key_path = $expected"
}

assert_plist_key_absent() {
  local plist="$1"
  local key_path="$2"
  if /usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" >/dev/null 2>&1; then
    fail "$plist must not contain $key_path"
  fi
  pass "$plist does not contain $key_path"
}

assert_plist_array_count() {
  local plist="$1"
  local key_path="$2"
  local expected="$3"
  local actual
  actual="$(python3 - "$plist" "$key_path" <<'PY'
import plistlib
import sys
from pathlib import Path

plist = Path(sys.argv[1])
key_path = sys.argv[2].split(":")
with plist.open("rb") as handle:
    value = plistlib.load(handle)
for key in key_path:
    value = value[key]
if not isinstance(value, list):
    raise SystemExit("not-array")
print(len(value))
PY
)" || fail "$plist $key_path must be an array"
  [[ "$actual" == "$expected" ]] || fail "$plist $key_path expected $expected entries but got $actual"
  pass "$plist $key_path has $expected entries"
}

assert_privacy_manifest_declarations() {
  local manifest="$1"
  local label="$2"
  assert_plist_value "$manifest" "NSPrivacyTracking" "false"
  assert_plist_array_count "$manifest" "NSPrivacyTrackingDomains" "0"
  assert_plist_array_count "$manifest" "NSPrivacyCollectedDataTypes" "0"
  assert_plist_value "$manifest" "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType" "NSPrivacyAccessedAPICategoryUserDefaults"
  assert_plist_value "$manifest" "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0" "CA92.1"
  pass "$label PrivacyInfo declarations match App Store privacy claims"
}

unique_project_setting() {
  local key="$1"
  local values
  values="$(awk -v key="$key" '$1 == key { value = $3; gsub(/;/, "", value); print value }' "$PROJECT_FILE" | sort -u)"
  local count
  count="$(printf '%s\n' "$values" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$count" == "1" ]] || fail "$key must have exactly one value across project configurations, got: ${values:-<none>}"
  printf '%s\n' "$values"
}

EXPECTED_MARKETING_VERSION="$(unique_project_setting MARKETING_VERSION)"
EXPECTED_BUILD_NUMBER="$(unique_project_setting CURRENT_PROJECT_VERSION)"
pass "MARKETING_VERSION is consistently $EXPECTED_MARKETING_VERSION"
pass "CURRENT_PROJECT_VERSION is consistently $EXPECTED_BUILD_NUMBER"
mkdir -p "$SOURCE_PACKAGES_DIR"

if ! "$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh" "$XCODEBUILD_TIMEOUT_SECONDS" "$BUILD_LOG" -- \
  xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build; then
  tail -n 120 "$BUILD_LOG" >&2
  fail "Release iphoneos build failed or timed out after ${XCODEBUILD_TIMEOUT_SECONDS}s. Full log: $BUILD_LOG"
fi
pass "$CONFIGURATION iphoneos build succeeded with CODE_SIGNING_ALLOWED=NO"

APP_PATH="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphoneos/ClaraCoreMobile.app"
INFO_PLIST="$APP_PATH/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"

[[ -d "$APP_PATH" ]] || fail "Built device app bundle not found at $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "Built device Info.plist not found"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "Built device PrivacyInfo.xcprivacy not found"
pass "Built device bundle contains Info.plist and PrivacyInfo.xcprivacy"
assert_privacy_manifest_declarations "$PRIVACY_MANIFEST" "Device Release bundle"

assert_plist_value "$INFO_PLIST" "CFBundleIdentifier" "$BUNDLE_ID"
assert_plist_value "$INFO_PLIST" "CFBundleShortVersionString" "$EXPECTED_MARKETING_VERSION"
assert_plist_value "$INFO_PLIST" "CFBundleVersion" "$EXPECTED_BUILD_NUMBER"
assert_plist_value "$INFO_PLIST" "ITSAppUsesNonExemptEncryption" "false"
assert_plist_key_absent "$INFO_PLIST" "UIApplicationSceneManifest"

pass "Device Release build metadata is ready for real signing/archive validation"
