#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/ClaraCoreMobile.xcodeproj/project.pbxproj"
BUNDLE_ID="${BUNDLE_ID:-com.claracore.mobile}"
ARCHIVE_PATH="${ARCHIVE_PATH:-}"
EXPORT_PATH="${EXPORT_PATH:-}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-signed-artifacts.XXXXXX")"
PRESERVE_WORK_DIR=0

cleanup() {
  if [[ "$PRESERVE_WORK_DIR" == "1" ]]; then
    printf 'Signed artifact verification workspace kept at: %s\n' "$WORK_DIR" >&2
  else
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive scripts/verify_signed_app_store_artifacts.sh
  ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive EXPORT_PATH=/path/to/export scripts/verify_signed_app_store_artifacts.sh

Environment:
  ARCHIVE_PATH   Required signed .xcarchive path from Xcode Organizer or xcodebuild archive.
  EXPORT_PATH    Optional export directory containing an .ipa after app-store-connect export.
  BUNDLE_ID      Expected bundle id. Default: com.claracore.mobile

This validates already-created signed App Store artifacts. It does not create,
export, upload, notarize, or submit anything.
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

plist_value() {
  local plist="$1"
  local key_path="$2"
  /usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" 2>/dev/null || true
}

assert_plist_value() {
  local plist="$1"
  local key_path="$2"
  local expected="$3"
  local actual
  actual="$(plist_value "$plist" "$key_path")"
  [[ "$actual" == "$expected" ]] || fail "$plist $key_path expected '$expected' but got '${actual:-<missing>}'"
  pass "$plist $key_path = $expected"
}

assert_plist_value_matches() {
  local plist="$1"
  local key_path="$2"
  local pattern="$3"
  local description="$4"
  local actual
  actual="$(plist_value "$plist" "$key_path")"
  [[ "$actual" =~ $pattern ]] || fail "$plist $key_path must match $description, got '${actual:-<missing>}'"
  pass "$plist $key_path matches $description"
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

assert_distribution_signature() {
  local app_path="$1"
  local signature
  codesign --verify --strict "$app_path" >/dev/null 2>&1 ||
    fail "$app_path code signature failed strict verification"
  signature="$(codesign -dv "$app_path" 2>&1 || true)"
  printf '%s\n' "$signature" | grep -Eq 'Authority=(Apple Distribution|iPhone Distribution)' ||
    fail "$app_path is not signed with an Apple Distribution identity"
  printf '%s\n' "$signature" | grep -q "TeamIdentifier=" ||
    fail "$app_path signature is missing TeamIdentifier"
  pass "$app_path is signed with an Apple Distribution identity"
}

assert_signature_team_matches_profile() {
  local app_path="$1"
  local label="$2"
  local expected_team_identifier="$3"
  local signature actual_team_identifier

  signature="$(codesign -dv "$app_path" 2>&1 || true)"
  actual_team_identifier="$(printf '%s\n' "$signature" | awk -F= '$1 == "TeamIdentifier" { print $2; exit }')"
  [[ "$actual_team_identifier" == "$expected_team_identifier" ]] ||
    fail "$label code signature TeamIdentifier expected '$expected_team_identifier' but got '${actual_team_identifier:-<missing>}'"
  pass "$label code signature TeamIdentifier matches the embedded provisioning profile"
}

assert_signed_entitlements_match_profile() {
  local app_path="$1"
  local label="$2"
  local expected_application_identifier="$3"
  local expected_team_identifier="$4"
  local expected_get_task_allow="$5"
  local entitlements="$WORK_DIR/${label}.codesign-entitlements.plist"

  codesign -d --entitlements :- "$app_path" >"$entitlements" 2>/dev/null ||
    fail "$label code signature entitlements could not be decoded"

  local signed_application_identifier signed_team_identifier signed_get_task_allow
  signed_application_identifier="$(plist_value "$entitlements" "application-identifier")"
  signed_team_identifier="$(plist_value "$entitlements" "com.apple.developer.team-identifier")"
  signed_get_task_allow="$(plist_value "$entitlements" "get-task-allow")"

  [[ "$signed_application_identifier" == "$expected_application_identifier" ]] ||
    fail "$label code signature application-identifier expected '$expected_application_identifier' but got '${signed_application_identifier:-<missing>}'"
  [[ "$signed_team_identifier" == "$expected_team_identifier" ]] ||
    fail "$label code signature team identifier expected '$expected_team_identifier' but got '${signed_team_identifier:-<missing>}'"
  [[ "$signed_get_task_allow" == "$expected_get_task_allow" ]] ||
    fail "$label code signature get-task-allow expected '$expected_get_task_allow' but got '${signed_get_task_allow:-<missing>}'"

  pass "$label code signature entitlements match the embedded provisioning profile"
}

assert_embedded_profile() {
  local app_path="$1"
  local label="$2"
  local profile="$app_path/embedded.mobileprovision"
  local decoded="$WORK_DIR/${label}.mobileprovision.plist"

  [[ -f "$profile" ]] || fail "$label embedded.mobileprovision not found"
  security cms -D -i "$profile" >"$decoded" 2>/dev/null ||
    fail "$label embedded.mobileprovision could not be decoded"

  local application_identifier team_identifier get_task_allow provisions_all_devices expiration_date
  application_identifier="$(plist_value "$decoded" "Entitlements:application-identifier")"
  team_identifier="$(plist_value "$decoded" "Entitlements:com.apple.developer.team-identifier")"
  get_task_allow="$(plist_value "$decoded" "Entitlements:get-task-allow")"
  provisions_all_devices="$(plist_value "$decoded" "ProvisionsAllDevices")"
  expiration_date="$(plist_value "$decoded" "ExpirationDate")"

  [[ "$application_identifier" == *".$BUNDLE_ID" ]] ||
    fail "$label provisioning profile application-identifier must end with .$BUNDLE_ID, got '${application_identifier:-<missing>}'"
  [[ "$application_identifier" != *".*" ]] ||
    fail "$label provisioning profile must not use a wildcard application identifier"
  [[ -n "$team_identifier" ]] ||
    fail "$label provisioning profile is missing com.apple.developer.team-identifier"
  [[ "$application_identifier" == "$team_identifier.$BUNDLE_ID" ]] ||
    fail "$label provisioning profile team identifier does not match application identifier"
  [[ "$get_task_allow" == "false" ]] ||
    fail "$label provisioning profile get-task-allow must be false for App Store distribution"
  [[ "$provisions_all_devices" != "true" ]] ||
    fail "$label provisioning profile must not be an enterprise all-devices profile"
  [[ -n "$expiration_date" ]] ||
    fail "$label provisioning profile is missing ExpirationDate"

  python3 - "$expiration_date" <<'PY' ||
import datetime
import sys

raw = sys.argv[1].strip()
try:
    expires = datetime.datetime.strptime(raw, "%a %b %d %H:%M:%S %Z %Y")
except ValueError:
    expires = datetime.datetime.fromisoformat(raw.replace("Z", "+00:00")).replace(tzinfo=None)
now = datetime.datetime.utcnow()
if expires <= now:
    raise SystemExit(1)
PY
    fail "$label provisioning profile is expired: $expiration_date"

  pass "$label embedded provisioning profile matches App Store distribution expectations"
  assert_signature_team_matches_profile "$app_path" "$label" "$team_identifier"
  assert_signed_entitlements_match_profile "$app_path" "$label" "$application_identifier" "$team_identifier" "$get_task_allow"
}

EXPECTED_MARKETING_VERSION="$(unique_project_setting MARKETING_VERSION)"
EXPECTED_BUILD_NUMBER="$(unique_project_setting CURRENT_PROJECT_VERSION)"

[[ -n "$ARCHIVE_PATH" ]] || fail "ARCHIVE_PATH is required"
[[ -d "$ARCHIVE_PATH" ]] || fail "Archive not found at $ARCHIVE_PATH"

ARCHIVE_APP="$ARCHIVE_PATH/Products/Applications/ClaraCoreMobile.app"
ARCHIVE_INFO="$ARCHIVE_PATH/Info.plist"
ARCHIVE_APP_INFO="$ARCHIVE_APP/Info.plist"
ARCHIVE_PRIVACY="$ARCHIVE_APP/PrivacyInfo.xcprivacy"
ARCHIVE_DSYM="$ARCHIVE_PATH/dSYMs/ClaraCoreMobile.app.dSYM"
ARCHIVE_APP_BINARY="$ARCHIVE_APP/ClaraCoreMobile"
ARCHIVE_DSYM_BINARY="$ARCHIVE_DSYM/Contents/Resources/DWARF/ClaraCoreMobile"

[[ -d "$ARCHIVE_APP" ]] || fail "Archived app bundle not found at $ARCHIVE_APP"
[[ -f "$ARCHIVE_INFO" ]] || fail "Archive Info.plist not found"
[[ -f "$ARCHIVE_APP_INFO" ]] || fail "Archived app Info.plist not found"
[[ -f "$ARCHIVE_PRIVACY" ]] || fail "Archived PrivacyInfo.xcprivacy not found"
[[ -d "$ARCHIVE_DSYM" ]] || fail "Archive dSYM not found at $ARCHIVE_DSYM"
pass "Signed archive structure contains app bundle, Info.plist, PrivacyInfo.xcprivacy, archive metadata, and dSYM"
assert_privacy_manifest_declarations "$ARCHIVE_PRIVACY" "signed archive"
assert_dsym_matches_binary "$ARCHIVE_APP_BINARY" "$ARCHIVE_DSYM_BINARY" "signed archive"

assert_plist_value "$ARCHIVE_APP_INFO" "CFBundleIdentifier" "$BUNDLE_ID"
assert_plist_value "$ARCHIVE_APP_INFO" "CFBundleShortVersionString" "$EXPECTED_MARKETING_VERSION"
assert_plist_value "$ARCHIVE_APP_INFO" "CFBundleVersion" "$EXPECTED_BUILD_NUMBER"
assert_plist_value "$ARCHIVE_APP_INFO" "ITSAppUsesNonExemptEncryption" "false"
assert_plist_key_absent "$ARCHIVE_APP_INFO" "UIApplicationSceneManifest"
assert_plist_value "$ARCHIVE_INFO" "ApplicationProperties:CFBundleIdentifier" "$BUNDLE_ID"
assert_plist_value_matches "$ARCHIVE_INFO" "ApplicationProperties:SigningIdentity" '^(Apple Distribution|iPhone Distribution)' "Apple Distribution signing identity"
assert_distribution_signature "$ARCHIVE_APP"
assert_embedded_profile "$ARCHIVE_APP" "archive-app"

if [[ -n "$EXPORT_PATH" ]]; then
  [[ -d "$EXPORT_PATH" ]] || fail "Export path not found at $EXPORT_PATH"
  ipa_count="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name '*.ipa' | wc -l | tr -d ' ')"
  [[ "$ipa_count" == "1" ]] || fail "EXPORT_PATH must contain exactly one .ipa, found $ipa_count"
  IPA_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name '*.ipa' | head -n 1)"
  UNZIP_DIR="$WORK_DIR/ipa"
  unzip -q "$IPA_PATH" -d "$UNZIP_DIR" || fail "Could not unzip IPA at $IPA_PATH"
  IPA_APP="$UNZIP_DIR/Payload/ClaraCoreMobile.app"
  IPA_INFO="$IPA_APP/Info.plist"
  IPA_PRIVACY="$IPA_APP/PrivacyInfo.xcprivacy"
  [[ -d "$IPA_APP" ]] || fail "IPA app bundle not found at $IPA_APP"
  [[ -f "$IPA_INFO" ]] || fail "IPA Info.plist not found"
  [[ -f "$IPA_PRIVACY" ]] || fail "IPA PrivacyInfo.xcprivacy not found"
  assert_privacy_manifest_declarations "$IPA_PRIVACY" "exported IPA"
  assert_plist_value "$IPA_INFO" "CFBundleIdentifier" "$BUNDLE_ID"
  assert_plist_value "$IPA_INFO" "CFBundleShortVersionString" "$EXPECTED_MARKETING_VERSION"
  assert_plist_value "$IPA_INFO" "CFBundleVersion" "$EXPECTED_BUILD_NUMBER"
  assert_plist_value "$IPA_INFO" "ITSAppUsesNonExemptEncryption" "false"
  assert_plist_key_absent "$IPA_INFO" "UIApplicationSceneManifest"
  assert_distribution_signature "$IPA_APP"
  assert_embedded_profile "$IPA_APP" "ipa-app"
  pass "Exported IPA metadata and signature match the signed archive expectations"
else
  pass "No EXPORT_PATH provided; skipped IPA export verification"
fi

pass "Signed App Store archive/export artifacts are ready for TestFlight upload validation"
