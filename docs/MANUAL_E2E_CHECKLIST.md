# ClaraCore Mobile Manual E2E Checklist

Date: 2026-07-06
Scope: final manual validation before TestFlight or App Store submission

## Current Status

- Source repairs, local-rule organization, external-model configuration, original Archive, and App Store readiness checks are implemented in source.
- 2026-07-06: A Debug development-signed build was installed and launched on `zhouwei iphone` (iPhone 14 Pro) with bundle id `com.claracore.mobile`.
- 2026-07-06: `scripts/verify_app_store_submission_ready.sh` passed local readiness and screenshot-package gates, then correctly stopped at the remaining release blockers: Apple Distribution certificate, signed archive/export artifacts, and a clean committed/published release state.
- Before relying on this checklist for submission, run the current local automated gates and record the exact build number below.
- `scripts/verify_app_store_readiness.sh` includes the XCTest suite and a Release simulator install/launch smoke. You can also run `scripts/verify_unit_tests.sh` directly after logic changes or `scripts/smoke_simulator_launch.sh` directly after narrow project or plist changes.
- A fresh TestFlight pass is still required for the exact signed binary submitted to App Review.

## Preconditions

- Install and launch `ClaraCoreMobile` on the test iPhone.
- Record the app version and build from `设置` > `支持页面` before testing.
- If testing external model organization, save a model configuration in `设置`: Provider name, OpenAI-compatible Base URL, API Key, accept the external processing notice, then query available models and choose one returned model.
- If no API key is available, confirm the app clearly shows `本机规则` as the active organization mechanism and still creates conservative local memories / Shared Lines without sending content to a model provider.
- Use this DeepSeek share URL unless a fresher fixture is intentionally selected:

```text
https://chat.deepseek.com/share/suy08uspxl9wzja7uc
```

## Core Flow

1. Open `设置`.
2. Open `支持页面` and confirm it shows the app version and build number.
3. Open `隐私政策` and confirm it shows `生效日期：2026 年 7 月 3 日`.
4. If testing an external model, select `外部模型`, fill Provider, Base URL, and API Key, then accept the external processing notice.
5. Tap `查询模型`.
6. Confirm the returned model list appears.
7. If there are more than eight models, search by model id and confirm matching models remain selectable.
8. Select one model.
9. Confirm `默认整理模型` is read-only and cannot be manually typed.
10. Tap `保存配置`.
11. Confirm the `整理引擎` card shows the selected preference, the actual active mechanism, and the external model activation checklist.
12. If the checklist is complete but the runtime has not refreshed yet, confirm the UI says `配置完成：等待生效` instead of implying content is already being sent.
13. Edit the Base URL or selected model without tapping `保存配置`; confirm the `整理引擎` card says there are unsaved model configuration changes and still calculates enablement from the last saved configuration.
14. Tap `保存配置` again, then confirm the unsaved-change message disappears and the active mechanism updates immediately without a tab switch.
15. Tap `测试连接` and confirm visible success or a clear failure message.
16. Tap `删除 Key`, confirm the destructive dialog appears, approve deletion, and confirm `整理引擎` returns to `本机规则`.
17. Disable the external processing notice and confirm `整理引擎` remains or returns to `本机规则`.

## Import Flow

