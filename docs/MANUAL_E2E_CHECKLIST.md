# ClaraCore Mobile Manual E2E Checklist

Date: 2026-06-29
Scope: first testable iOS build

## Preconditions

- Build and launch `ClaraCoreMobile` on an iPhone simulator.
- If testing real reflection, save a DeepSeek API key in `设置`.
- If no API key is available, confirm the app stays in local placeholder mode and does not create durable candidates automatically.
- Use this DeepSeek share URL unless a fresher fixture is intentionally selected:

```text
https://chat.deepseek.com/share/suy08uspxl9wzja7uc
```

## Core Flow

1. Open `导入`.
2. Paste the DeepSeek share URL.
3. Tap import.
4. Confirm a pending capture appears in `收件箱`.
5. Open the pending capture.
6. Tap organize.
7. Confirm the capture remains pending until commit or discard.
8. Review candidate memories and the Shared Line candidate.
9. Commit the digest.
10. Confirm committed memories appear in `记忆`.
11. Confirm one new `共同线` appears.
12. Open that Shared Line.
13. Confirm milestone text is rendered as a numbered step list.
14. Tap `复制回召包`.
15. Confirm the recall package includes:
    - `# Agent`
    - `# 用户`
    - `# 共同线`
    - `# 相关事实记忆`
    - `# 请求`
16. Paste the package into DeepSeek and confirm it can continue from the provided context.

## Pass Criteria

- One import defaults to one Shared Line.
- Candidate memories are few, factual, and bound to that Shared Line through `lineId`.
- Recall prefers memories related to the selected Shared Line.
- The app can copy a complete recall package without exposing API keys.
- No startup failure occurs if Keychain read fails or no DeepSeek key exists.

## Stop Criteria

- Import removes the inbox item before successful commit or discard.
- A single import creates multiple Shared Lines by default.
- Reflection writes broad summaries as durable memories.
- Recall package omits Context Card identity sections.
- API keys appear in logs, source files, fixtures, docs, or clipboard output.
