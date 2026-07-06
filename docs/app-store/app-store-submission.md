# ClaraCore Mobile App Store Submission Checklist

Date: 2026-07-06
Status: Draft for App Store Connect and TestFlight setup

## Current Release State

- 2026-07-06 local readiness passed through XCTest, Release simulator build/install/launch smoke, unsigned Release iphoneos build, unsigned archive structure checks, PrivacyInfo validation, App Store metadata validation, common secret scanning, and screenshot package verification.
- 2026-07-06 device delivery check installed and launched a Debug development-signed build on `zhouwei iphone` (iPhone 14 Pro) with bundle id `com.claracore.mobile`.
- Final upload readiness still requires an Apple Distribution certificate for Team `A5L4GGX82X`, a real signed `.xcarchive` / optional exported `.ipa`, and one clean committed/published release state before App Store Connect upload.

## 1. Privacy Policy URL

Current public fallback URL:

```text
https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/privacy-policy.md
```

Cleaner URL after enabling GitHub Pages with source set to GitHub Actions:

```text
https://xiaomao361.github.io/claracore-mobile/app-store/privacy-policy/
```

Source page in this repo:

```text
docs/app-store/privacy-policy.md
```

The policy states:

- Imported conversations, raw source archives, memories, Context Cards, Shared Lines, and import history are stored locally.
- The local database is stored in the app's Application Support container and is excluded from iCloud and iTunes backups.
- API keys are stored in ThisDeviceOnly iOS Keychain items.
- Content is sent to a remote model only when the user configures a model provider, accepts the external model processing notice, and starts organization.
- DeepSeek public share-link import is one import path, not the product identity or required default model.
- No ads, no tracking, no ClaraCore account, and no developer-side cloud sync.

## 2. Support URL

Current public fallback URL:

```text
https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/support.md
```

Cleaner URL after enabling GitHub Pages with source set to GitHub Actions:

```text
https://xiaomao361.github.io/claracore-mobile/app-store/support/
```

Source page in this repo:

```text
docs/app-store/support.md
```

The support page points users to:

- GitHub Issues for bug reports and support.
- The privacy policy.
- A short FAQ covering API keys, local storage, and remote model behavior.

The automated readiness gate checks that the Privacy Policy URL, Support URL, and GitHub Issues support contact URL return HTTP 200, that the App Store Connect metadata uses the same Privacy Policy and Support URLs, and that first-release category, content rights, age-rating, pricing, and mainland China availability guidance remain present.

## 3. App Review Notes

Paste this into App Store Connect review notes, then replace bracketed fields before submission:

```text
ClaraCore Mobile is a local-first iOS app for importing user-selected conversation material, organizing it into local memories and Shared Lines, and copying a recall package back into an external conversation app.

Testing without an API key:
1. Launch the app.
2. Open Settings and review the default model configuration fields.
3. Do not save an API key.
4. Open Import and paste a short text transcript.
5. The Import screen shows `本次整理机制：本机规则`; importing creates conservative local memories / Shared Lines without sending content to a model provider. This verifies launch, navigation, local storage, settings, and local organization without requiring third-party credentials.

Testing with a remote model:
1. In Settings, enter an OpenAI-compatible model configuration:
   Provider: [PROVIDER_NAME]
   Base URL: [OPENAI_COMPATIBLE_BASE_URL]
   API Key: [TEST_API_KEY_PROVIDED_IN_APP_STORE_CONNECT_NOTES_ONLY]
2. Tap Query Models (`查询模型`).
3. Select one returned model from the list. If the provider returns many models, use the model search field to narrow by model id. The default organization model field is read-only and cannot be manually typed.
4. Accept the external model processing notice.
5. Tap Save Configuration (`保存配置`) and confirm the organization engine status updates immediately in Settings.
6. Tap Test Connection (`测试连接`).
7. Open Import.
8. Paste a short transcript or a public conversation share link.
9. Tap Import and Organize.
10. Confirm the result screen shows committed Memory and Shared Line counts.
11. Open Original Text (`原文`) and confirm the source archive is visible.
12. Open Memory and delete one test memory.
13. Open Shared Line, copy the recall package, and confirm the copied text includes role, user, continuity state, and related factual memories.
14. Open Original Text (`原文`), copy or share one complete original Archive entry, and confirm the screen makes this explicit before putting full original text on the system clipboard or share sheet.

The app does not include ads, tracking, user accounts, or a developer-operated cloud sync service. User content is stored locally unless the user configures a remote model provider, accepts the external model processing notice, and starts organization. The user can also explicitly copy or share a complete original Archive entry from the Original Text screen. API keys are stored in ThisDeviceOnly iOS Keychain items.

DeepSeek is supported as one public share-link import source. The default model provider is configurable and can be any OpenAI-compatible endpoint.

Support URL:
https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/support.md

Privacy Policy URL:
https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/privacy-policy.md
```