1. Open `导入`.
2. Paste the DeepSeek share URL.
3. Confirm the current role card is visible before importing.
4. Confirm `整理目标` defaults to `新建共同线`.
5. If existing Shared Lines are present, choose one and confirm the selected target is visibly marked.
6. If there are more than four Shared Lines, search by title or current milestone and confirm matching lines are shown.
7. Confirm `本次整理机制` shows whether this import will use `本机规则` or `外部模型`.
8. If `本次整理机制` is not already `外部模型`, tap `切换整理方式` or `补全启用条件`, confirm it switches to `设置`, then return to `导入`.
9. Tap `导入并整理`.
10. Confirm progress moves through prepare, segment, organize, reconcile, and commit.
11. During segment organization, confirm the progress title says `本机规则整理` or `外部模型整理`, matching `本次整理机制`.
12. Confirm the import screen switches to a result card.
13. Confirm the result card shows Memory count and the exact `写入共同线` title/current milestone.
14. Tap `查看共同线`.
15. Confirm the app switches to `共同线` and opens the recall package for the exact Shared Line shown on the result card.
16. Return to `导入`, then tap `查看记忆`.
17. Confirm committed memories appear in `记忆` and can be filtered by type/source/共同线.
18. Delete one test memory and confirm visible feedback appears.
19. Open `原文`, delete one test Archive entry, confirm the destructive dialog appears, and confirm it disappears from the list only after approving.
20. Confirm deleting an Archive entry does not automatically delete already written memories or Shared Lines.
21. Confirm copying or sharing Archive raw text explains it places the complete original text on the system clipboard or share sheet.
22. Open `记忆`, tap delete on one test memory, confirm the destructive dialog appears, and approve deletion only after confirming it is the intended memory.
23. Open `共同线`, tap delete on one test Shared Line, confirm the destructive dialog appears, and approve deletion only after confirming it is the intended line.
24. Re-import the same URL.
25. Confirm the duplicate result card appears instead of a blocking error.
26. Tap `查看共同线` on the duplicate result and confirm it opens the same committed Shared Line when the old record has line IDs.
27. Tap `重新整理一次` only if intentionally testing duplicate bypass.
28. Open `共同线`.
29. Confirm one new or updated Shared Line appears with a visible current station, completed milestones, and next action.
30. Confirm the Shared Line card exposes rich continuity state when available:
    - current state summary
    - current interpretation and interpretation status
    - position arc
    - emotional arc / affective trace
    - confirmed ground, boundary notes, and misread risks
31. Delete one test Shared Line and confirm visible feedback appears.
32. Tap `复制回召包`.
33. Confirm the screen explains it will not copy API Key, Base URL, model configuration, or the complete raw Archive.
34. Confirm the recall package includes:
    - `请接着这段关系和这条共同线继续`
    - `你现在的角色：`
    - `你正在面对的用户：`
    - `我们正在延续：`
    - `连续性状态：`
    - `需要记住的事实：`
    - `这次请这样继续：`
35. Clear the `接下来怎么继续` text, copy again, and confirm the package falls back to the default continuation instruction instead of leaving an empty request.
36. Paste the package into DeepSeek and confirm it can continue from the provided context without becoming overly academic.
37. Open Settings, tap `清除本机数据`, confirm the destructive dialog appears, approve only at the end of the test run.
38. Confirm Archive, Inbox, memories, Shared Lines, custom Context Cards, model configuration, and saved model keys are removed, and the default Context Card plus local-rule organization are restored.

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
- The app can copy a complete recall package without exposing API keys, model provider settings, or the complete raw Archive.
- A blank recall continuation request falls back to the default continuation instruction before copying.
- Duplicate imports show a recovery card with view/retry/continue actions.
- Current role selection persists across app launches.
- Save/delete/import actions produce visible feedback, and destructive deletion of Archive, Memory, or Shared Line requires confirmation.
- Archive raw copy clearly explains it places the complete original text on the system clipboard.
- Settings exposes a confirmed `清除本机数据` path that clears local user data, model configuration, and saved model keys.
- If the internal Inbox view is exposed during testing, discarding a pending import requires confirmation and does not delete already committed Archive, Memory, or Shared Line records.
- The Support page exposes the exact version/build a tester should include in bug reports.
- The built-in Privacy Policy exposes the current effective date.
- Saving model configuration updates the Settings status immediately without requiring a tab switch or app restart.
- Unsaved model configuration edits are clearly labeled as unsaved and do not change the active organization engine status until `保存配置` is tapped.
- The import screen gives a direct Settings path from `本次整理机制` when the external model is not active, so users can switch modes or complete activation without hunting through tabs.
- In-progress organization never labels the local-rule path as generic `模型整理`; it must say `本机规则整理` or `外部模型整理`.
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
- Local-rule import progress implies content is being sent to a model provider.
- The import screen shows `本机规则` but offers no direct path to configure or complete external-model activation.
