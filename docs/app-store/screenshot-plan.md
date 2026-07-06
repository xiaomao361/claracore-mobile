---
title: ClaraCore Mobile Screenshot Plan
permalink: /app-store/screenshot-plan/
---

# ClaraCore Mobile Screenshot Plan

Date: 2026-07-06

Use this plan to produce the App Store Connect screenshot set for the exact TestFlight or App Store build being submitted.

## Local File Layout

Save final screenshots under:

```text
docs/app-store/screenshots/
  iphone-6.9/
    01-import.png
    02-settings-model.png
    03-import-result.png
    04-archive.png
    05-memory.png
    06-shared-line.png
    07-recall-package.png
    08-settings-support.png
  ipad-13/
    01-import.png
    02-settings-model.png
    03-import-result.png
    04-archive.png
    05-memory.png
    06-shared-line.png
    07-recall-package.png
    08-settings-support.png
  manifest.txt
```

To capture the current simulator build into the expected local layout, run:

```bash
scripts/capture_app_store_screenshots.sh
```

Before uploading existing screenshot files, run:

```bash
MIN_SCREENSHOTS_PER_DEVICE=8 scripts/verify_app_store_screenshots.sh
```

The capture script defaults to a Release simulator build, installs it on the configured iPhone and iPad simulators, launches the app with `CLARACORE_SCREENSHOT_MODE=1`, captures the full first-release sequence, writes `manifest.txt`, and then runs the verifier. Screenshot fixture mode seeds safe sample model configuration, Archive, Memory, and Shared Line data so every screenshot can be captured from real app UI without importing private material first. The manifest records `SCREENSHOT_SEQUENCE=01-import,02-settings-model,03-import-result,04-archive,05-memory,06-shared-line,07-recall-package,08-settings-support` and `AUTO_CAPTURED_SCREENSHOTS=01-import,02-settings-model,03-import-result,04-archive,05-memory,06-shared-line,07-recall-package,08-settings-support`. Use `CONFIGURATION=Debug scripts/capture_app_store_screenshots.sh` only for local visual debugging. The verifier checks the manifest against the current marketing version/build number, file format, screenshot count, accepted portrait pixel sizes, nonblank screenshot content, and, in final mode, the required 8-file sequence for both device sets. The final submission gate runs the verifier with `MIN_SCREENSHOTS_PER_DEVICE=8`.

## Required Device Sets

ClaraCore Mobile currently targets iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), so prepare both:

- iPhone 6.9-inch portrait screenshots: use one accepted 6.9-inch size such as `1320 x 2868`, `1290 x 2796`, or `1260 x 2736`.
- iPad 13-inch portrait screenshots: use one accepted 13-inch size such as `2064 x 2752` or `2048 x 2732`.

Apple accepts 1 to 10 screenshots per device set in `.jpeg`, `.jpg`, or `.png`. App previews are optional for this release. For the first upload-ready package, prepare all 8 screenshots below for each required device set.

## Capture Rules

- Capture real app UI from the submitted build, not mockups.
- Regenerate screenshots after changing marketing version, build number, public App Store copy, or first-screen UI.
- Use portrait orientation for the first release.
- Hide or remove real API keys, account identifiers, local logs, and private conversation content.
- Use sample content that clearly shows user-directed import, not background capture or automatic monitoring.
- Run the verifier after capture so blank, transparent, single-color, duplicate, wrong-size, stale-version, or Debug screenshots are rejected before upload.
- Keep text legible on both iPhone and iPad screenshots.

## Screenshot Sequence

Prepare the same sequence for iPhone and iPad when the layout is usable on both:

1. `01-import`: Import screen with role card selector, source input, paste/file actions, `本次整理机制`, and the direct Settings action (`切换整理方式` or `补全启用条件`) when the external model is not active.
2. `02-settings-model`: Settings model configuration with Provider, Base URL, API Key field, external processing consent, queried model results, and selected read-only default model.
3. `03-import-result`: Import result card showing Memory count and Shared Line count.
4. `04-archive`: Original Text (`原文`) Archive list or detail view showing source trace.
5. `05-memory`: Memory list showing local, editable, deletable factual memories.
6. `06-shared-line`: Shared Line screen showing current position, milestones, next step, and continuity state.
7. `07-recall-package`: Recall package sheet showing copyable context for an external conversation app.
8. `08-settings-support`: Built-in Privacy Policy and Support pages in Settings, including version/build and privacy effective date.

## Review-Safe Content

Avoid screenshots that imply:

- silent background memory capture
- automatic reading of other apps
- therapy, medical advice, diagnosis, crisis intervention, or surveillance
- a required DeepSeek model dependency
- real API keys or private user data

## Apple Source Notes

- App Store Connect accepts 1 to 10 screenshots in `.jpeg`, `.jpg`, or `.png`.
- iPhone 6.9-inch screenshot sizes include `1320 x 2868`, `1290 x 2796`, and `1260 x 2736` portrait.
- iPad 13-inch screenshots are required when the app runs on iPad; accepted portrait sizes include `2064 x 2752` and `2048 x 2732`.

Source: Apple App Store Connect Help, Screenshot specifications.
