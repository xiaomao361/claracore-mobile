---
title: ClaraCore Mobile App Privacy Labels
permalink: /app-store/app-privacy-labels/
---

# ClaraCore Mobile App Privacy Labels

Date: 2026-07-06

Use this as the source of truth when filling App Store Connect > App Privacy.
Re-check this page before submission if analytics, accounts, crash reporting,
hosted sync, in-app purchases, ads, or a ClaraCore-operated backend are added.

## Tracking

Select:

```text
No, we do not use this app to track users.
```

Do not declare third-party advertising, tracking, or data broker sharing for the
current app.

## Data Linked To The User

Select:

```text
No.
```

Reason:

```text
ClaraCore Mobile does not create ClaraCore accounts and does not link app data to a developer-operated user profile.
```

## Data Not Linked To The User

Select:

```text
No developer-operated collection.
```

Reason:

```text
Imported conversations, original Archive entries, memories, Shared Lines, Context Cards, import history, and model configuration are stored locally on the device. ClaraCore does not operate a server that collects this data.
```

## User Content

For the current app, do not declare developer-operated collection of User
Content.

Use this conservative note if App Store Connect asks about content sent to
user-configured third-party providers:

```text
User Content
Purpose: App Functionality
Tracking: No
Advertising: No
Developer-side collection: No developer-operated server collection
Notes: Imported conversation content may be sent to a user-configured OpenAI-compatible model provider only after the user saves model configuration, accepts the external model processing notice, and starts organization.
```

Clipboard/share note:

```text
Copying a recall package to the clipboard or copying/sharing a complete original Archive entry is user-directed device behavior through the system clipboard or share sheet and is not collected by ClaraCore servers.
```

## Diagnostics

Do not declare Diagnostics collection for the current app.

Reason:

```text
The built-in Copy Diagnostics action copies a local support block to the user's clipboard. It does not send diagnostics to ClaraCore servers and excludes API keys, imported conversation text, memories, Shared Lines, and model provider configuration.
```

## Authentication Data

Do not declare developer-operated collection of authentication data.

Reason:

```text
A user-provided model API key is stored in a ThisDeviceOnly iOS Keychain item and sent only to the configured model provider as an Authorization header. It is not sent to ClaraCore servers.
```

## Categories To Leave Unselected

Leave these categories unselected unless the app adds a feature that actually
collects them through a developer-operated service:

```text
Contact Info
Health and Fitness
Financial Info
Location
Sensitive Info
Contacts
User Contacts
Browsing History
Search History
Identifiers
Purchases
Usage Data
Diagnostics
Other Data
Advertising Data
Tracking
```
