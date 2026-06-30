# ClaraCore Mobile Fix Plan

Date: 2026-06-30
Status: Active repair plan

## Why This Exists

This plan captures the real-device problems found after the first ClaraCore Mobile build and turns them into an implementation sequence.

The earlier app proved the basic loop:

```text
import -> inbox -> organize -> review -> commit -> memory / shared line -> recall package
```

The product should now move from a DeepSeek-specific prototype toward a broader AI conversation import and memory triage app, with a simpler daily path:

```text
import -> auto organize -> auto commit -> memory / shared line
```

Inbox can remain an internal recovery/history store, but it should not be a required user-facing step.

## Product Decisions

### 1. Importer Is A Major Product Surface

Importer is not a small DeepSeek helper. It should become a provider-aware import system that supports:

- AI conversation share URLs.
- Generic URLs when they contain useful conversation content.
- Plain text and `.txt` imports.
- Clipboard text.
- Future file exports from AI apps.

The implementation should use a registry:

```text
ConversationImporterRegistry
  -> DeepSeekShareImporter
  -> ChatGPTShareImporter
  -> ClaudeShareImporter
  -> GeminiShareImporter
  -> DoubaoShareImporter
  -> KimiShareImporter
  -> TongyiShareImporter
  -> GenericURLImporter
  -> TextImporter
```

Each importer should answer:

```text
canHandle(input)
import(input) -> RawCapture
sourceApp
sourceThreadId
confidence
```

Unknown URLs should not be rejected immediately. They should go through a generic URL path, then an LLM-assisted classification/extraction fallback when direct parsing fails.

### 2. DeepSeek Is A Default Provider, Not The Product Identity

User-facing copy should avoid making the whole app feel like a DeepSeek companion.

Preferred language:

- `AI 对话导入`
- `模型配置`
- `默认整理模型`
- `复制给外部 AI`
- `分享链接`

Provider-specific language is still allowed where it is useful:

- `DeepSeek 分享链接`
- `ChatGPT 分享链接`
- `Claude 分享链接`

### 3. Context Cards Become Multiple Role Spaces

The current default Context Card is too small for the intended workflow. The product should support multiple role cards.

Rules:

- A memory belongs to one role card.
- A shared line belongs to one role card.
- An inbox item and import session should capture the selected role card.
- Recall should search inside the selected role space first.
- If no role card exists, the user should create one before import.
- Automatic role-card creation can be suggested by the organizer, but should require confirmation before saving.

Schema direction:

```text
context_cards
  id
  title
  agent_profile
  user_profile
  created_at
  updated_at

memories.context_card_id
continuity_lines.context_card_id
inbox.context_card_id
import_sessions.context_card_id
```

### 4. Navigation Follows The Real Workflow

Tab order should become:

```text
导入 -> 记忆 -> 共同线 -> 设置
```

Recall should live inside Shared Line detail unless it proves important enough to become a tab later.

### 5. Memory Is Not A Manual Writing Surface

The Memory page should not center manual entry.

Keep:

- Search.
- Filter.
- Edit.
- Archive/delete.
- Source trace.
- Tag and role indicators.

Remove from the primary UI:

- Manual memory creation form.

Manual correction is still allowed through edit flows.

### 6. Recall Copy Should Be Role-Led, Not Academic

The current recall package sounds too formal and makes the receiving AI answer in a stiff style. Recall should read like a continuation brief for a role, not a research report.

Target shape:

```text
你现在继续使用下面这个角色和用户关系。

【角色】
...

【用户】
...

【我们正在延续的事】
标题：...
已经走到：
1. ...
2. ...
接下来先做：...

【需要记住的事实】
1. ...

请自然接着这个状态继续。不要把这些内容改写成报告；如果信息不足，先问我。
```

## Confirmed Problems

### P0: Dark Mode Breaks Text Inputs And Some Surfaces

Symptoms:

- System dark mode makes text fields and related surfaces render with wrong foreground/background combinations.
- The app does not currently have a coherent dark-mode token strategy.

Decision:

- Short term: force the app into light mode if full dark-mode support is not ready.
- Longer term: make `ClaraDesign` tokens dynamic and verify TextField/TextEditor backgrounds explicitly.

Acceptance:

