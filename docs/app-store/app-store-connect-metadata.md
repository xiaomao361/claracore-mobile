---
title: ClaraCore Mobile App Store Connect Metadata
permalink: /app-store/app-store-connect-metadata/
---

# ClaraCore Mobile App Store Connect Metadata

Date: 2026-07-06

Use this page as the App Store Connect copy source. Do not add real API keys to this file.

## App Information

Name:

```text
ClaraCore
```

Subtitle:

```text
对话上下文整理
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
https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/privacy-policy.md
```

Support URL:

```text
https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/support.md
```

These GitHub document URLs are the current public fallback and return HTTP 200 without requiring GitHub Pages.
After GitHub Pages is enabled with source set to GitHub Actions, the cleaner Pages URLs can replace them:

```text
https://xiaomao361.github.io/claracore-mobile/app-store/privacy-policy/
https://xiaomao361.github.io/claracore-mobile/app-store/support/
```

## Promotional Text

```text
导入你主动选择的对话、文本或公开分享链接，整理成本地记忆和共同线，再复制上下文继续使用。
```

## Description

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
- 导入原文、记忆、角色卡和共同线默认存储在本机，并可在应用内删除
- API Key 存储在 iOS Keychain 的 ThisDeviceOnly 项中
- 未配置模型 Key 时，应用不会把对话发送给远程模型
- 配置远程模型前，应用会要求你明确同意外部模型处理说明
- 配置远程模型后，只有在你主动导入并整理时，相关内容才会发送到你选择的模型提供方
- 无广告，无跟踪，无 ClaraCore 账号

DeepSeek 公开分享链接是支持的导入来源之一，但 ClaraCore 不依赖 DeepSeek 作为默认模型。你可以配置任意兼容 OpenAI 协议的模型端点，查询可用模型后选择默认整理模型。
```

## Keywords

```text
记忆,对话,上下文,笔记,整理,本地,回召,Archive,DeepSeek
```

## App Privacy Labels

Fill App Store Connect from `docs/app-store/app-privacy-labels.md`.

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
Copying a recall package to the clipboard or copying/sharing a complete original Archive entry is user-directed device behavior, not developer-operated server collection.
```

Conservative disclosure if App Store Connect asks about data sent to user-configured third-party model providers:

```text
User Content
Purpose: App Functionality
Tracking: No
Advertising: No
Notes: Imported conversation content may be sent to a user-configured OpenAI-compatible model provider only after the user saves model configuration, accepts the external model processing notice, and starts organization.
Copying a recall package or a complete original Archive entry is initiated by the user through the system clipboard or share sheet and is not collected by ClaraCore servers.
```

Authentication data:

```text
A user-provided model API key is stored in a ThisDeviceOnly iOS Keychain item and sent only to the configured model provider as an Authorization header.
```

Do not declare analytics, purchases, location, contacts, health, financial, browsing history, advertising data, or tracking unless those features are added.

## App Review Notes

```text
ClaraCore Mobile is a local-first iOS app for importing user-selected conversation material, organizing it into local memories and Shared Lines, and copying a recall package back into an external conversation app.

Testing without an API key:
1. Launch the app.
2. Open Settings and review the built-in Privacy Policy and Support pages.
3. Review the default model configuration fields.
4. Do not save an API key.
5. Open Import and paste a short text transcript.
6. The Import screen shows `本次整理机制：本机规则`; importing creates conservative local memories / Shared Lines without sending content to a model provider.

Testing with a remote model:
Remote model configuration is optional. The app can be reviewed without third-party credentials by using the local-rule path above.

If remote model testing is required, the developer can provide a temporary non-production OpenAI-compatible endpoint and API key directly in App Store Connect review notes, not in the app binary or public repository. With those credentials, the reviewer can open Settings, enter the provider/base URL/API key, accept the external model processing notice, query models, select one returned model, save the configuration, test the connection, then import and organize a short transcript.

The app does not include ads, tracking, user accounts, or developer-operated cloud sync. User content is stored locally unless the user configures a remote model provider, accepts the external model processing notice, and starts organization. The user can also explicitly copy or share a complete original Archive entry from the Original Text screen. API keys are stored in ThisDeviceOnly iOS Keychain items.

DeepSeek is supported as one public share-link import source. The default model provider is configurable and can be any OpenAI-compatible endpoint.
```

## Screenshot Set

Required first pass:

1. Import screen with role card selector, source input, paste/file buttons, `本次整理机制`, and the direct Settings action (`切换整理方式` or `补全启用条件`) when the external model is not active.
2. Settings model configuration with provider/base URL/API key fields, external model consent, queried models, and selected model. Hide the API key.
3. Import result screen showing Memory and Shared Line counts.
4. Original Text (`原文`) archive list and detail view.
5. Memory list showing editable/deletable local memories.
6. Shared Line screen showing current position, milestones, next step, and continuity state.
7. Recall package sheet showing copyable context for an external conversation app.
8. Settings built-in Privacy Policy and Support pages.

Avoid screenshots that imply background capture, silent monitoring, therapy, medical advice, or automatic reading of other apps.
