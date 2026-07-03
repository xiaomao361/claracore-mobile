# ClaraCore Mobile App Store Submission Checklist

Date: 2026-07-01
Status: Draft for App Store Connect and TestFlight setup

## 1. Privacy Policy URL

Recommended public URL after enabling GitHub Pages with the repository workflow:

```text
https://xiaomao361.github.io/claracore-mobile/app-store/privacy-policy/
```

Source page in this repo:

```text
docs/app-store/privacy-policy.md
```

The policy states:

- Imported conversations, raw source archives, memories, Context Cards, Shared Lines, and import history are stored locally.
- API keys are stored in iOS Keychain.
- Content is sent to a remote model only when the user configures a model provider, accepts the third-party AI processing notice, and starts organization.
- DeepSeek public share-link import is one import path, not the product identity or required default model.
- No ads, no tracking, no ClaraCore account, and no developer-side cloud sync.

## 2. Support URL

Recommended public URL after enabling GitHub Pages with the repository workflow:

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

## 3. App Review Notes

Paste this into App Store Connect review notes, then replace bracketed fields before submission:

```text
ClaraCore Mobile is a local-first iOS app for importing user-selected AI conversation material, organizing it into local memories and Shared Lines, and copying a recall package back into an external AI app.

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
4. Accept the third-party AI processing notice.
5. Tap Save Configuration (`保存配置`) and confirm the organization engine status updates immediately in Settings.
6. Tap Test Connection (`测试连接`).
7. Open Import.
8. Paste a short transcript or a public conversation share link.
9. Tap Import and Organize.
10. Confirm the result screen shows committed Memory and Shared Line counts.
11. Open Original Text (`原文`) and confirm the source archive is visible.
12. Open Memory and delete one test memory.
13. Open Shared Line, copy the recall package, and confirm the copied text includes role, user, continuity state, and related factual memories.

The app does not include ads, tracking, user accounts, or a developer-operated cloud sync service. User content is stored locally unless the user configures a remote model provider, accepts the third-party AI processing notice, and starts organization. API keys are stored in the iOS Keychain.

DeepSeek is supported as one public share-link import source. The default model provider is configurable and can be any OpenAI-compatible endpoint.

Support URL:
https://xiaomao361.github.io/claracore-mobile/app-store/support/

Privacy Policy URL:
https://xiaomao361.github.io/claracore-mobile/app-store/privacy-policy/
```

Do not commit a real test API key to this repository. Add it only in App Store Connect Review Notes if needed.

## 4. App Privacy Labels Draft

Use this as the App Store Connect App Privacy draft. Re-check before submission if analytics, accounts, sync, crash reporting, or a hosted backend are added later.

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
```

### Data Types To Disclose Conservatively

If App Store Connect asks about data transmitted to third-party processors selected by the user, disclose:

```text
User Content
- Purpose: App Functionality
- Tracking: No
- Used for advertising: No
- Developer-side collection: No developer-operated server collection
- Notes: Imported conversation text may be sent to a user-configured OpenAI-compatible model provider only when the user saves a model API key, accepts the third-party AI processing notice, and starts organization.
```

Also disclose if requested:

```text
Other Data / Authentication Token
- Purpose: App Functionality
- Tracking: No
- Notes: A user-provided model API key is stored in iOS Keychain and sent only to the configured model provider as an Authorization header.
```

Do not disclose analytics, purchases, location, contacts, browsing history, health, financial, or advertising data unless those features are added.

## 5. App Store Screenshots And Chinese Description

### Screenshot Set

Prepare screenshots that show actual app behavior:

1. Import screen with role card selector and "paste link/text/file" entry.
2. Model configuration in Settings with provider/base URL/API key fields, third-party AI processing consent, queried model results, and the selected read-only default model, with the API key hidden.
3. Import result screen showing Memory and Shared Line counts.
4. Original Text (`原文`) Archive list and detail screen showing a source trace.
5. Memory list showing user-editable, deletable factual memories.
6. Shared Line screen showing current station, milestones, next step, and continuity state.
7. Recall package sheet showing copyable context for an external AI app.
8. Built-in Privacy Policy and Support pages in Settings.

Avoid screenshots that imply silent background memory capture. The app should look like a user-directed capture and organization tool.

### Chinese App Name

```text
ClaraCore
```

If a subtitle is needed:

```text
AI 对话记忆整理
```

### Chinese Subtitle

```text
把有价值的 AI 对话整理成可恢复的记忆
```

### Chinese Promotional Text

```text
导入你主动选择的 AI 对话、文本或公开分享链接，整理成本地记忆和共同线，再复制回召包到外部 AI 应用继续使用。
```

### Chinese Description

```text
ClaraCore Mobile 是一个本地优先的 AI 对话记忆整理工具。

