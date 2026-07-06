#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METADATA="$ROOT_DIR/docs/app-store/app-store-connect-metadata.md"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify_public_app_store_docs.sh

Fetches the Privacy Policy URL and Support URL from App Store Connect metadata
and checks that the public pages contain the release-critical privacy/support
claims from the local App Store materials. When the metadata uses GitHub blob
fallback URLs, it also checks that the public App Store material files match
the local release documents.

Run this after publishing updated docs and before submitting to App Review.
It is intentionally separate from the local readiness gate because local-only
work can pass while public GitHub/GitHub Pages content is still stale.

When the metadata uses GitHub blob fallback URLs, this also requires the public
raw files to exactly match the local release documents.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

python3 - "$METADATA" <<'PY'
import hashlib
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

metadata_path = Path(sys.argv[1])
root_dir = metadata_path.parents[2]
metadata = metadata_path.read_text(encoding="utf-8")
failures: list[str] = []


def record_failure(message: str) -> None:
    failures.append(message)


def finish() -> None:
    if failures:
        print("ERROR: Public App Store documents are not ready:", file=sys.stderr)
        for failure in failures:
            print(failure, file=sys.stderr)
        sys.exit(1)


def extract_labeled_block(label: str) -> str:
    pattern = rf"{re.escape(label)}:\n\n```text\n(.*?)\n```"
    match = re.search(pattern, metadata, re.DOTALL)
    if not match:
        record_failure(f"- Missing metadata field: {label}")
        finish()
    return match.group(1).strip()


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": "ClaraCoreMobileReleaseCheck/1.0"})
    try:
        with urlopen(request, timeout=30) as response:
            status = getattr(response, "status", None)
            if status != 200:
                raise RuntimeError(f"{url} returned HTTP {status}")
            return response.read().decode("utf-8", errors="replace")
    except HTTPError as exc:
        raise RuntimeError(f"{url} returned HTTP {exc.code}") from exc
    except URLError as exc:
        raise RuntimeError(f"{url} could not be fetched: {exc.reason}") from exc


def raw_github_url(url: str) -> str:
    match = re.fullmatch(r"https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)", url)
    if not match:
        return url
    owner, repo, branch, path = match.groups()
    return f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}"


def github_blob_path(url: str) -> Path | None:
    match = re.fullmatch(r"https://github\.com/[^/]+/[^/]+/blob/[^/]+/(.+)", url)
    if not match:
        return None
    return root_dir / match.group(1)


def github_blob_parts(url: str) -> tuple[str, str, str] | None:
    match = re.fullmatch(r"https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/.+", url)
    if not match:
        return None
    return match.groups()


def github_blob_url_like(reference_url: str, relative_path: str) -> str | None:
    parts = github_blob_parts(reference_url)
    if parts is None:
        return None
    owner, repo, branch = parts
    return f"https://github.com/{owner}/{repo}/blob/{branch}/{relative_path}"


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def require_all(label: str, text: str, needles: list[str]) -> None:
    missing = [needle for needle in needles if needle not in text]
    if missing:
        formatted = "\n".join(f"  - {needle}" for needle in missing)
        record_failure(f"- {label} public content is stale or incomplete. Missing:\n{formatted}")
    else:
        print(f"OK: {label} public content includes release-critical claims")


def require_absent(label: str, text: str, needles: list[str]) -> None:
    present = [needle for needle in needles if needle in text]
    if present:
        formatted = "\n".join(f"  - {needle}" for needle in present)
        record_failure(f"- {label} public content contains disallowed App Store positioning:\n{formatted}")
    else:
        print(f"OK: {label} public content avoids disallowed App Store positioning")