- API key field, importer text editor, context card editors, memory edit sheet, and recall request field are readable in system dark mode.
- No white text on white surface or dark text on dark surface.

### P0: Keyboard Can Trap The User

Symptoms:

- Text input keyboard, such as the API key field, does not dismiss naturally.
- User had to quit and reopen the app.

Fix direction:

- Add `scrollDismissesKeyboard(.interactively)` to scroll-based input screens.
- Add keyboard toolbar with `完成`.
- Add background tap dismissal on large editor screens.
- Ensure bottom buttons remain reachable above keyboard.

Acceptance:

- User can enter and save API key without leaving the app.
- User can paste/import a long text and dismiss keyboard by scrolling or tapping done.

### P0: Import Flow Has Too Many User Steps

Symptoms:

- User has to import, open inbox, tap organize, review, then commit.
- This is useful for debugging extraction but too heavy for normal use.

Fix direction:

- On import:
  - enqueue internally for duplicate tracking;
  - prepare session;
  - organize with progress;
  - commit accepted candidates directly;
  - mark the internal inbox row committed;
  - show a concise completion summary.

Acceptance:

- One tap on import completes the normal flow.
- If the result is wrong, the user deletes the memory or shared line directly.
- Inbox is not required as a main tab.

### P0: Saved Actions Lack Clear Feedback

Symptoms:

- Some saves do not show a clear confirmation.

Fix direction:

- Use a consistent lightweight status/toast component for save/import/commit/delete/update actions.
- Important changes should update visible state immediately.

Acceptance:

- Saving provider key, saving role card, editing memory, committing digest, archiving memory, and updating shared line all produce visible feedback.

### P1: Organizing Progress Is Too Opaque

Symptoms:

- Current organizing state is mostly a text status.
- User cannot tell whether the app is fetching, segmenting, reflecting, reconciling, or stuck.

Fix direction:

- Add a compact progress surface in Inbox item cards and/or review sheet:
  - fetching source;
  - creating import session;
  - segmenting;
  - reflecting segment `n / total`;
  - reconciling;
  - ready for review.
- Persist enough state to recover or explain after interruption.

Acceptance:

- During organize, the active item visibly changes state.
- For multi-segment imports, progress shows current segment and total.

### P1: Importer Scope Is Too Narrow

Symptoms:

- Current URL handling is DeepSeek-specific.
- Many AI apps provide share links and should be supported.

Fix direction:

- Introduce importer registry and provider-specific parsers.
- Start with URL detection by domain.
- Add `.txt` and raw text as first-class import types.
- Add fixtures per provider before enabling parsing.
- Add generic URL fallback and LLM-assisted extraction after deterministic importers.

Initial provider priority:

1. DeepSeek share URL.
2. Generic text / `.txt`.
3. ChatGPT share URL.
4. Claude share URL.
5. Kimi / Doubao / Tongyi / Gemini based on real share samples.
6. Generic URL fallback.

Acceptance:

- Import view identifies known provider URLs.
- Unknown URLs are accepted into a fallback path instead of being treated as plain manual text without metadata.
- Provider parsers have fixture tests.

### P1: Memory And Shared Line Quality Is Weak

Symptoms:

- Extracted memories and shared lines do not feel useful enough.
- Memory and shared line boundaries need sharper prompts and review UI.

Fix direction:

- Rework extraction prompts:
  - Memory: stable fact, preference, decision, durable user/project truth.
  - Shared Line: current process state, milestones, next action.
  - Do not store general notes as memory.
- Allow `preference` memories where appropriate instead of silently dropping them.
- Prefer one coherent shared line per import unless source clearly spans unrelated topics.
- Let user merge into an existing line later.

Acceptance:

- Review digest separates `事实记忆`, `偏好`, `决定`, and `共同线`.
- A single import usually produces one useful shared line and a small number of memories.

### P1: Memory List Visual Structure Is Not Good Enough

Symptoms:

- Memory page style is messy.
- Tags and identifiers are insufficient.
- It should borrow more from ClaraCore Memoria.

Fix direction:

- Redesign memory cards around:
  - content;
  - kind: fact / preference / decision / task;
  - tags;
  - role card;
  - source app;
  - linked shared line;
  - created/updated time;
  - private/archive status;
  - confidence or reviewed marker if available.

Acceptance:

- Memory list is scannable.
- Every memory has visible provenance and type.
- Tags are ordered and readable.

