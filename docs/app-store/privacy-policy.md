---
title: ClaraCore Mobile Privacy Policy
permalink: /app-store/privacy-policy/
---

# ClaraCore Mobile Privacy Policy

Effective date: June 30, 2026

ClaraCore Mobile is an iOS app for importing user-selected AI conversation material, organizing it into local memories and Shared Lines, and copying a recall package back into an external AI app.

## Summary

- The app is local-first.
- The app does not include advertising or third-party tracking.
- The app does not create a ClaraCore account.
- API keys are stored in the iOS Keychain on the user's device.
- Imported conversations, raw source archives, memories, Context Cards, Shared Lines, and import history are stored locally on the user's device.
- Conversation content is sent to a remote model provider only when the user configures a model API key and starts an import or organization action that requires remote reflection.

## Data Stored On Device

ClaraCore Mobile stores the following data locally:

- Imported conversation text, raw source archives, public share-link transcripts, pasted text, and imported `.txt` files.
- Context Cards, including the user-provided agent and user profile text.
- Shared Lines, including current position, next step, interpretation, boundary notes, and related continuity state.
- Memories, including facts, decisions, tags, source information, confidence, importance, and local linkage to a Shared Line or Context Card.
- Import history and duplicate-detection metadata.
- Default model configuration, including provider display name, base URL, and the selected model name returned by the configured provider.
- API keys in the iOS Keychain.

The app does not upload this local database to ClaraCore servers.

## Remote Model Processing

If the user enters a model provider base URL and API key, ClaraCore Mobile can query the configured provider's `/models` endpoint so the user can choose an available default organization model.

If the user saves a default model configuration, ClaraCore Mobile can send imported conversation segments and derived draft context to the configured OpenAI-compatible model endpoint for organization.

This may include:

- Imported conversation text.
- Context needed to extract candidate memories and Shared Line updates.
- Model prompts used to request structured JSON output.

The API key is sent only as an authorization credential to the user-configured model provider for model discovery, connection testing, and organization requests. The app does not send the API key to ClaraCore servers.

If no model API key is configured, ClaraCore Mobile uses local rules. In local-rule mode, the app does not send conversation content to a remote model provider and creates only conservative local memories and Shared Lines from text the user intentionally imports.

## DeepSeek Share Links

ClaraCore Mobile can import publicly shared DeepSeek conversation links when the user intentionally pastes or shares such a link into the app.

For this import path, the app requests the publicly shared conversation content from DeepSeek's share endpoint and converts the returned transcript into local import material. This is separate from the default model provider used for organization. DeepSeek is not required as the default model provider.

## Third-Party Providers

If the user configures a remote model provider, the provider's own privacy policy and data handling terms apply to the content sent to that provider.

Users should only configure providers and API keys they trust. ClaraCore Mobile cannot control how a user-selected third-party model provider stores, processes, or trains on submitted content.

## Data Sharing

ClaraCore Mobile does not sell user data and does not use user data for advertising or tracking.

The app may transmit data only in these user-directed cases:

- Fetching a public conversation share link selected by the user.
- Querying available models from a provider configured by the user.
- Sending imported conversation content to a user-configured model provider for organization.
- Copying a recall package to the clipboard when the user taps the copy action.

## Deletion And Control

Users can delete original source Archive entries, memories, and Shared Lines inside the app. Deleting an original source Archive entry removes the saved source text, segmentation records, and import record for that import. It does not automatically delete memories or Shared Lines already created from the import.

Users can delete the saved model API key from Settings. Removing the key returns the app to local-rule organization.

Uninstalling the app removes the app's local database from the device according to normal iOS app data behavior. Keychain behavior may depend on iOS and device backup/restore behavior.

## Security

API keys are stored in the iOS Keychain using device-local accessibility. Local app data is stored in the app container on the user's device.

Users should avoid importing conversations that contain sensitive personal information unless they are comfortable storing that information locally and, when a remote model is configured, sending it to the selected model provider.

## Children's Privacy

ClaraCore Mobile is not designed for children and does not knowingly collect children's personal data.

## Contact

For support or privacy questions, use the Support page:

https://github.com/xiaomao361/claracore-mobile/blob/main/docs/app-store/support.md

## Changes

This policy may be updated as ClaraCore Mobile changes. The effective date above will be updated when the policy changes materially.
