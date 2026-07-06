#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_release_artifacts_tracked.sh

Checks that release-critical source, test, script, screenshot, and public App
Store material files are tracked by Git. This script does not stage, commit,
push, or mutate the worktree.

Run this before publishing docs, creating a release branch, or treating the final
submission gate as upload-ready. Untracked local files can pass local checks but
will be missing from GitHub fallback URLs, GitHub Pages, fresh clones, or another
Mac used for signing.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

pass() {
  printf 'OK: %s\n' "$1"
}

failures=()

require_tracked() {
  local path="$1"
  if git -C "$ROOT_DIR" ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    pass "$path is tracked"
  else
    failures+=("$path")
  fi
}

required_paths=(
  "ClaraCoreMobile/App/AppStoreScreenshotFixtureSeeder.swift"
  "ClaraCoreMobile/Core/Reflection/LocalOrganizationRulebook.swift"
  "ClaraCoreMobileTests/Core/Database/AppDatabaseTests.swift"
  "docs/app-store/app-privacy-labels.md"
  "docs/app-store/export-options-app-store-connect.plist"
  "docs/app-store/screenshot-plan.md"
  "docs/app-store/screenshots/manifest.txt"
  "docs/app-store/screenshots/iphone-6.9/01-import.png"
  "docs/app-store/screenshots/iphone-6.9/02-settings-model.png"
  "docs/app-store/screenshots/iphone-6.9/03-import-result.png"
  "docs/app-store/screenshots/iphone-6.9/04-archive.png"
  "docs/app-store/screenshots/iphone-6.9/05-memory.png"
  "docs/app-store/screenshots/iphone-6.9/06-shared-line.png"
  "docs/app-store/screenshots/iphone-6.9/07-recall-package.png"
  "docs/app-store/screenshots/iphone-6.9/08-settings-support.png"
  "docs/app-store/screenshots/ipad-13/01-import.png"
  "docs/app-store/screenshots/ipad-13/02-settings-model.png"
  "docs/app-store/screenshots/ipad-13/03-import-result.png"
  "docs/app-store/screenshots/ipad-13/04-archive.png"
  "docs/app-store/screenshots/ipad-13/05-memory.png"
  "docs/app-store/screenshots/ipad-13/06-shared-line.png"
  "docs/app-store/screenshots/ipad-13/07-recall-package.png"
  "docs/app-store/screenshots/ipad-13/08-settings-support.png"
  "scripts/capture_app_store_screenshots.sh"
  "scripts/export_signed_app_store_archive.sh"
  "scripts/run_xcodebuild_with_timeout.sh"
  "scripts/set_app_version.sh"
  "scripts/smoke_simulator_launch.sh"
  "scripts/verify_app_store_archive.sh"
  "scripts/verify_app_store_screenshots.sh"
  "scripts/verify_app_store_signing_prerequisites.sh"
  "scripts/verify_app_store_submission_ready.sh"
  "scripts/verify_device_release_build.sh"
  "scripts/verify_public_app_store_docs.sh"
  "scripts/verify_release_artifacts_tracked.sh"
  "scripts/verify_release_worktree_clean.sh"
  "scripts/verify_signed_app_store_artifacts.sh"
  "scripts/verify_unit_tests.sh"
)

for path in "${required_paths[@]}"; do
  require_tracked "$path"
done

if ((${#failures[@]} > 0)); then
  printf 'ERROR: Release-critical files are not tracked by Git:\n' >&2
  for path in "${failures[@]}"; do
    printf '  - %s\n' "$path" >&2
  done
  printf 'Next action: when you are ready for a release checkpoint, stage and commit these files once, then publish the docs/materials. This script did not modify Git.\n' >&2
  exit 1
fi

pass "Release-critical source, tests, scripts, screenshots, and App Store materials are tracked by Git"
