# ClaraCore Mobile

ClaraCore Mobile is the iOS capture surface for ClaraCore.

The first milestone is deliberately small and verified in order:

1. Store local memories on device.
2. Recall them with SQLite FTS5.
3. Queue raw captures in Inbox.
4. Segment large imports into resumable import sessions.
5. Import DeepSeek shared conversations from `https://chat.deepseek.com/share/{shareId}`.
6. Reflect segments into conservative memory and one Shared Line candidate per import.
7. Copy a recall package back into an external AI app.

Current product model:

- `角色卡 / Context Card`: who the agent is and who the user is.
- `共同线 / Shared Line`: where one continuing topic/process has arrived.
- `记忆 / Memory`: a small number of durable facts or decisions.

V1 should keep memory low-presence. The user mainly chooses a Context Card and a Shared Line; related memories are attached automatically during recall.

This project starts with SwiftUI and GRDB.swift.

Development follows [Architecture And Build Sequence](docs/ARCHITECTURE_AND_SEQUENCE.md).

App Store preparation materials live in [docs/app-store](docs/app-store/index.md).
