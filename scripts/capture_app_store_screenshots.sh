#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ClaraCoreMobile.xcodeproj"
PROJECT_FILE="$PROJECT_PATH/project.pbxproj"
SCHEME="ClaraCoreMobile"
BUNDLE_ID="com.claracore.mobile"
CONFIGURATION="${CONFIGURATION:-Release}"
IPHONE_SIMULATOR_NAME="${IPHONE_SIMULATOR_NAME:-iPhone 17 Pro Max}"
IPAD_SIMULATOR_NAME="${IPAD_SIMULATOR_NAME:-iPad Pro 13-inch (M5)}"
IPHONE_SIMULATOR_ID="${IPHONE_SIMULATOR_ID:-}"
IPAD_SIMULATOR_ID="${IPAD_SIMULATOR_ID:-}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/docs/app-store/screenshots}"
SCREENSHOT_DELAY="${SCREENSHOT_DELAY:-3}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$ROOT_DIR/.xcode-source-packages}"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-screenshots.XXXXXX")"
BUILD_LOG="$DERIVED_DATA/xcodebuild-${CONFIGURATION}.log"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-900}"
PRESERVE_DERIVED_DATA=0
FINAL_SCREENSHOT_SEQUENCE="01-import,02-settings-model,03-import-result,04-archive,05-memory,06-shared-line,07-recall-package,08-settings-support"

cleanup() {
  if [[ -n "${IPHONE_SIMULATOR_ID:-}" ]]; then
    xcrun simctl terminate "$IPHONE_SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${IPAD_SIMULATOR_ID:-}" ]]; then
    xcrun simctl terminate "$IPAD_SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi
  if [[ "$PRESERVE_DERIVED_DATA" == "1" ]]; then
    printf 'Screenshot capture artifacts kept at: %s\n' "$DERIVED_DATA" >&2
  else
    rm -rf "$DERIVED_DATA"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  scripts/capture_app_store_screenshots.sh

Environment:
  CONFIGURATION            Xcode build configuration. Default: Release
  IPHONE_SIMULATOR_ID      Optional iPhone simulator UDID.
  IPHONE_SIMULATOR_NAME    iPhone simulator name when no UDID is provided. Default: iPhone 17 Pro Max
  IPAD_SIMULATOR_ID        Optional iPad simulator UDID.
  IPAD_SIMULATOR_NAME      iPad simulator name when no UDID is provided. Default: iPad Pro 13-inch (M5)
  SCREENSHOT_DIR           Output root. Default: docs/app-store/screenshots
  SCREENSHOT_DELAY         Seconds to wait after app launch before capture. Default: 3
  SOURCE_PACKAGES_DIR      Reused SwiftPM package checkout/cache directory. Default: .xcode-source-packages
  XCODEBUILD_TIMEOUT_SECONDS
                           Timeout for xcodebuild build. Default: 900

The script builds ClaraCore Mobile once for iOS Simulator, installs it on the
selected iPhone and iPad simulators, launches it in screenshot fixture mode,
captures the full first-release screenshot sequence, and writes a
manifest that records the full required final screenshot sequence. Screenshot
fixture mode seeds safe sample model configuration, Archive, Memory, and Shared
Line data so every required screenshot can be captured from real app UI without
private user material. Review or replace the generated screenshots if the UI
changes, then run:
  MIN_SCREENSHOTS_PER_DEVICE=8 scripts/verify_app_store_screenshots.sh
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

unique_project_setting() {
  local key="$1"
  local values
  values="$(awk -v key="$key" '$1 == key { value = $3; gsub(/;/, "", value); print value }' "$PROJECT_FILE" | sort -u)"
  local count
  count="$(printf '%s\n' "$values" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$count" == "1" ]] || fail "$key must have exactly one value across project configurations, got: ${values:-<none>}"
  printf '%s\n' "$values"
}

find_simulator_id() {
  local name="$1"
  xcrun simctl list devices available |
    sed -n "s/^[[:space:]]*${name} (\([0-9A-F-]*\)) (.*/\1/p" |
    head -n 1
}

boot_simulator() {
  local id="$1"
  xcrun simctl boot "$id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$id" -b >/dev/null
}

install_launch_capture() {
  local label="$1"
  local simulator_id="$2"
  local app_path="$3"
  local output_path="$4"
  local tab="$5"

  xcrun simctl uninstall "$simulator_id" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$simulator_id" "$app_path"
  SIMCTL_CHILD_CLARACORE_SCREENSHOT_MODE=1 \
    SIMCTL_CHILD_CLARACORE_SCREENSHOT_TAB="$tab" \
    xcrun simctl launch "$simulator_id" "$BUNDLE_ID" >/dev/null
  sleep "$SCREENSHOT_DELAY"
  mkdir -p "$(dirname "$output_path")"
  xcrun simctl io "$simulator_id" screenshot "$output_path" >/dev/null
  pass "Captured $label screenshot at $output_path"
}