def require_exact_github_match(label: str, public_url: str, public_text: str) -> None:
    local_path = github_blob_path(public_url)
    if local_path is None:
        print(f"OK: {label} URL is not a GitHub blob fallback; exact markdown match skipped")
        return
    if not local_path.is_file():
        record_failure(f"- {label} local document for public URL is missing: {local_path}")
        return

    local_text = local_path.read_text(encoding="utf-8")
    if public_text != local_text:
        record_failure(
            f"- {label} public GitHub fallback does not exactly match local release document "
            f"{local_path.relative_to(root_dir)} "
            f"(local sha256 {sha256(local_text)}, public sha256 {sha256(public_text)})"
        )
    else:
        print(f"OK: {label} public GitHub fallback exactly matches local release document")


def require_exact_github_material(reference_url: str, label: str, relative_path: str) -> None:
    public_url = github_blob_url_like(reference_url, relative_path)
    if public_url is None:
        print(f"OK: {label} exact material match skipped because metadata does not use a GitHub blob fallback")
        return
    local_path = root_dir / relative_path
    if not local_path.is_file():
        record_failure(f"- {label} local release material is missing: {relative_path}")
        return
    try:
        public_text = fetch(raw_github_url(public_url))
    except RuntimeError as exc:
        record_failure(f"- {label} public release material is missing or unreachable: {exc}")
        return
    local_text = local_path.read_text(encoding="utf-8")
    if public_text != local_text:
        record_failure(
            f"- {label} public GitHub fallback does not exactly match local release material "
            f"{relative_path} "
            f"(local sha256 {sha256(local_text)}, public sha256 {sha256(public_text)})"
        )
    else:
        print(f"OK: {label} public GitHub fallback exactly matches local release material")


privacy_url = extract_labeled_block("Privacy Policy URL")
support_url = extract_labeled_block("Support URL")

try:
    privacy_public = fetch(raw_github_url(privacy_url))
    support_public = fetch(raw_github_url(support_url))
except RuntimeError as exc:
    record_failure(f"- {exc}")
    finish()

require_exact_github_match("Privacy Policy", privacy_url, privacy_public)
require_exact_github_match("Support", support_url, support_public)

for label, relative_path in [
    ("App Store materials index", "docs/app-store/index.md"),
    ("App Store Connect metadata", "docs/app-store/app-store-connect-metadata.md"),
    ("App Store submission checklist", "docs/app-store/app-store-submission.md"),
    ("App Privacy labels", "docs/app-store/app-privacy-labels.md"),
    ("Screenshot plan", "docs/app-store/screenshot-plan.md"),
    ("App Store Connect export options", "docs/app-store/export-options-app-store-connect.plist"),
]:
    require_exact_github_material(privacy_url, label, relative_path)

require_all(
    "Privacy Policy",
    privacy_public,
    [
        "Effective date: July 3, 2026",
        "ThisDeviceOnly iOS Keychain",
        "Application Support container",
        "excluded from iCloud and iTunes backups",
        "Copying or sharing a complete original Archive entry",
    ],
)
require_all(
    "Support",
    support_public,
    [
        "Copy Diagnostics",
        "non-sensitive organization engine status",
        "does not include API keys",
        "provider names, Base URLs, model names, or model provider configuration",
        "local-rule mode",
        "copies/shares a complete original Archive entry",
    ],
)

disallowed_ai_positioning = [
    "third-party AI processing notice",
    "third-party AI consent",
    "AI processing",
    "第三方 AI",
    "AI 处理",
    "AI 应用",
    "AI 对话",
    "外部 AI",
]

require_absent("Privacy Policy", privacy_public, disallowed_ai_positioning)
require_absent("Support", support_public, disallowed_ai_positioning)

for label, relative_path in [
    ("App Store materials index", "docs/app-store/index.md"),
    ("App Store Connect metadata", "docs/app-store/app-store-connect-metadata.md"),
    ("App Store submission checklist", "docs/app-store/app-store-submission.md"),
    ("App Privacy labels", "docs/app-store/app-privacy-labels.md"),
    ("Screenshot plan", "docs/app-store/screenshot-plan.md"),
]:
    local_text = (root_dir / relative_path).read_text(encoding="utf-8")
    require_absent(label, local_text, disallowed_ai_positioning)

finish()
print("OK: Public App Store Privacy Policy and Support pages match local release claims")
PY