Do not commit a real test API key to this repository. Add it only in App Store Connect Review Notes if needed.

## 4. App Privacy Labels Draft

Use `docs/app-store/app-privacy-labels.md` as the App Store Connect App Privacy source of truth. Re-check before submission if analytics, accounts, sync, crash reporting, or a hosted backend are added later.

### Tracking

```text
Does this app use data to track the user?
No.
```

### Data Linked To The User

```text
The developer does not operate an account system and does not link app data to a ClaraCore account.

If the user configures a remote model provider, that provider may be able to associate API requests with the user's provider account or API key. This is controlled by the user-selected provider.
```

### Data Not Collected By The Developer

```text
ClaraCore Mobile does not collect data to developer-operated servers in the current app.
Copying a recall package to the clipboard or copying/sharing a complete original Archive entry is user-directed device behavior, not developer-operated server collection.
```

### Data Types To Disclose Conservatively

If App Store Connect asks about data transmitted to third-party processors selected by the user, disclose:

```text
User Content
- Purpose: App Functionality
- Tracking: No
- Used for advertising: No
- Developer-side collection: No developer-operated server collection
- Notes: Imported conversation text may be sent to a user-configured OpenAI-compatible model provider only when the user saves a model API key, accepts the external model processing notice, and starts organization.
- Clipboard/share note: Copying a recall package or a complete original Archive entry is initiated by the user through the system clipboard or share sheet and is not collected by ClaraCore servers.
```

Also disclose if requested:

```text
Other Data / Authentication Token
- Purpose: App Functionality
- Tracking: No
- Notes: A user-provided model API key is stored in a ThisDeviceOnly iOS Keychain item and sent only to the configured model provider as an Authorization header.
```

Do not disclose analytics, purchases, location, contacts, browsing history, health, financial, or advertising data unless those features are added.

## 5. App Store Screenshots And Chinese Description

Use `docs/app-store/screenshot-plan.md` as the source of truth for screenshot device sets, sizes, and review-safe content.

To regenerate the current simulator screenshot set:

```bash
scripts/capture_app_store_screenshots.sh
scripts/verify_app_store_screenshots.sh
```

The capture script defaults to a Release simulator build. Use a Debug override only for local visual debugging, not for final App Store screenshots.

### Screenshot Set

Prepare screenshots that show actual app behavior:

1. Import screen with role card selector, source input, paste/file buttons, `本次整理机制`, and the direct Settings action (`切换整理方式` or `补全启用条件`) when the external model is not active.
2. Model configuration in Settings with provider/base URL/API key fields, external model consent, queried model results, and the selected read-only default model, with the API key hidden.
3. Import result screen showing Memory and Shared Line counts.
4. Original Text (`原文`) Archive list and detail screen showing a source trace.
5. Memory list showing user-editable, deletable factual memories.
6. Shared Line screen showing current station, milestones, next step, and continuity state.
7. Recall package sheet showing copyable context for an external conversation app.
8. Built-in Privacy Policy and Support pages in Settings.

Avoid screenshots that imply silent background memory capture. The app should look like a user-directed capture and organization tool.

### Chinese App Name

```text
ClaraCore
```

If a subtitle is needed:

```text
对话上下文整理
```

### Chinese Subtitle

```text
把重要对话整理成可恢复的记忆
```

### Chinese Promotional Text

```text
导入你主动选择的对话、文本或公开分享链接，整理成本地记忆和共同线，再复制上下文继续使用。
```

### Chinese Description