### P1: Role Card Flow Is Underpowered

Symptoms:

- Current role card is a single default card.
- The product needs multiple role contexts.
- Import, memory, and shared line should be role-aware.

Fix direction:

- Add role card list and create/edit flow.
- Add role selector to import flow.
- Bind import session, memory, and shared line to role card.
- If no role card exists, block import behind a minimal create-card sheet.
- Add candidate role-card suggestions later, not silent auto-create.

Acceptance:

- User can create more than one role card.
- Import asks which role space this conversation belongs to.
- Recall uses the selected role card.

### P2: Recall Prompt Tone Is Too Academic

Symptoms:

- External AI receives a formal package and responds in a formal/academic tone.

Fix direction:

- Rewrite recall package around role continuation.
- Use warm direct Chinese.
- Avoid headings like a technical report unless the user chooses that mode.

Acceptance:

- Copied recall text asks the external AI to continue naturally from role, user, shared line, and facts.

### P2: DeepSeek-Specific UI Copy Leaks Product Direction

Symptoms:

- Several screens imply the whole product is DeepSeek-specific.

Fix direction:

- Rename UI copy to provider-neutral wording.
- Keep provider names only for source labels and configuration rows.

Acceptance:

- User can understand ClaraCore as an AI conversation memory app, not a DeepSeek-only utility.

## Implementation Sequence

### Phase 1: Real-Device Usability Repair

Goal:

Fix the problems that made the current app hard or impossible to use.

Status:

- 2026-06-30: Initial implementation completed for light-mode lock, keyboard dismissal, commit sheet dismissal, tab order, Memory manual-write removal, and basic visible feedback.
- 2026-06-30: Import flow simplified after product review. Import now auto-organizes and commits; Inbox is removed from the main tab flow.

Tasks:

1. Stabilize light/dark rendering.
2. Add keyboard dismissal and keyboard-safe layout.
3. Fix commit-success navigation and feedback.
4. Add consistent save/import/commit status feedback.
5. Reorder tabs to `导入 -> 记忆 -> 共同线 -> 设置`.
6. Remove manual memory creation from primary Memory UI.

Validation:

- Manual device check for dark mode, API key entry, import text entry, commit result, and tab order.
- Unit tests only where store behavior changes.
- 2026-06-30: Simulator compile build passed through XcodeBuildMCP `build_sim`; real-device manual check still needed.

### Phase 2: Provider-Neutral Copy And Progress

Goal:

Make the current DeepSeek-backed implementation feel provider-neutral and more transparent during organizing.

Status:

- 2026-06-30: Initial implementation completed for provider-neutral UI copy, organizer progress states, provider import error messages, LLM range guarding, and external-AI recall labels.

Tasks:

1. Rename visible copy from DeepSeek-specific workflow to AI conversation import / default model language.
2. Keep DeepSeek as default provider in Settings.
3. Add organize progress stages.
4. Improve importer status labels.
5. Improve error messages for provider import and LLM failures.
6. Guard LLM-provided ranges before creating provenance ranges.

Validation:

- Organize shows stage and segment progress.
- Invalid provider responses show user-readable errors.
- Bad LLM ranges do not crash the app.
- 2026-06-30: XcodeBuildMCP `build_sim` passed; XcodeBuildMCP `test_sim` passed 32 tests, 0 failed.

### Phase 3: Importer Registry

Goal:

Turn importer into an extensible system before adding many providers.

Status:

- 2026-06-30: Initial registry skeleton completed. DeepSeek share URLs and manual text now route through `ConversationImporterRegistry`; unknown URLs route to a generic fallback placeholder; duplicate detection by content hash/source thread is surfaced before enqueue.
- 2026-06-30: Generic URL fallback now fetches public `text/html`, `application/xhtml+xml`, and `text/plain` links, extracts readable text, preserves URL/title metadata, and queues the result as a URL capture. Provider-specific parsers and LLM-assisted extraction remain future work.
- 2026-06-30: Provider URL profiles added for common AI share domains. ChatGPT, Claude, Gemini, Kimi, Doubao, and Tongyi/Qwen links are now identified before generic fallback, preserve provider metadata, and use the generic public webpage/text extraction path until real provider fixtures are available.
- 2026-06-30: `.txt` import is now first-class. Import view exposes a file picker, `.txt` files route through `FileConversationImporter`, and resulting captures preserve file source metadata before entering the same inbox path.
- 2026-06-30: Importer now drives the whole happy path. A successful import automatically prepares, organizes, commits memories/shared lines, and marks the internal inbox item committed.

