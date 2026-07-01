---
title: ClaraCore Mobile App Store Connect Metadata
permalink: /app-store/app-store-connect-metadata/
---

# ClaraCore Mobile App Store Connect Metadata

Date: 2026-07-01

Use this page as the App Store Connect copy source. Do not add real API keys to this file.

## App Information

Name:

```text
ClaraCore
```

Subtitle:

```text
AI 对话记忆整理
```

Category:

```text
Productivity
```

Content rights:

```text
The app imports only user-selected text, public share links, or text files provided by the user. It does not include third-party copyrighted media assets as app content.
```

Age rating guidance:

```text
No unrestricted web browser.
No gambling, contests, or commerce.
No medical diagnosis, therapy, or crisis intervention.
User-generated imported text may contain arbitrary content, but the app's own purpose is productivity and local organization.
```

## Pricing And Availability

Initial recommendation:

```text
Free, no in-app purchases.
Exclude mainland China for the first public release unless ICP/app filing requirements are confirmed and satisfied.
```

Reason:

```text
ClaraCore is currently a personal local-first productivity app with user-configured model providers. The first release should reduce compliance uncertainty and focus on TestFlight feedback.
```

## Privacy Policy And Support

Privacy Policy URL:

```text
https://xiaomao361.github.io/claracore-mobile/app-store/privacy-policy/
```

Support URL:

```text
https://xiaomao361.github.io/claracore-mobile/app-store/support/
```

These URLs require GitHub Pages or another static host to be enabled before App Review.

## Promotional Text

```text
导入你主动选择的 AI 对话、文本或公开分享链接，整理成本地记忆和共同线，再复制回召包到外部 AI 应用继续使用。
```

## Description

```text
ClaraCore Mobile 是一个本地优先的 AI 对话记忆整理工具。

你可以把自己主动选择的 AI 对话、公开分享链接、粘贴文本或文本文件导入 ClaraCore。应用会把有价值的信息整理成本地记忆和共同线，帮助你在下一次对话时快速恢复上下文。

核心能力：
- 导入 AI 对话、公开分享链接、粘贴文本和 .txt 文件
- 保存原始导入，形成可回看的原文 Archive
- 使用角色卡描述当前 Agent 和用户关系
- 将导入内容整理成少量事实记忆和一条共同线
- 查看、编辑和删除本地记忆
- 查看共同线的当前状态、里程碑和下一步
- 复制回召包到外部 AI 应用继续对话
- 查询并选择任意 OpenAI-compatible 默认整理模型

隐私与控制：
- 导入原文、记忆、角色卡和共同线默认存储在本机
- API Key 存储在 iOS Keychain
- 未配置模型 Key 时，应用不会把对话发送给远程模型
- 配置远程模型前，应用会要求你明确同意第三方 AI 处理说明
- 配置远程模型后，只有在你主动导入并整理时，相关内容才会发送到你选择的模型提供方
- 无广告，无跟踪，无 ClaraCore 账号

DeepSeek 公开分享链接是支持的导入来源之一，但 ClaraCore 不依赖 DeepSeek 作为默认模型。你可以配置任意兼容 OpenAI 协议的模型端点，查询可用模型后选择默认整理模型。
```

## Keywords

```text
AI,记忆,对话,上下文,笔记,整理,本地,ChatGPT,Claude,DeepSeek
```

## App Privacy Labels

Tracking:

```text
No.
```

Data linked to the user:

```text
No ClaraCore account exists. The developer does not link app data to a developer-operated user profile.
```

Data collected by developer-operated servers:

```text
None in the current app.
```

Conservative disclosure if App Store Connect asks about data sent to user-configured third-party model providers:

```text
User Content
Purpose: App Functionality
Tracking: No
Advertising: No
Notes: Imported conversation content may be sent to a user-configured OpenAI-compatible model provider only after the user saves model configuration, accepts the third-party AI processing notice, and starts organization.
```

Authentication data:

```text
A user-provided model API key is stored in iOS Keychain and sent only to the configured model provider as an Authorization header.
```

Do not declare analytics, purchases, location, contacts, health, financial, browsing history, advertising data, or tracking unless those features are added.

## App Review Notes

```text
ClaraCore Mobile is a local-first iOS app for importing user-selected AI conversation material, organizing it into local memories and Shared Lines, and copying a recall package back into an external AI app.

Testing without an API key:
1. Launch the app.
2. Open Settings and review the built-in Privacy Policy and Support pages.
3. Review the default model configuration fields.
4. Do not save an API key.
5. Open Import and paste a short text transcript.
6. The app remains in local placeholder mode and asks for a default model key before real organization.

Testing with a remote model:
1. In Settings, enter an OpenAI-compatible model configuration:
   Provider: [PROVIDER_NAME]
   Base URL: [OPENAI_COMPATIBLE_BASE_URL]
   API Key: [TEST_API_KEY_PROVIDED_IN_APP_STORE_CONNECT_NOTES_ONLY]
2. Accept the third-party AI processing notice.
3. Tap Query Models (`查询模型`).
4. Select one returned model from the list.
5. Tap Save Configuration (`保存配置`).
6. Tap Test Connection (`测试连接`).
7. Open Import.
8. Paste a short transcript or a public conversation share link.
9. Tap Import and Organize.
10. Confirm the result screen shows committed Memory and Shared Line counts.
11. Open Original Text (`原文`) and confirm the source archive is visible.
12. Open Memory and delete one test memory.
13. Open Shared Line, copy the recall package, and confirm the copied text includes role, user, continuity state, and related factual memories.

The app does not include ads, tracking, user accounts, or developer-operated cloud sync. User content is stored locally unless the user configures a remote model provider, accepts the third-party AI processing notice, and starts organization. API keys are stored in iOS Keychain.

DeepSeek is supported as one public share-link import source. The default model provider is configurable and can be any OpenAI-compatible endpoint.
```

## Screenshot Set

Required first pass:

1. Import screen with role card selector, source input, and paste/file buttons.
2. Settings model configuration with provider/base URL/API key fields, consent notice, queried models, and selected model. Hide the API key.
3. Import result screen showing Memory and Shared Line counts.
4. Original Text (`原文`) archive list and detail view.
5. Memory list showing editable/deletable local memories.
6. Shared Line screen showing current position, milestones, next step, and continuity state.
7. Recall package sheet showing copyable context for an external AI app.
8. Settings built-in Privacy Policy and Support pages.

Avoid screenshots that imply background capture, silent monitoring, therapy, medical advice, or automatic reading of other AI apps.
