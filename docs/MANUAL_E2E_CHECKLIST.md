# ClaraCore Mobile Manual E2E Checklist

Date: 2026-07-01
Scope: final manual validation after source repair completion

## Current Status

- Source repairs are complete.
- Simulator verification passed with the full XCTest suite, 0 failed.
- Model configuration polish and rich Shared Line state have been added and installed on the test iPhone.
- True-device pass has been run on the test iPhone.

## Preconditions

- Install and launch `ClaraCoreMobile` on the test iPhone.
- If testing real reflection, save a default model configuration in `设置`: Provider name, OpenAI-compatible Base URL, API Key, then query available models and choose one returned model.
- If no API key is available, confirm the app stays in local placeholder mode and does not create durable candidates automatically.
- Use this DeepSeek share URL unless a fresher fixture is intentionally selected:

```text
https://chat.deepseek.com/share/suy08uspxl9wzja7uc
```

## Core Flow

1. Open `设置`.
2. If testing a remote model, fill Provider, Base URL, and API Key.
3. Tap `查询模型`.
4. Confirm the returned model list appears.
5. If there are more than eight models, search by model id and confirm matching models remain selectable.
6. Select one model.
7. Confirm `默认整理模型` is read-only and cannot be manually typed.
8. Tap `保存配置`.
9. Confirm the `整理引擎` card updates immediately without leaving the screen.
10. Tap `测试连接` and confirm visible success or a clear failure message.
11. If testing local placeholder mode, delete the saved key and confirm `整理引擎` returns to local placeholder mode.

## Import Flow

1. Open `导入`.
2. Paste the DeepSeek share URL.
3. Confirm the current role card is visible before importing.
4. Confirm `整理目标` defaults to `新建共同线`.
5. If existing Shared Lines are present, choose one and confirm the selected target is visibly marked.
6. If there are more than four Shared Lines, search by title or current milestone and confirm matching lines are shown.
7. Tap `导入并整理`.
8. Confirm progress moves through prepare, segment, model organize, reconcile, and commit.
9. Confirm the import screen switches to a result card.
10. Confirm the result card shows Memory count and the exact `写入共同线` title/current milestone.
11. Tap `查看共同线`.
12. Confirm the app switches to `共同线` and opens the recall package for the exact Shared Line shown on the result card.
13. Return to `导入`, then tap `查看记忆`.
14. Confirm committed memories appear in `记忆` and can be filtered by type/source/共同线.
15. Delete one test memory and confirm visible feedback appears.
16. Re-import the same URL.
17. Confirm the duplicate result card appears instead of a blocking error.
18. Tap `查看共同线` on the duplicate result and confirm it opens the same committed Shared Line when the old record has line IDs.
19. Tap `重新整理一次` only if intentionally testing duplicate bypass.
20. Open `共同线`.
21. Confirm one new or updated Shared Line appears with a visible current station, completed milestones, and next action.
22. Confirm the Shared Line card exposes rich continuity state when available:
    - current state summary
    - current interpretation and interpretation status
    - position arc
    - emotional arc / affective trace
    - confirmed ground, boundary notes, and misread risks
23. Delete one test Shared Line and confirm visible feedback appears.
24. Tap `复制回召包`.
25. Confirm the recall package includes:
    - `请接着这段关系和这条共同线继续`
    - `你现在的角色：`
    - `你正在面对的用户：`
    - `我们正在延续：`
    - `连续性状态：`
    - `需要记住的事实：`
    - `这次请这样继续：`
26. Paste the package into DeepSeek and confirm it can continue from the provided context without becoming overly academic.

## Secondary Import Paths

1. Paste a plain text transcript and confirm it follows the same one-step flow.
2. Import a `.txt` file and confirm it follows the same one-step flow.
3. Paste a known provider URL such as ChatGPT/Claude/Gemini/Kimi/Doubao/Qwen.
4. If the provider link is private or inaccessible, confirm the app says to use a public share link or copied text.

## Pass Criteria

- One import defaults to one Shared Line.
- Memories are few, factual, and bound to that Shared Line through `lineId` when a line is created.
- Memory cards show confidence/importance signals without compressing or overloading the card.
- A line-only digest with durable facts produces conservative fallback memories.
- Recall prefers memories related to the selected Shared Line.
- Recall preserves Shared Line continuity state, including position/emotional arc and boundary notes.
- The app can copy a complete recall package without exposing API keys.
- Duplicate imports show a recovery card with view/retry/continue actions.
- Current role selection persists across app launches.
- Save/delete/import actions produce visible feedback.
- Saving model configuration updates the Settings status immediately without requiring a tab switch or app restart.
- The default organization model is selected only from queried model results, not typed manually.
- No startup failure occurs if Keychain read fails or no default model key exists.

## Stop Criteria

- A single import creates multiple Shared Lines by default.
- Reflection writes broad summaries as durable memories.
- Recall package omits Context Card identity sections.
- API keys appear in logs, source files, fixtures, docs, or clipboard output.
- Duplicate import leaves the user stuck with no action.
- Shared Line cards do not show current station/progress.
- Shared Line cards or recall packages lose rich continuity state after import.
- Settings lets the user type an arbitrary default model id into the model field after model querying has been introduced.