```text
ClaraCore Mobile 是一个本地优先的对话上下文整理工具。

你可以把自己主动选择的对话、公开分享链接、粘贴文本或文本文件导入 ClaraCore。应用会把有价值的信息整理成本地记忆和共同线，帮助你在下一次对话时快速恢复上下文。

核心能力：
- 导入对话、公开分享链接、粘贴文本和 .txt 文件
- 保存原始导入，形成可回看的原文 Archive
- 使用角色卡描述当前 Agent 和用户关系
- 将导入内容整理成少量事实记忆和一条共同线
- 查看、编辑和删除本地记忆
- 删除已保存的原文 Archive
- 查看共同线的当前状态、里程碑和下一步
- 复制回召包到外部对话应用继续使用
- 查询并选择任意 OpenAI-compatible 默认整理模型

隐私与控制：
- 导入内容、记忆、角色卡和共同线默认存储在本机，并可在应用内删除
- API Key 存储在 iOS Keychain 的 ThisDeviceOnly 项中
- 未配置模型 Key 时，应用不会把对话发送给远程模型
- 配置远程模型前，应用会要求你明确同意外部模型处理说明
- 配置远程模型后，只有在你主动导入并整理时，相关内容才会发送到你选择的模型提供方
- 无广告，无跟踪，无 ClaraCore 账号

DeepSeek 公开分享链接是支持的导入来源之一，但 ClaraCore 不依赖 DeepSeek 作为默认模型。你可以配置任意兼容 OpenAI 协议的模型端点，查询可用模型后选择默认整理模型。
```

### Keywords Draft

```text
记忆,对话,上下文,笔记,整理,本地,回召,Archive,DeepSeek
```

### Review-Safe DeepSeek Wording

Use:

```text
支持导入用户主动提供的公开分享链接和复制文本。
支持 DeepSeek 公开分享链接作为一种导入来源。
默认整理模型可配置为任意 OpenAI-compatible endpoint，并从该 endpoint 返回的模型列表中选择。
```

Avoid:

```text
DeepSeek 官方客户端
DeepSeek 记忆插件
自动读取 DeepSeek 对话
后台捕获聊天记录
```

## 6. TestFlight External Testing Checklist

Run this before public App Store submission:

1. Install from TestFlight on a clean device.
2. Launch for the first time without a model API key.
3. Confirm Settings opens and model configuration fields are visible.
4. Confirm Import shows `本次整理机制：本机规则` and explains that content will not be sent to a model provider.
5. Enter Provider, Base URL, and a non-production API key.
6. Accept the external model processing notice.
7. Query available models and select one returned model, using model search when the provider returns many results.
8. Save the configuration and confirm the Settings organization engine status updates immediately.
9. Tap Test Connection and confirm visible success or clear failure.
10. Import a short pasted transcript.
11. Confirm result card shows Memory and Shared Line counts.
12. Open Original Text (`原文`) and confirm the archive entry exists.
13. Delete one Original Text Archive entry and confirm it is removed from the archive list.
14. Delete one memory and confirm feedback.
15. Open Shared Line and confirm current station, milestones, next step, and continuity state.
16. Copy recall package and paste it into Notes to verify clipboard output.
17. Delete the saved model key and confirm the app returns to local-rule organization.
18. In Settings, use `清除本机数据` and confirm Archive, Inbox, memories, Shared Lines, custom Context Cards, model configuration, and saved model keys are removed.
19. Confirm the default Context Card is restored and Import shows local-rule organization.
20. Reopen the app and confirm it does not crash when no key exists.

Record:

```text
Build:
Device:
iOS version:
Tester:
Pass/Fail:
Issues:
```

## 7. Mainland China ICP And Compliance

Before selecting mainland China availability in App Store Connect:

1. Confirm whether the Apple Developer account is an individual or organization account.
2. Confirm whether the app will be distributed in mainland China on the first release.
3. If distributing in mainland China, verify whether an ICP Filing Number is required for this app/account combination.
4. Ensure the ICP Filing Number and App Store Connect metadata match the MIIT filing information.
5. If no ICP Filing Number is available, consider excluding mainland China from the first public release until the compliance path is clear.

Current recommendation for the first public release:

