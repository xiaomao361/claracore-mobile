#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-}"
EXPORT_PATH="${EXPORT_PATH:-}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/docs/app-store/export-options-app-store-connect.plist}"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-1200}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claracore-mobile-export.XXXXXX")"
EXPORT_LOG="$WORK_DIR/xcodebuild-export.log"
PRESERVE_WORK_DIR=0

cleanup() {
  if [[ "$PRESERVE_WORK_DIR" == "1" ]]; then
    printf 'Export artifacts kept at: %s\n' "$WORK_DIR" >&2
    [[ -f "$EXPORT_LOG" ]] && printf 'Export log kept at: %s\n' "$EXPORT_LOG" >&2
  else
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive EXPORT_PATH=/path/to/export scripts/export_signed_app_store_archive.sh

Environment:
  ARCHIVE_PATH                  Required signed .xcarchive path.
  EXPORT_PATH                   Required output directory for exported .ipa.
  EXPORT_OPTIONS_PLIST          Export options plist. Default: docs/app-store/export-options-app-store-connect.plist
  XCODEBUILD_TIMEOUT_SECONDS    Timeout for xcodebuild -exportArchive. Default: 1200

Exports an already-created signed archive with App Store Connect export options,
then verifies the resulting archive/export artifacts. It does not upload or
submit the app.
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

[[ -n "$ARCHIVE_PATH" ]] || fail "ARCHIVE_PATH is required"
[[ -d "$ARCHIVE_PATH" ]] || fail "Archive not found at $ARCHIVE_PATH"
[[ -n "$EXPORT_PATH" ]] || fail "EXPORT_PATH is required"
[[ -f "$EXPORT_OPTIONS_PLIST" ]] || fail "Export options plist not found at $EXPORT_OPTIONS_PLIST"

mkdir -p "$EXPORT_PATH"

if ! "$ROOT_DIR/scripts/run_xcodebuild_with_timeout.sh" "$XCODEBUILD_TIMEOUT_SECONDS" "$EXPORT_LOG" -- \
  xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"; then
  tail -n 160 "$EXPORT_LOG" >&2
  fail "App Store Connect export failed or timed out after ${XCODEBUILD_TIMEOUT_SECONDS}s. Full log: $EXPORT_LOG"
fi

pass "Signed archive exported for App Store Connect at $EXPORT_PATH"
ARCHIVE_PATH="$ARCHIVE_PATH" EXPORT_PATH="$EXPORT_PATH" "$ROOT_DIR/scripts/verify_signed_app_store_artifacts.sh"