capture_device_set() {
  local label="$1"
  local simulator_id="$2"
  local app_path="$3"
  local output_dir="$4"

  install_launch_capture "$label 01-import" "$simulator_id" "$app_path" "$output_dir/01-import.png" "import"
  install_launch_capture "$label 02-settings-model" "$simulator_id" "$app_path" "$output_dir/02-settings-model.png" "settings"
  install_launch_capture "$label 03-import-result" "$simulator_id" "$app_path" "$output_dir/03-import-result.png" "import-result"
  install_launch_capture "$label 04-archive" "$simulator_id" "$app_path" "$output_dir/04-archive.png" "archive"
  install_launch_capture "$label 05-memory" "$simulator_id" "$app_path" "$output_dir/05-memory.png" "memory"
  install_launch_capture "$label 06-shared-line" "$simulator_id" "$app_path" "$output_dir/06-shared-line.png" "shared-line"
  install_launch_capture "$label 07-recall-package" "$simulator_id" "$app_path" "$output_dir/07-recall-package.png" "recall-package"
  install_launch_capture "$label 08-settings-support" "$simulator_id" "$app_path" "$output_dir/08-settings-support.png" "settings-support"
}

if [[ -z "$IPHONE_SIMULATOR_ID" ]]; then
  IPHONE_SIMULATOR_ID="$(find_simulator_id "$IPHONE_SIMULATOR_NAME")"
fi
if [[ -z "$IPAD_SIMULATOR_ID" ]]; then
  IPAD_SIMULATOR_ID="$(find_simulator_id "$IPAD_SIMULATOR_NAME")"
fi
[[ -n "$IPHONE_SIMULATOR_ID" ]] || fail "No available iPhone simulator found for IPHONE_SIMULATOR_NAME='$IPHONE_SIMULATOR_NAME'"
[[ -n "$IPAD_SIMULATOR_ID" ]] || fail "No available iPad simulator found for IPAD_SIMULATOR_NAME='$IPAD_SIMULATOR_NAME'"

pass "Using iPhone simulator $IPHONE_SIMULATOR_ID"
pass "Using iPad simulator $IPAD_SIMULATOR_ID"

boot_simulator "$IPHONE_SIMULATOR_ID"
boot_simulator "$IPAD_SIMULATOR_ID"
pass "Simulators are booted"
mkdir -p "$SOURCE_PACKAGES_DIR"

if ! "$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh" "$XCODEBUILD_TIMEOUT_SECONDS" "$BUILD_LOG" -- \
  xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  build; then
  tail -n 120 "$BUILD_LOG" >&2
  fail "Screenshot build failed or timed out after ${XCODEBUILD_TIMEOUT_SECONDS}s. Full log: $BUILD_LOG"
fi
pass "$CONFIGURATION simulator build succeeded"

EXPECTED_MARKETING_VERSION="$(unique_project_setting MARKETING_VERSION)"
EXPECTED_BUILD_NUMBER="$(unique_project_setting CURRENT_PROJECT_VERSION)"

APP_PATH="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphonesimulator/ClaraCoreMobile.app"
[[ -d "$APP_PATH" ]] || fail "Built app bundle not found at $APP_PATH"

capture_device_set "iPhone 6.9-inch" "$IPHONE_SIMULATOR_ID" "$APP_PATH" "$SCREENSHOT_DIR/iphone-6.9"
capture_device_set "iPad 13-inch" "$IPAD_SIMULATOR_ID" "$APP_PATH" "$SCREENSHOT_DIR/ipad-13"

cat >"$SCREENSHOT_DIR/manifest.txt" <<EOF
# ClaraCore Mobile App Store screenshot manifest
MARKETING_VERSION=$EXPECTED_MARKETING_VERSION
CURRENT_PROJECT_VERSION=$EXPECTED_BUILD_NUMBER
CONFIGURATION=$CONFIGURATION
BUNDLE_ID=$BUNDLE_ID
GENERATED_AT_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
IPHONE_SIMULATOR_ID=$IPHONE_SIMULATOR_ID
IPAD_SIMULATOR_ID=$IPAD_SIMULATOR_ID
SCREENSHOT_SEQUENCE=$FINAL_SCREENSHOT_SEQUENCE
AUTO_CAPTURED_SCREENSHOTS=01-import,02-settings-model,03-import-result,04-archive,05-memory,06-shared-line,07-recall-package,08-settings-support
IPHONE_SCREENSHOT=iphone-6.9/01-import.png
IPAD_SCREENSHOT=ipad-13/01-import.png
EOF
pass "Wrote screenshot manifest at $SCREENSHOT_DIR/manifest.txt"

"$ROOT_DIR/scripts/verify_app_store_screenshots.sh" "$SCREENSHOT_DIR"