```text
If there is no confirmed ICP filing and no mainland-China compliance review, do not include mainland China in the first public App Store launch.
```

## 8. Final Pre-Submission Checklist

Before submitting to App Review:

1. Before uploading a new TestFlight or App Store build, set the intended marketing version and a new App Store Connect build number:

   ```bash
   scripts/set_app_version.sh 0.1.0 2
   ```

   Keep `MARKETING_VERSION` stable for metadata-only resubmissions, but increase `CURRENT_PROJECT_VERSION` for every uploaded binary. App Store Connect rejects reused build numbers for the same version.
2. Run the local automated readiness gate:

   ```bash
   scripts/verify_app_store_readiness.sh
   ```

   This verifies the public fallback Privacy Policy and Support URLs return HTTP 200, the GitHub Issues support contact URL, in-app public URL consistency, App Store Connect metadata URL consistency, release document dates, screenshot plan coverage for the current iPhone/iPad target family, mainland China first-release availability guidance, Privacy Policy effective date, GitHub Pages workflow trigger mode, project version consistency, the version helper script, plist/project syntax, Keychain API key accessibility, bounded xcodebuild timeouts for release gates, reused SwiftPM package checkouts, the XCTest suite, the PrivacyInfo manifest including no tracking domains and no collected data declarations, App Store icon size/alpha, App Store Connect metadata lengths/placeholders, category/content-rights/age-rating/pricing guidance, common secret patterns, Release simulator build, Release simulator install/launch smoke, unsigned Release iphoneos build, unsigned archive structure, bundled privacy manifest, bundle identifier/version, and `ITSAppUsesNonExemptEncryption = false`.
3. Optional: run the XCTest suite directly after logic, storage, importer, recall, or settings changes:

   ```bash
   scripts/verify_unit_tests.sh
   ```

   This runs the `ClaraCoreMobileTests` XCTest suite on an iOS simulator and should pass before TestFlight or App Review submission.
4. Optional: run the simulator launch smoke check directly after narrow plist or project-setting changes:

   ```bash
   scripts/smoke_simulator_launch.sh
   ```

   This defaults to a Release simulator build, installs, launches, confirms the app process is running, then terminates the simulator app. It catches install/launch preflight failures that a compile-only build can miss.
5. Run the unsigned generic device Release build check:

   ```bash
   scripts/verify_device_release_build.sh
   ```

   This builds `Release-iphoneos` with `CODE_SIGNING_ALLOWED=NO` and validates the bundled Info.plist and PrivacyInfo manifest declarations. It is not an uploadable archive and does not replace Developer Program signing, TestFlight upload, or App Review validation.
6. Run the unsigned archive structure check:

   ```bash
   scripts/verify_app_store_archive.sh
   ```

   This creates an unsigned `.xcarchive`, then validates the archived app bundle, Info.plist, PrivacyInfo manifest declarations, archive metadata, dSYM presence, and dSYM UUID match with the app binary. It is still not an uploadable archive; the final upload must use a real signed archive/export from the Apple Developer Program account.
7. After joining the Apple Developer Program and configuring signing in Xcode, run the signing prerequisite check:

   ```bash
   scripts/verify_app_store_signing_prerequisites.sh
   ```

   This verifies the Release iOS build settings use `com.claracore.mobile`, automatic signing, a non-empty development team, an iOS device platform, and a local Apple Distribution signing identity whose Team ID matches `DEVELOPMENT_TEAM`. It does not upload anything. Do not proceed to a real signed archive/TestFlight upload while this fails.
