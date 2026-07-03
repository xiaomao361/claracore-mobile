#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
SCHEME="ClaraCoreMobile"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-readiness.XXXXXX")"

cleanup() {
  rm -rf "$DERIVED_DATA"
}
trap cleanup EXIT

log() {
  printf '\n==> %s\n' "$1"
}

pass() {
  printf 'OK: %s\n' "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

assert_http_200() {
  local url="$1"
  local status
  status="$(curl -L -s -o /dev/null -w '%{http_code}' "$url")"
  [[ "$status" == "200" ]] || fail "$url returned HTTP $status"
  pass "$url returned HTTP 200"
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

assert_sips_property() {
  local image="$1"
  local property="$2"
  local expected="$3"
  local actual
  actual="$(sips -g "$property" "$image" 2>/dev/null | awk -F': ' -v key="$property" '$1 ~ key { print $2; exit }')"
  [[ "$actual" == "$expected" ]] || fail "$image $property expected '$expected' but got '${actual:-<missing>}'"
  pass "$image $property = $expected"
}

cd "$ROOT_DIR"

log "Checking public support and privacy URLs"
assert_http_200 "https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/privacy-policy.md"
assert_http_200 "https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/support.md"

log "Linting plist and project files"
plutil -lint \
  "$ROOT_DIR/ClaraCoreMobile/PrivacyInfo.xcprivacy" \
  "$ROOT_DIR/ClaraCoreMobile.xcodeproj/project.pbxproj" >/dev/null
pass "Privacy manifest and Xcode project plist syntax are valid"

log "Checking privacy manifest declarations"
assert_plist_value "$ROOT_DIR/ClaraCoreMobile/PrivacyInfo.xcprivacy" "NSPrivacyTracking" "false"
assert_plist_value "$ROOT_DIR/ClaraCoreMobile/PrivacyInfo.xcprivacy" "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType" "NSPrivacyAccessedAPICategoryUserDefaults"
assert_plist_value "$ROOT_DIR/ClaraCoreMobile/PrivacyInfo.xcprivacy" "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0" "CA92.1"

log "Checking App Store icon asset"
APP_ICON="$ROOT_DIR/ClaraCoreMobile/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
[[ -f "$APP_ICON" ]] || fail "App Store icon not found at $APP_ICON"
assert_sips_property "$APP_ICON" "pixelWidth" "1024"
assert_sips_property "$APP_ICON" "pixelHeight" "1024"
assert_sips_property "$APP_ICON" "hasAlpha" "no"

log "Scanning committed source for common real API key patterns"
if rg -n --hidden \
  -g '!/.git/**' \
  -g '!*.xcresult/**' \
  -g '!DerivedData/**' \
  -e 'sk-proj-[A-Za-z0-9_-]{20,}' \
  -e 'sk-[A-Za-z0-9_-]{20,}' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'AIza[0-9A-Za-z_-]{35}' \
  "$ROOT_DIR"; then
  fail "Potential real API key pattern found. Remove secrets before submission."
fi
pass "No common real API key patterns found"

log "Building Release simulator app with App Store validation"
BUILD_LOG="$DERIVED_DATA/xcodebuild-release.log"
if ! xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  build >"$BUILD_LOG"; then
  tail -n 120 "$BUILD_LOG" >&2
  fail "Release simulator build failed. Full log: $BUILD_LOG"
fi
pass "Release simulator build succeeded"

APP_PATH="$DERIVED_DATA/Build/Products/Release-iphonesimulator/ClaraCoreMobile.app"
INFO_PLIST="$APP_PATH/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"

[[ -d "$APP_PATH" ]] || fail "Built app bundle not found at $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "Built Info.plist not found"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "Built PrivacyInfo.xcprivacy not found"
pass "Built bundle contains Info.plist and PrivacyInfo.xcprivacy"

log "Checking built app metadata"
assert_plist_value "$INFO_PLIST" "CFBundleIdentifier" "com.claracore.mobile"
assert_plist_value "$INFO_PLIST" "CFBundleShortVersionString" "0.1.0"
assert_plist_value "$INFO_PLIST" "CFBundleVersion" "1"
assert_plist_value "$INFO_PLIST" "ITSAppUsesNonExemptEncryption" "false"

log "App Store readiness checks passed"
