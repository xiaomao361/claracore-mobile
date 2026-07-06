#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/ClaraCoreMobile.xcodeproj/project.pbxproj"
SCREENSHOT_DIR="${1:-$ROOT_DIR/docs/app-store/screenshots}"
IPHONE_DIR="$SCREENSHOT_DIR/iphone-6.9"
IPAD_DIR="$SCREENSHOT_DIR/ipad-13"
MANIFEST="$SCREENSHOT_DIR/manifest.txt"
MIN_SCREENSHOTS_PER_DEVICE="${MIN_SCREENSHOTS_PER_DEVICE:-1}"
FINAL_SCREENSHOT_SEQUENCE="01-import,02-settings-model,03-import-result,04-archive,05-memory,06-shared-line,07-recall-package,08-settings-support"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_app_store_screenshots.sh [screenshot-dir]

Expected layout:
  docs/app-store/screenshots/
    iphone-6.9/
      01-import.png
      02-settings-model.png
      ...
    ipad-13/
      01-import.png
      02-settings-model.png
      ...
    manifest.txt

Each device set must contain 1 to 10 .png, .jpg, or .jpeg files.
Set MIN_SCREENSHOTS_PER_DEVICE=8 for the final upload-ready screenshot package.
When MIN_SCREENSHOTS_PER_DEVICE is 8 or higher, each device set must include:
  01-import, 02-settings-model, 03-import-result, 04-archive,
  05-memory, 06-shared-line, 07-recall-package, 08-settings-support
Accepted portrait sizes:
  iPhone 6.9-inch: 1320x2868, 1290x2796, 1260x2736
  iPad 13-inch:    2064x2752, 2048x2732

manifest.txt must match the current MARKETING_VERSION and CURRENT_PROJECT_VERSION.
Screenshots are also sampled with ImageIO to reject blank, transparent, or
single-color captures before upload. Final packages also reject duplicate
pixel signatures within each device set.
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
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

image_property() {
  local image="$1"
  local property="$2"
  sips -g "$property" "$image" 2>/dev/null | awk -F': ' -v key="$property" '$1 ~ key { print $2; exit }'
}

image_content_signature() {
  local label="$1"
  local image="$2"

  xcrun swift - "$label" "$image" <<'SWIFT'
import Foundation
import ImageIO
import CoreGraphics

let label = CommandLine.arguments[1]
let path = CommandLine.arguments[2]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    exit(1)
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("\(label) screenshot is not readable by ImageIO: \(path)")
}

let width = image.width
let height = image.height
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fail("\(label) screenshot could not be decoded for duplicate validation")
}

context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

let stepX = max(1, width / 64)
let stepY = max(1, height / 64)
var hash: UInt64 = 1469598103934665603

func mix(_ value: UInt8) {
    hash ^= UInt64(value)
    hash = hash &* 1099511628211
}

for y in stride(from: 0, to: height, by: stepY) {
    for x in stride(from: 0, to: width, by: stepX) {
        let offset = y * bytesPerRow + x * bytesPerPixel
        mix(pixels[offset])
        mix(pixels[offset + 1])
        mix(pixels[offset + 2])
        mix(pixels[offset + 3])
    }
}

print(String(hash, radix: 16))
SWIFT
}

assert_no_duplicate_screenshot_content() {
  local label="$1"
  shift
  local -a files=("$@")

  (( MIN_SCREENSHOTS_PER_DEVICE >= 8 )) || return 0

  local seen_file
  seen_file="$(mktemp "${TMPDIR:-/tmp}/claracore-screenshot-signatures.XXXXXX")"
  trap 'rm -f "$seen_file"' RETURN

  local file basename signature existing
  for file in "${files[@]}"; do
    basename="$(basename "$file")"
    signature="$(image_content_signature "$label $basename" "$file")"
    existing="$(awk -F'\t' -v signature="$signature" '$1 == signature { print $2; exit }' "$seen_file")"
    if [[ -n "$existing" ]]; then
      rm -f "$seen_file"
      fail "$label final screenshot package contains duplicate screenshot content: $basename duplicates $existing"
    fi
    printf '%s\t%s\n' "$signature" "$basename" >>"$seen_file"
  done

  rm -f "$seen_file"
  trap - RETURN
  pass "$label final screenshot package has no duplicate screenshot content"
}

assert_screenshot_content() {
  local label="$1"
  local image="$2"

  xcrun swift - "$label" "$image" <<'SWIFT'
import Foundation
import ImageIO
import CoreGraphics

let label = CommandLine.arguments[1]
let path = CommandLine.arguments[2]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    exit(1)
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("\(label) screenshot is not readable by ImageIO: \(path)")
}

let width = image.width
let height = image.height
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fail("\(label) screenshot could not be decoded for content validation")
}

context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

let stepX = max(1, width / 80)
let stepY = max(1, height / 80)
var samples = 0
var opaqueSamples = 0
var minLuminance = 255
var maxLuminance = 0
var colorBuckets = Set<Int>()

for y in stride(from: 0, to: height, by: stepY) {
    for x in stride(from: 0, to: width, by: stepX) {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        let alpha = Int(pixels[offset + 3])
        let luminance = (red * 299 + green * 587 + blue * 114) / 1000

        samples += 1
        if alpha > 16 {
            opaqueSamples += 1
        }
        minLuminance = min(minLuminance, luminance)
        maxLuminance = max(maxLuminance, luminance)
        colorBuckets.insert((red / 16) << 8 | (green / 16) << 4 | (blue / 16))
    }
}

let opaqueRatio = Double(opaqueSamples) / Double(max(samples, 1))
let luminanceRange = maxLuminance - minLuminance