Tasks:

1. Introduce `ConversationImportInput`.
2. Introduce `ConversationImporter` protocol.
3. Introduce `ConversationImporterRegistry`.
4. Move DeepSeek share handling behind the protocol.
5. Add `TextImporter` for raw text and `.txt`.
6. Add generic URL placeholder path.
7. Add duplicate detection by content hash and/or source thread id.
8. Add fixtures and tests for each importer.

Validation:

- DeepSeek import still works through registry.
- Text import works through registry.
- Unknown URL is routed to generic URL fallback.
- Duplicate import is detected or clearly presented as existing.
- 2026-06-30: XcodeBuildMCP `build_sim` passed; XcodeBuildMCP `test_sim` passed 36 tests, 0 failed.
- 2026-06-30: Generic URL fallback update passed XcodeBuildMCP `build_sim`; XcodeBuildMCP `test_sim` passed 39 tests, 0 failed.
- 2026-06-30: Provider URL profile update passed XcodeBuildMCP `build_sim`; XcodeBuildMCP `test_sim` passed 41 tests, 0 failed.
- 2026-06-30: `.txt` file import update passed XcodeBuildMCP `build_sim`; XcodeBuildMCP `test_sim` passed 43 tests, 0 failed.

### Phase 4: Multiple Role Cards

Goal:

Make role cards the identity boundary for memories, shared lines, and recalls.

Status:

- 2026-06-30: Initial role-space plumbing completed. `context_card_id` now flows through inbox, import sessions, memories, and shared lines; import can select a role card; settings can create/edit multiple role cards; commit and recall use the bound role.

Tasks:

1. Add migrations for `context_card_id`.
2. Add role card list and create/edit UI.
3. Add selected role state.
4. Add role selection to import.
5. Bind inbox/import session/memory/shared line to role.
6. Update recall builder to use selected role.
7. Add tests for role-scoped recall and memory search.

Validation:

- Two role cards can hold separate imports.
- Memories from role A do not pollute role B recall by default.
- Shared line detail displays its role card.
- 2026-06-30: XcodeBuildMCP `build_sim` passed; XcodeBuildMCP `test_sim` passed 38 tests, 0 failed.

### Phase 5: Memory And Shared Line Quality Pass

Goal:

Make extracted outputs useful enough for daily use.

Status:

- 2026-06-30: Initial quality pass completed. Durable preferences are retained, review groups candidate memories by type, memory cards show type/source/role/line/tag signals, shared line cards separate current position from next step, and recall copy now uses role-continuation wording.

Tasks:

1. Revise extraction prompts and schema.
2. Preserve preference memories when durable.
3. Improve review grouping.
4. Add memory source/type/tag indicators.
5. Improve shared line detail and milestone rendering.
6. Add merge-to-existing-line affordance if needed.
7. Rewrite recall text into role-continuation style.

Validation:

- Review output feels small, durable, and actionable.
- Memory cards show type, role, source, tags, and linked line.
- Recall output produces more natural continuation in external AI.
- 2026-06-30: XcodeBuildMCP `build_sim` passed; XcodeBuildMCP `test_sim` passed 38 tests, 0 failed.

## Non-Goals For This Repair Batch

- Building a full in-app chat surface.
- Adding InnerLife as a runtime dependency.
- Building a cloud sync service.
- Supporting screenshots/OCR before URL and text import are solid.
- Fully solving all AI provider formats without real examples and fixtures.

## Open Questions

1. Which providers should be first after DeepSeek and `.txt`?
2. Should role selection happen before every import, or should the app remember a current active role?
3. Should unknown URLs be fetched locally first, or sent directly to LLM classification after user confirmation?
4. Should duplicate imports be blocked, merged, or allowed with a warning?
5. Should recall have tone presets, or should the role card fully control tone?

## Working Rule

Optimize in small verified loops:

```text
one phase -> implementation -> focused tests/manual device check -> update this plan
```

Do not expand importer provider support without fixtures from real shared URLs or exported files.