你可以把自己主动选择的 AI 对话、公开分享链接、粘贴文本或文本文件导入 ClaraCore。应用会把有价值的信息整理成本地记忆和共同线，帮助你在下一次对话时快速恢复上下文。

核心能力：
- 导入 AI 对话、公开分享链接、粘贴文本和 .txt 文件
- 保存原始导入，形成可回看的原文 Archive
- 使用角色卡描述当前 Agent 和用户关系
- 将导入内容整理成少量事实记忆和一条共同线
- 查看、编辑和删除本地记忆
- 删除已保存的原文 Archive
- 查看共同线的当前状态、里程碑和下一步
- 复制回召包到外部 AI 应用继续对话
- 查询并选择任意 OpenAI-compatible 默认整理模型

隐私与控制：
- 导入内容、记忆、角色卡和共同线默认存储在本机，并可在应用内删除
- API Key 存储在 iOS Keychain
- 未配置模型 Key 时，应用不会把对话发送给远程模型
- 配置远程模型前，应用会要求你明确同意第三方 AI 处理说明
- 配置远程模型后，只有在你主动导入并整理时，相关内容才会发送到你选择的模型提供方
- 无广告，无跟踪，无 ClaraCore 账号

DeepSeek 公开分享链接是支持的导入来源之一，但 ClaraCore 不依赖 DeepSeek 作为默认模型。你可以配置任意兼容 OpenAI 协议的模型端点，查询可用模型后选择默认整理模型。
```

### Keywords Draft

```text
AI,记忆,对话,上下文,笔记,整理,本地,ChatGPT,Claude,DeepSeek
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
后台捕获 AI 聊天记录
```

## 6. TestFlight External Testing Checklist

Run this before public App Store submission:

1. Install from TestFlight on a clean device.
2. Launch for the first time without a model API key.
3. Confirm Settings opens and model configuration fields are visible.
4. Confirm Import shows `本次整理机制：本机规则` and explains that content will not be sent to a model provider.
5. Enter Provider, Base URL, and a non-production API key.
6. Accept the third-party AI processing notice.
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
18. Reopen the app and confirm it does not crash when no key exists.

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

1. In the GitHub repository, enable Pages and set its source to GitHub Actions before running `.github/workflows/pages.yml`.
2. Wait for the Pages deployment to finish, then open both URLs in a logged-out browser window.
3. Fill App Privacy labels from this document.
4. Copy final metadata from `docs/app-store/app-store-connect-metadata.md`.
5. Add App Review Notes and, if needed, a temporary test model key only inside App Store Connect.
6. Upload screenshots that show user-directed import, third-party AI consent, source archive, deletion, and recall copy.
7. Confirm no source, docs, fixtures, screenshots, logs, or review notes committed to git contain a real API key.
8. Run the TestFlight external testing checklist once.
9. Decide App Store territory availability, especially mainland China.

## Source Notes

Official Apple references used for this checklist:

- App privacy policy URL and privacy information requirements: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- App privacy details disclosure: https://developer.apple.com/app-store/app-privacy-details/
- App Review support and privacy link readiness: https://developer.apple.com/distribute/app-review/
- App information and China ICP filing note: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
