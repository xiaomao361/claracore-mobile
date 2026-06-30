# ClaraCore Mobile Manual E2E Checklist

Date: 2026-06-30
Scope: one-step import repair pass

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
3. Confirm the current role card is visible before importing.
4. Tap `导入并整理`.
5. Confirm progress moves through prepare, segment, model organize, reconcile, and commit.
6. Confirm the import screen switches to a result card.
7. Confirm the result card shows Memory and Shared Line counts.
8. Tap `查看记忆`.
9. Confirm committed memories appear in `记忆` and can be filtered by type/source/共同线.
10. Delete one test memory and confirm visible feedback appears.
11. Re-import the same URL.
12. Confirm the duplicate result card appears instead of a blocking error.
13. Tap `重新整理一次` only if intentionally testing duplicate bypass.
14. Open `共同线`.
15. Confirm one new Shared Line appears with a visible current station, completed milestones, and next action.
16. Delete one test Shared Line and confirm visible feedback appears.
17. Tap `复制回召包`.
18. Confirm the recall package includes:
    - `# Agent`
    - `# 用户`
    - `# 共同线`
    - `# 相关事实记忆`
    - `# 请求`
19. Paste the package into DeepSeek and confirm it can continue from the provided context.

## Secondary Import Paths

1. Paste a plain text transcript and confirm it follows the same one-step flow.
2. Import a `.txt` file and confirm it follows the same one-step flow.
3. Paste a known provider URL such as ChatGPT/Claude/Gemini/Kimi/Doubao/Qwen.
4. If the provider link is private or inaccessible, confirm the app says to use a public share link or copied text.

## Pass Criteria

- One import defaults to one Shared Line.
- Memories are few, factual, and bound to that Shared Line through `lineId` when a line is created.
- A line-only digest with durable facts produces conservative fallback memories.
- Recall prefers memories related to the selected Shared Line.
- The app can copy a complete recall package without exposing API keys.
- Duplicate imports show a recovery card with view/retry/continue actions.
- Current role selection persists across app launches.
- Save/delete/import actions produce visible feedback.
- No startup failure occurs if Keychain read fails or no DeepSeek key exists.

## Stop Criteria

- A single import creates multiple Shared Lines by default.
- Reflection writes broad summaries as durable memories.
- Recall package omits Context Card identity sections.
- API keys appear in logs, source files, fixtures, docs, or clipboard output.
- Duplicate import leaves the user stuck with no action.
- Shared Line cards do not show current station/progress.