if opaqueRatio < 0.98 {
    fail("\(label) screenshot appears transparent or partially missing: opaque sample ratio \(String(format: "%.3f", opaqueRatio))")
}
if luminanceRange < 24 || colorBuckets.count < 8 {
    fail("\(label) screenshot appears blank or single-color: luminance range \(luminanceRange), color buckets \(colorBuckets.count)")
}
SWIFT
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

manifest_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$MANIFEST"
}

assert_manifest() {
  [[ -f "$MANIFEST" ]] || fail "Screenshot manifest is missing at $MANIFEST; regenerate screenshots with scripts/capture_app_store_screenshots.sh"

  local expected_marketing expected_build
  expected_marketing="$(unique_project_setting MARKETING_VERSION)"
  expected_build="$(unique_project_setting CURRENT_PROJECT_VERSION)"

  [[ "$(manifest_value MARKETING_VERSION)" == "$expected_marketing" ]] || fail "Screenshot manifest MARKETING_VERSION must be $expected_marketing"
  [[ "$(manifest_value CURRENT_PROJECT_VERSION)" == "$expected_build" ]] || fail "Screenshot manifest CURRENT_PROJECT_VERSION must be $expected_build"
  [[ "$(manifest_value CONFIGURATION)" == "Release" ]] || fail "Screenshot manifest CONFIGURATION must be Release for App Store upload"
  [[ "$(manifest_value BUNDLE_ID)" == "com.claracore.mobile" ]] || fail "Screenshot manifest BUNDLE_ID must be com.claracore.mobile"
  [[ "$(manifest_value IPHONE_SCREENSHOT)" == "iphone-6.9/01-import.png" ]] || fail "Screenshot manifest must record the iPhone screenshot path"
  [[ "$(manifest_value IPAD_SCREENSHOT)" == "ipad-13/01-import.png" ]] || fail "Screenshot manifest must record the iPad screenshot path"
  if (( MIN_SCREENSHOTS_PER_DEVICE >= 8 )); then
    [[ "$(manifest_value SCREENSHOT_SEQUENCE)" == "$FINAL_SCREENSHOT_SEQUENCE" ]] || fail "Screenshot manifest SCREENSHOT_SEQUENCE must be $FINAL_SCREENSHOT_SEQUENCE for the final package"
  fi
  pass "Screenshot manifest matches current project version and Release configuration"
}

assert_min_screenshot_count_setting() {
  [[ "$MIN_SCREENSHOTS_PER_DEVICE" =~ ^[0-9]+$ ]] || fail "MIN_SCREENSHOTS_PER_DEVICE must be an integer"
  (( MIN_SCREENSHOTS_PER_DEVICE >= 1 )) || fail "MIN_SCREENSHOTS_PER_DEVICE must be at least 1"
  (( MIN_SCREENSHOTS_PER_DEVICE <= 10 )) || fail "MIN_SCREENSHOTS_PER_DEVICE must be at most 10"
}

assert_final_screenshot_sequence() {
  local label="$1"
  local dir="$2"
  local required_stems=(
    "01-import"
    "02-settings-model"
    "03-import-result"
    "04-archive"
    "05-memory"
    "06-shared-line"
    "07-recall-package"
    "08-settings-support"
  )

  (( MIN_SCREENSHOTS_PER_DEVICE >= 8 )) || return 0

  local stem matches count
  for stem in "${required_stems[@]}"; do
    matches=()
    while IFS= read -r -d '' file; do
      matches+=("$file")
    done < <(find "$dir" -maxdepth 1 -type f \( -iname "$stem.png" -o -iname "$stem.jpg" -o -iname "$stem.jpeg" \) -print0)
    count="${#matches[@]}"
    [[ "$count" == "1" ]] || fail "$label final screenshot package must contain exactly one $stem image; found $count"
  done

  pass "$label final screenshot sequence covers the required first-release screens"
}

assert_screenshot_set() {
  local label="$1"
  local dir="$2"
  local accepted_sizes="$3"

  [[ -d "$dir" ]] || fail "$label screenshot directory is missing: $dir"

  local -a files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0 | sort -z)

  local count="${#files[@]}"
  (( count >= MIN_SCREENSHOTS_PER_DEVICE )) || fail "$label must contain at least $MIN_SCREENSHOTS_PER_DEVICE screenshot(s) for this gate; found $count"
  (( count <= 10 )) || fail "$label has $count screenshots; App Store Connect allows at most 10"
  assert_final_screenshot_sequence "$label" "$dir"
  assert_no_duplicate_screenshot_content "$label" "${files[@]}"

  local file
  for file in "${files[@]}"; do
    local width height size basename
    width="$(image_property "$file" pixelWidth)"
    height="$(image_property "$file" pixelHeight)"
    basename="$(basename "$file")"
    [[ -n "$width" && -n "$height" ]] || fail "$file is not a readable image"
    size="${width}x${height}"
    case " $accepted_sizes " in
      *" $size "*) ;;
      *) fail "$label screenshot $basename is ${size}; accepted sizes: $accepted_sizes" ;;
    esac
    assert_screenshot_content "$label $basename" "$file"
  done

  pass "$label has $count valid nonblank screenshots"
}

assert_min_screenshot_count_setting
assert_manifest
assert_screenshot_set "iPhone 6.9-inch" "$IPHONE_DIR" "1320x2868 1290x2796 1260x2736"
assert_screenshot_set "iPad 13-inch" "$IPAD_DIR" "2064x2752 2048x2732"
pass "App Store screenshot files are ready for upload"
