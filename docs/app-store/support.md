---
title: ClaraCore Mobile Support
permalink: /app-store/support/
---

# ClaraCore Mobile Support

ClaraCore Mobile is an iOS app for importing user-selected conversation material, organizing it into local memories and Shared Lines, and copying a recall package back into an external conversation app.

## Support Contact

For support, bug reports, privacy questions, or App Store review follow-up, contact the maintainer through the project repository:

https://github.com/xiaomao361/claracore-mobile/issues

When reporting an issue, use Settings > Support > Copy Diagnostics, then include the copied diagnostics block and the steps that led to the problem.

The copied diagnostics block contains app version/build, bundle ID, device model, iOS version, and a non-sensitive organization engine status summary such as whether external-model activation is complete and which activation requirements are missing. It does not include API keys, imported conversation text, memories, Shared Lines, provider names, Base URLs, model names, or model provider configuration.

If GitHub Issues are not enabled for this repository, contact the developer through the contact method listed in App Store Connect.

## Common Questions

### Do I need a DeepSeek key?

No. DeepSeek public share links are one supported import source, but the default organization model is configurable. Any OpenAI-compatible model endpoint can be used if the user provides a base URL and API key, queries available models, and selects one returned model.

### Can I type any model name manually?

No. The default organization model is selected from the model list returned by the configured provider's `/models` endpoint. This keeps the saved configuration tied to a model the provider reported as available.

### What happens without a model API key?

The app stays in local-rule mode. Users can import selected conversation material and create conservative local memories / Shared Lines without sending content to a model provider. A configured external model is optional and is shown as enabled only after the provider, model, API key, and external processing notice are all complete.

### Where is my data stored?

Imported conversations, memories, Context Cards, Shared Lines, and import history are stored locally on the device in the app's Application Support container. The local database is excluded from iCloud and iTunes backups. API keys are stored in ThisDeviceOnly iOS Keychain items.

### How do I clear local data?

Open Settings, then use `清除本机数据`. This deletes local Archive, Inbox, memories, Shared Lines, Context Cards, model configuration, and saved model API keys, then restores the default Context Card and local-rule organization mode.

### When does content leave the device?

Content leaves the device only when the user fetches a public share link, configures a remote model provider and starts organization, copies a recall package to the clipboard for use in another app, or copies/shares a complete original Archive entry.

## Privacy Policy

https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/privacy-policy.md