8. After creating a real signed archive and, optionally, an App Store Connect export, verify the produced artifacts:

   ```bash
   ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive EXPORT_PATH=/path/to/export scripts/export_signed_app_store_archive.sh
   ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive scripts/verify_signed_app_store_artifacts.sh
   ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive EXPORT_PATH=/path/to/export scripts/verify_signed_app_store_artifacts.sh
   ```

   The export script uses `docs/app-store/export-options-app-store-connect.plist` with `method = app-store-connect`, `destination = export`, `signingStyle = automatic`, `distributionBundleIdentifier = com.claracore.mobile`, and `manageAppVersionAndBuildNumber = false`, then runs the signed artifact verifier. The verifier validates the signed archive's bundle id, archive signing identity, version/build, bundled PrivacyInfo declarations, dSYM presence, dSYM UUID match with the app binary, export-compliance flag, absence of `UIApplicationSceneManifest`, Apple Distribution signature, strict code-signature verification, signed entitlements, and embedded provisioning profile fields such as bundle id, team id, `get-task-allow = false`, non-wildcard app id, non-enterprise distribution, and future expiration. It also verifies that the code-signature TeamIdentifier and signed entitlements match the embedded provisioning profile. When `EXPORT_PATH` is provided, it also unzips the exported `.ipa` and verifies the contained app. The final submission gate requires this signed artifact validation by default; use `RUN_SIGNED_ARTIFACTS=0` only for an explicit pre-certificate dry run that must not be treated as upload-ready.
9. Optional: enable GitHub Pages, set its source to GitHub Actions, run `.github/workflows/pages.yml` manually, then replace the fallback URLs with the cleaner Pages URLs only after both Pages URLs return HTTP 200.
10. Fill App Privacy labels from this document.
11. Copy final metadata from `docs/app-store/app-store-connect-metadata.md`.
12. After publishing the final Privacy Policy and Support pages, run:

   ```bash
   scripts/verify_public_app_store_docs.sh
   ```

   This checks that the public URLs App Review will open contain the current local release-critical claims. When the metadata uses GitHub fallback URLs, the public raw files must exactly match the local release documents. Do not submit while this fails; it commonly fails when local docs were updated but GitHub/GitHub Pages has not been refreshed yet.
13. Add App Review Notes and, if needed, a temporary test model key only inside App Store Connect. Confirm the notes disclose the user-controlled copy/share path for complete original Archive entries.
14. Save iPhone and iPad screenshots under the layout in `docs/app-store/screenshot-plan.md`, run `MIN_SCREENSHOTS_PER_DEVICE=8 scripts/verify_app_store_screenshots.sh`, then upload the verified screenshots showing user-directed import, external model consent, source archive, confirmed deletion, and recall copy. The default one-screenshot verifier mode is only for early technical validation; the upload-ready package must include the full first-release sequence for both required device sets.
15. Confirm the built-in Support page can copy diagnostics and that the copied block contains version/build, bundle ID, device, iOS version, and non-sensitive organization engine status, but no API key, imported text, memories, Shared Lines, provider name, Base URL, model name, or model provider configuration.
16. Confirm no screenshots, local logs, App Store Connect review notes, or copied diagnostics contain a real API key.
17. Run the TestFlight external testing checklist once.
18. Confirm mainland China is excluded from the first public release unless ICP/app filing requirements have been confirmed and satisfied.
19. Run the final local submission gate after the signed archive/export, public documents, screenshots, metadata, review notes, and availability choices are all final:

   ```bash
   ARCHIVE_PATH=/path/to/ClaraCoreMobile.xcarchive EXPORT_PATH=/path/to/export scripts/verify_app_store_submission_ready.sh
   ```

   This uploads nothing. By default it runs the local readiness gate, signing prerequisite check, signed archive/export artifact verifier, release-critical tracked-file check, clean worktree check, public App Store document check, and screenshot package verifier with `MIN_SCREENSHOTS_PER_DEVICE=8`, then reports every failing gate together with a concrete next action. `EXPORT_PATH` is optional only if no export directory was produced yet, but `ARCHIVE_PATH` is required for an upload-ready run. Use `RUN_SIGNED_ARTIFACTS=0` only for an explicit pre-certificate dry run that must not be treated as upload-ready. `RUN_*` values must be explicit booleans (`1`, `0`, `true`, `false`, `yes`, or `no`) so a typo cannot silently disable a required gate. Do not upload a signed archive to TestFlight or submit to App Review while this final gate fails.

## Source Notes

Official Apple references used for this checklist:

- App privacy policy URL and privacy information requirements: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- App privacy details disclosure: https://developer.apple.com/app-store/app-privacy-details/
- App Review support and privacy link readiness: https://developer.apple.com/distribute/app-review/
- App information and China ICP filing note: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- Export compliance overview and Info.plist declaration: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
