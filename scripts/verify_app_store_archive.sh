#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
PROJECT_FILE="$PROJECT_PATH/project.pbxproj"
SCHEME="ClaraCoreMobile"
BUNDLE_ID="com.claracore.mobile"
CONFIGURATION="${CONFIGURATION:-Release}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT_DIR/.xcode-source-packages}"
ARCHIVE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-archive.XXXXXX")"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ARCHIVE_ROOT/ClaraCoreMobile.xcarchive}"
BUILD_LOG="$ARCHIVE_ROOT/xcodebuild-archive.log"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-1200}"
PRESERVE_ARCHIVE_ROOT=0

cleanup() {
  if [[ -n "${KEEP_ARCHIVE:-}" || "$PRESERVE_ARCHIVE_ROOT" == "1" ]]; then
    printf 'Archive artifacts kept at: %s\n' "$ARCHIVE_ROOT" >&2
    if [[ -d "$ARCHIVE_PATH" ]]; then
      printf 'Archive kept at: %s\n' "$ARCHIVE_PATH" >&2
    fi
  else
    rm -rf "$ARCHIVE_ROOT"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_app_store_archive.sh

Environment:
  CONFIGURATION      Xcode build configuration. Default: Release
  ARCHIVE_PATH       Optional output .xcarchive path. Default: temporary path
  KEEP_ARCHIVE       Set to any value to keep the generated archive
  SOURCE_PACKAGES_DIR
                     Reused SwiftPM package checkout/cache directory. Default: .xcode-source-packages
  XCODEBUILD_TIMEOUT_SECONDS
                     Timeout for xcodebuild archive. Default: 1200

This creates an unsigned generic iOS .xcarchive with CODE_SIGNING_ALLOWED=NO and
validates archive structure, bundled Info.plist metadata, PrivacyInfo manifest,
and dSYM presence. It is not an uploadable App Store archive and does not
replace a real signed archive/export/TestFlight upload.
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
  PRESERVE_ARCHIVE_ROOT=1
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

binary_uuids() {
  local binary="$1"
  dwarfdump --uuid "$binary" 2>/dev/null | awk '{ print $2 }' | sort -u
}

assert_dsym_matches_binary() {
  local binary="$1"
  local dsym_binary="$2"
  local label="$3"

  [[ -f "$binary" ]] || fail "$label app binary not found at $binary"
  [[ -f "$dsym_binary" ]] || fail "$label dSYM DWARF binary not found at $dsym_binary"

  local binary_uuid_count
  binary_uuid_count="$(binary_uuids "$binary" | wc -l | tr -d ' ')"
  [[ "$binary_uuid_count" -gt 0 ]] || fail "$label app binary UUIDs could not be read"

  while IFS= read -r uuid; do
    [[ -n "$uuid" ]] || continue
    if ! binary_uuids "$dsym_binary" | grep -Fxq "$uuid"; then
      fail "$label dSYM does not contain app binary UUID $uuid"
    fi
  done < <(binary_uuids "$binary")

  pass "$label dSYM UUIDs match the app binary"
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
  -archivePath "$ARCHIVE_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  archive; then
  tail -n 160 "$BUILD_LOG" >&2
  fail "Unsigned archive failed or timed out after ${XCODEBUILD_TIMEOUT_SECONDS}s. Full log: $BUILD_LOG"
fi
pass "$CONFIGURATION unsigned generic iOS archive succeeded"

APP_PATH="$ARCHIVE_PATH/Products/Applications/ClaraCoreMobile.app"
INFO_PLIST="$APP_PATH/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"
ARCHIVE_INFO="$ARCHIVE_PATH/Info.plist"
DSYM_PATH="$ARCHIVE_PATH/dSYMs/ClaraCoreMobile.app.dSYM"
APP_BINARY="$APP_PATH/ClaraCoreMobile"
DSYM_BINARY="$DSYM_PATH/Contents/Resources/DWARF/ClaraCoreMobile"

[[ -d "$ARCHIVE_PATH" ]] || fail "Archive not found at $ARCHIVE_PATH"
[[ -d "$APP_PATH" ]] || fail "Archived app bundle not found at $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "Archived app Info.plist not found"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "Archived app PrivacyInfo.xcprivacy not found"
[[ -f "$ARCHIVE_INFO" ]] || fail "Archive Info.plist not found"
[[ -d "$DSYM_PATH" ]] || fail "Archive dSYM not found at $DSYM_PATH"
pass "Archive contains app bundle, Info.plist, PrivacyInfo.xcprivacy, archive metadata, and dSYM"
assert_privacy_manifest_declarations "$PRIVACY_MANIFEST" "Archive"
assert_dsym_matches_binary "$APP_BINARY" "$DSYM_BINARY" "Archive"

assert_plist_value "$INFO_PLIST" "CFBundleIdentifier" "$BUNDLE_ID"
assert_plist_value "$INFO_PLIST" "CFBundleShortVersionString" "$EXPECTED_MARKETING_VERSION"
assert_plist_value "$INFO_PLIST" "CFBundleVersion" "$EXPECTED_BUILD_NUMBER"
assert_plist_value "$INFO_PLIST" "ITSAppUsesNonExemptEncryption" "false"
assert_plist_key_absent "$INFO_PLIST" "UIApplicationSceneManifest"
assert_plist_value "$ARCHIVE_INFO" "ApplicationProperties:CFBundleIdentifier" "$BUNDLE_ID"
assert_plist_value "$ARCHIVE_INFO" "ApplicationProperties:SigningIdentity" ""

pass "Unsigned archive metadata is ready for real signed archive/export validation"
