---
title: ClaraCore Mobile Support
permalink: /app-store/support/
---

# ClaraCore Mobile Support

ClaraCore Mobile is an iOS app for importing user-selected AI conversation material, organizing it into local memories and Shared Lines, and copying a recall package back into an external AI app.

## Support Contact

For support, bug reports, privacy questions, or App Store review follow-up, contact the maintainer through the project repository:

https://github.com/xiaomao361/claracore-mobile/issues

If GitHub Issues are not enabled for this repository, contact the developer through the contact method listed in App Store Connect.

## Common Questions

### Do I need a DeepSeek key?

No. DeepSeek public share links are one supported import source, but the default organization model is configurable. Any OpenAI-compatible model endpoint can be used if the user provides a base URL and API key, queries available models, and selects one returned model.

### Can I type any model name manually?

No. The default organization model is selected from the model list returned by the configured provider's `/models` endpoint. This keeps the saved configuration tied to a model the provider reported as available.

### What happens without a model API key?

The app stays in local-rule mode. Users can import selected conversation material and create conservative local memories / Shared Lines without sending content to a model provider. A configured external model is optional and is shown as enabled only after the provider, model, API key, and external processing notice are all complete.

### Where is my data stored?

Imported conversations, memories, Context Cards, Shared Lines, and import history are stored locally on the device. API keys are stored in the iOS Keychain.

### When does content leave the device?

Content leaves the device only when the user fetches a public share link, configures a remote model provider and starts organization, or copies a recall package to the clipboard for use in another app.

## Privacy Policy

https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/privacy-policy.md
