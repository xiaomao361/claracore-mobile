#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/ClaraCoreMobile.xcodeproj/project.pbxproj"

usage() {
  cat <<'EOF'
Usage:
  scripts/set_app_version.sh <marketing-version> <build-number>
  scripts/set_app_version.sh --check <marketing-version> <build-number>

Examples:
  scripts/set_app_version.sh 0.1.0 2
  scripts/set_app_version.sh --check 0.1.0 1
EOF
}

mode="set"
if [[ "${1:-}" == "--check" ]]; then
  mode="check"
  shift
fi

if [[ "$#" -ne 2 ]]; then
  usage >&2
  exit 2
fi

marketing_version="$1"
build_number="$2"

[[ "$marketing_version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || {
  echo "ERROR: marketing version must look like 0.1.0 or 1.0" >&2
  exit 1
}

[[ "$build_number" =~ ^[0-9]+$ ]] || {
  echo "ERROR: build number must be a positive integer" >&2
  exit 1
}

[[ "$build_number" -gt 0 ]] || {
  echo "ERROR: build number must be greater than zero" >&2
  exit 1
}

unique_project_setting() {
  local key="$1"
  local values
  values="$(awk -v key="$key" '$1 == key { value = $3; gsub(/;/, "", value); print value }' "$PROJECT_FILE" | sort -u)"
  local count
  count="$(printf '%s\n' "$values" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" != "1" ]]; then
    echo "ERROR: $key must have exactly one value across project configurations, got: ${values:-<none>}" >&2
    exit 1
  fi
  printf '%s\n' "$values"
}

if [[ "$mode" == "check" ]]; then
  current_marketing="$(unique_project_setting MARKETING_VERSION)"
  current_build="$(unique_project_setting CURRENT_PROJECT_VERSION)"
  [[ "$current_marketing" == "$marketing_version" ]] || {
    echo "ERROR: MARKETING_VERSION is $current_marketing, expected $marketing_version" >&2
    exit 1
  }
  [[ "$current_build" == "$build_number" ]] || {
    echo "ERROR: CURRENT_PROJECT_VERSION is $current_build, expected $build_number" >&2
    exit 1
  }
  echo "OK: MARKETING_VERSION=$marketing_version CURRENT_PROJECT_VERSION=$build_number"
  exit 0
fi

perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $marketing_version;/g; s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $build_number;/g" "$PROJECT_FILE"

"$0" --check "$marketing_version" "$build_number"
echo "Updated ClaraCoreMobile.xcodeproj to MARKETING_VERSION=$marketing_version CURRENT_PROJECT_VERSION=$build_number"
