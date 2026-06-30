# ClaraCore Mobile Architecture And Build Sequence

Date: 2026-06-29
Status: Active development baseline

## Development Checkpoint: 2026-06-30

Current node:
- The project has a bootable SwiftUI / GRDB iOS app under `ClaraCore/apps/claracore-mobile`.
- The UI is intentionally functional and Chinese-first, but visual/product UI refinement is owned by a separate UI session from this point.
- This development track should continue focusing on data flow, reflection reliability, persistence, tests, and end-to-end behavior.
- The product model has been simplified around Context Card + Shared Line + Memory:
  - Context Card defines who the agent is and who the user is.
  - Shared Line tracks the process/state of one continuing topic.
  - Memory stores a small number of durable facts or decisions.

Implemented and verified:
- App shell with tabs: 导入, 记忆, 共同线, 设置.
- Local SQLite migrations for Memoria, Inbox, Import Sessions, Capture Segments, and Continuity Lines.
- Manual text, clipboard text, and DeepSeek share URL import.
- DeepSeek share URL decoding through `https://chat.deepseek.com/api/v0/share/content?share_id={shareId}`.
- Capture segmentation and import session preparation.
- Reflection abstraction with local placeholder and OpenAI-compatible remote model implementation.
- Default model configuration for any OpenAI-compatible `/chat/completions` endpoint; API keys are stored through local Keychain settings and must not be written to source, fixtures, docs, or git.
- Startup fallback: Keychain read failures must not block app launch; the app falls back to local placeholder mode.
- Digest commit path from candidate memories / Shared Line updates into local stores.
- Default Context Card persistence with Agent / User profiles.
- Recall packaging from the default Context Card plus one Shared Line and selected factual memories into a copyable DeepSeek context package.
- Committed memories can now bind to the Shared Line created from the same digest through `lineId`; recall prefers line-bound memories before falling back to FTS.
- Shared Line milestone text renders as structured steps in the list and recall package surfaces.
- Settings exposes the default Context Card editor for Agent / User profiles.
- Import behavior: user-facing flow is one step. Importer queues an internal inbox row for duplicate/status tracking, automatically prepares/organizes/commits, then marks the internal row committed.
- App icon asset catalog exists at `ClaraCoreMobile/Assets.xcassets/AppIcon.appiconset`.
- Manual first-build end-to-end checklist exists at `docs/MANUAL_E2E_CHECKLIST.md`.
- DeepSeek real end-to-end path now targets:
  - Import -> auto organize -> auto commit -> memory list -> Shared Line list -> recall package copy.
- Reflection output has been tightened:
  - default memory candidates are few and conservative;
  - memories should be facts or decisions, not summaries;
  - one import should default to one Shared Line;
  - Shared Line `lastPosition` should read as milestone steps.

Latest verification:
- `plutil -lint ClaraCoreMobile.xcodeproj/project.pbxproj`
- `python3 -m json.tool ClaraCoreMobile/Assets.xcassets/Contents.json`
- `python3 -m json.tool ClaraCoreMobile/Assets.xcassets/AppIcon.appiconset/Contents.json`
- XcodeBuildMCP `build_sim`
- XcodeBuildMCP `test_sim`: 31 tests passed, 0 failed
- XcodeBuildMCP `build_run_sim`: app installed and launched on iPhone 17 simulator

Next technical work, independent from UI polish:
1. Run the manual first-build checklist on simulator and record any product/data-flow gaps.
2. Keep UI polish in the separate UI session unless a visual issue blocks the checklist.

UI session boundary:
- The UI session may change layout, copy, visual hierarchy, empty states, and interaction affordances.
- It should not change Core schemas, reflection prompts, importer parsing, or commit semantics without updating this document.
- Keep the first testable build standard aligned with the simplified flow: import DeepSeek share link -> auto organize and commit -> see memory and Shared Line -> copy recall package for DeepSeek.

## Product Boundary

ClaraCore Mobile is the human capture surface for ClaraCore. It is not another AI chat app.

The first version primarily targets domestic Chinese users. Importer priorities, product copy, provider order, and fixture coverage should therefore start with Chinese-language workflows and domestic AI products before expanding to global providers.

The mobile app must do five things well:

1. Capture useful material from mobile AI usage.
2. Automatically organize useful captures into durable memory and Shared Lines.
3. Let the user correct mistakes by editing or deleting the resulting memory/Shared Line.
4. Store and recall committed memories locally.
5. Preserve lightweight continuity through the Shared Line.

InnerLife is not part of the v1 mobile core. It may become a post-v1 remote reflection enhancement, but it must not be a dependency for capture, review, commit, search, or Shared Line.

## Current Product Model

The app should not expose a complicated project/folder/source taxonomy in v1. The simplified mental model is:

```text
Context Card = identity context
Shared Line = ongoing process
Memory = durable facts
Import Session = one external conversation snapshot
```

### Context Card

Chinese UI name: `角色卡`.

Purpose:
- Provide the stable identity context used when copying a recall package into DeepSeek, Claude, Doubao, or another external AI app.
- Answer two simple questions:
  - Agent 是谁？
  - 用户是谁？

V1 fields should stay minimal:

```text
ContextCard
- id
- title
- agentProfile
- userProfile
- createdAt
- updatedAt
```

Do not add card types, folders, complex role systems, or provider-specific settings yet. The first build can ship with one default editable card.

Default card intent:

```text
Agent:
你是一个帮助用户延续跨应用对话上下文的助手。

User:
用户希望你基于共同线和事实记忆继续，不要假设未提供的信息；如果信息不足，先指出缺口。
```

### Shared Line

Chinese UI name: `共同线`.

Purpose:
- Track one continuing topic, task, scene, project, or conversation arc.
- Store where the conversation/process has arrived and what should happen next.
- Preserve enough continuity state for copy-to-external-AI use, including the visible position/emotional arc and the current interpretation.

V1 rule:
- One import session defaults to one Shared Line.
- The system may later let the user merge an import into an existing line, but a single import should not automatically fan out into multiple lines.
- Shared Line text should be milestone-like, not a paragraph summary.
- Shared Line is richer than Memory on mobile. The phone flow is not an agent runtime, but copied context still needs the continuity state that helps an external AI continue in the right tone and position.
- Required rich fields:
  - `stateSummary`: short current-state summary.
  - `currentInterpretation`: what the line currently means.
  - `interpretationStatus`: confirmed / provisional / conflict / unknown.
  - `emotionalArc`: compact visible position and emotional curve.
  - `affectiveTrace`: tone, valence, intensity, stability, signals, and note.
  - `realityLine`: confirmed ground facts.
  - `boundaryNotes`: what should not be over-assumed.
  - `misreadRisks`: likely wrong readings to avoid.

Good `lastPosition` shape:

```text
1. 已完成 DeepSeek 分享链接导入
2. 已完成真实整理入库
3. 正在调整记忆和共同线模型
```

Good `nextStep` shape:

```text
实现角色卡式回召包结构。
```

### Memory

Chinese UI name: `记忆`.

Purpose:
- Store a small number of durable facts, decisions, and stable user/project truths.
- Support recall automatically when the user selects a Shared Line.

V1 rule:
- Memory should not be the user's main operation surface.
- The user primarily manages Shared Lines and Context Cards.
- Memory is a factual substrate: visible, editable, deletable, but low-presence.
- Do not store general topic notes, product explanations, comparison points, or every technical detail as memory.
- Mobile Memory is intentionally smaller than full ClaraCore Memoria. It should keep content, tags, source, role/line linkage, confidence, and importance, but it does not need to mirror every Memoria-side parameter.

Good memory examples:

```text
用户决定 ClaraCore Mobile v1 主要面向国内用户。
我们完成了 DeepSeek 分享链接导入到回召包复制的端到端闭环。
一次导入默认只应归入一条共同线。
```

Bad memory examples:

```text
DeepSeek 分享链接会生成只读快照。
截图 OCR 也可以导出对话。
分享链接比 OCR 解析成本低。
```

Those may be source details or line milestones, but they are usually not durable personal memory.

### Import Session

Purpose:
- Represent one imported external conversation snapshot.
- Preserve `source`, `sourceThreadId`, content hash, raw transcript, segment provenance, and resulting line/memory candidates.

V1 rule:
- A DeepSeek share link import is treated as one external conversation snapshot.
- It should produce one digest, one default Shared Line, and a small number of memories bound to that line.
- Later imports from the same topic can be merged into an existing Shared Line, but that merge UX is post-current-node.

### Recall Package

The recall package should be built from:

```text
selected Context Card
  + selected Shared Line
  + related Memories
```

Target structure:

```text
# Agent
...

# 用户
...

# 共同线
标题：
里程碑：
1. ...
2. ...
下一步：
...

# 相关事实记忆
1. ...
2. ...

# 请求
请基于以上上下文继续。不要假设未提供的信息；如果信息不足，先指出缺口。
```

The current implementation builds this structure from the default Context Card, selected Shared Line, and selected related memories.

## V1 Modules

### 1. Memoria

Responsibility:
- Local SQLite persistence.
- FTS5 recall with BM25 ranking.
- Store, recall, get, archive, restore, tag.
- Schema parity where practical with ClaraCore Memoria records and memory concepts.

Does not own:
- Capture source handling.
- Review decisions.
- UI navigation.
- AI reflection.

Primary code:
- `ClaraCoreMobile/Core/Database/`
- `ClaraCoreMobile/Core/Memoria/`
- `ClaraCoreMobile/Features/Memoria/`

### 2. Importer

Responsibility:
- Receive raw material from manual input, clipboard, Share Sheet, files, or URLs.
- Normalize source metadata into `RawCapture`.
- Preserve source tracking for future incremental merge: `sourceApp`, `sourceThreadId`, `contentHash`, and `capturedAt`.
- Queue captures into the internal Inbox table for duplicate/status tracking.
- Drive the normal user path through automatic organize and commit.

V1 supported inputs:
- Manual text entry.
- Clipboard text import.
- `.txt` file import.
- URL import for DeepSeek shared conversations, using `https://chat.deepseek.com/share/{shareId}`.
- Generic public text/html URL fallback and provider-domain recognition.

V1 importer support matrix:

| Source | Status | Handling |
| --- | --- | --- |
| DeepSeek share URL | Must support in v1 | Extract `{shareId}` from `https://chat.deepseek.com/share/{shareId}`, fetch `https://chat.deepseek.com/api/v0/share/content?share_id={shareId}`, decode turns, and convert to one immutable `RawCapture`. |
| Manual text | Must support in v1 | Store exactly what the user enters as a `RawCapture` with source metadata. |
| Clipboard text | Must support in v1 | Store clipboard text as a `RawCapture`; use content hash for duplicate detection. |
| `.txt` file | Must support in v1 | Read plain text from the selected file and preserve filename metadata. |
| Other domestic AI share URLs | Provider profile first | Identify common provider domains and use generic text/html extraction until real fixtures support parser-specific handling. |
| Generic URL | Supported as fallback | Fetch public text/html or text/plain pages and extract readable text; LLM-assisted extraction remains future work. |
| ChatGPT / Claude share URL | Deferred | Add after domestic provider flows are stable and their share formats are inspected and covered by fixture tests. |
| File export | Deferred | Add after import session and digest rollback are stable. |

Deferred inputs:
- Generic webpage extraction.
- ChatGPT / Claude share links.
- File export import.
- Photos, audio, screenshots, and PDFs.

Does not own:
- Memory commit policy.
- AI analysis.
- Continuity updates.

Primary code:
- `ClaraCoreMobile/Core/Importer/`
- `ClaraCoreMobile/Features/Importer/`
- future `ShareExtension/`

### 3. Import Session / Reflection / Digest

Responsibility:
- List pending captures.
- Convert a raw capture into an import session.
- Split large conversations into resumable capture segments.
- Run reflection jobs segment by segment.
- Reconcile segment drafts into one digest.
- Auto-commit provisional results with provenance when LLM reflection is enabled.
- Keep raw captures immutable; Reflection may create commit suggestions, but Importer does not overwrite existing memory or continuity.

Does not own:
- SQLite table migrations except through Core stores.
- Provider-specific app import logic.
- Long-running background execution guarantees on iOS.

Primary code:
- `ClaraCoreMobile/Core/Inbox/`
- `ClaraCoreMobile/Core/Importer/`
- `ClaraCoreMobile/Core/Reflection/`
- `ClaraCoreMobile/Core/Settings/`
- `ClaraCoreMobile/Features/Inbox/`
- `ClaraCoreMobile/Features/Review/`

Runtime provider rule:
- API keys must be stored locally in Keychain, never in source files, fixtures, or docs.
- If a default model key and valid OpenAI-compatible configuration exist, `AppDependencies` uses `OpenAICompatibleReflectionService`.
- If no model key exists, the app falls back to `RuleBasedReflectionService`, which is intentionally a local placeholder and does not create commit candidates.

### 4. Continuity / Shared Line

Responsibility:
- Track continuation threads.
- Store title, status, last position, next step, and rich continuity state.
- Let reviewed captures update or create Shared Line entries.
- Support recall packaging: the user selects one Shared Line, attaches relevant factual memories, and copies the package into DeepSeek or another external AI app.

Does not own:
- Long-term fact memory.
- Background agent state.

Rich state owned by Shared Line:

- `stateSummary`
- `currentInterpretation`
- `interpretationStatus`
- `emotionalArc`
- `affectiveTrace`
- `realityLine`
- `boundaryNotes`
- `misreadRisks`

This state is not meant to make mobile an agent. It exists so a copied recall package can preserve position, tone, confirmed ground, and misread boundaries when pasted into an external AI.

Primary code:
- `ClaraCoreMobile/Core/Continuity/`
- `ClaraCoreMobile/Core/Recall/`
- `ClaraCoreMobile/Features/Continuity/`
- `ClaraCoreMobile/Features/Recall/`

### Recall To External AI

The mobile recall flow is not a chat surface. It prepares context for an external AI app.

V1 recall flow:

```text
User selects a Shared Line
  -> app recalls related factual memories from Memoria
  -> user selects or removes memories
  -> app builds a copyable context package
  -> user pastes it into DeepSeek
```

The package should be structured as:

```text
# 共同线
Title:
Last position:
Next step:

【连续性状态】
当前状态:
当前解释:
位置/情绪弧线:
确认事实:
边界:
误读风险:

# 相关事实记忆
- ...

# 给 DeepSeek 的请求
请基于以上上下文继续，不要改写事实记忆。
```

Importer and Reflection must not own this flow. It belongs to Continuity + Memoria + a small recall packaging service.

### 5. Gateway / Automation

Responsibility:
- Post-v1 or late-v1 local access for Shortcuts and future agents.
- Foreground-only local HTTP or App Intent surfaces.
- Read/write through existing Core stores.

Does not own:
- MCP daemon behavior.
- Background execution.
- Desktop service management.

Primary code:
- `ClaraCoreMobile/Core/Gateway/`
- `ClaraCoreMobile/Features/Settings/`

## Directory Standard

All new code should follow this layout:

```text
ClaraCoreMobile/
├── App/
│   ├── ClaraCoreMobileApp.swift
│   ├── AppRootView.swift
│   ├── AppTab.swift
│   └── AppDependencies.swift
├── Core/
│   ├── Database/
│   ├── Memoria/
│   ├── Importer/
│   ├── Inbox/
│   ├── Reflection/
│   ├── Continuity/
│   ├── Recall/
│   ├── Settings/
│   └── Gateway/
├── Features/
│   ├── Memoria/
│   ├── Importer/
│   ├── Inbox/
│   ├── Review/
│   ├── Continuity/
│   ├── Recall/
│   └── Settings/
└── Shared/
    ├── Components/
    ├── Support/
    └── Fixtures/

ClaraCoreMobileTests/
├── Core/
│   ├── Memoria/
│   ├── Importer/
│   ├── Inbox/
│   ├── Continuity/
│   ├── Recall/
│   └── Settings/
└── Features/
```

## Dependency Rules

Core modules may depend on:
- Swift Foundation.
- GRDB where persistence is required.
- Other Core protocols only when the dependency is explicit and narrow.

Feature modules may depend on:
- SwiftUI.
- Core module protocols or services.
- Shared UI components.

Feature modules must not:
- Open SQLite directly.
- Run migrations.
- Know Share Extension storage details.
- Call future InnerLife services directly.

App shell may depend on:
- SwiftUI.
- Core store construction.
- Feature root views.

Tests should mirror the production directory. Each module needs at least one store or workflow test before UI work builds on it.

## State And Navigation Rules

Use SwiftUI-native state:
- `@State` for local view state.
- `@Observable` root services only when shared broadly.
- Initializer injection for feature-local stores.
- Environment injection only for app-level dependencies used across multiple feature roots.

The app shell should become:

```text
TabView
├── Inbox
├── Memoria
├── Shared Line
└── Settings
```

Do not add global singleton state unless there is a concrete cross-feature lifecycle requirement.

## Build Sequence

### Phase 0: Memoria Foundation

Goal:
- Local SQLite opens.
- Memoria schema migrates.
- Store then recall works through FTS5.
- Minimal app UI can manually store and search.

Acceptance:
- `MemoriaStoreTests.testStoreThenRecallReturnsStoredMemory` passes.
- Manual app run can save text and find it by search.

### Phase 1: App Shell

Goal:
- Replace the temporary single Form with a tabbed shell.
- Add empty feature roots for Inbox, Memoria, Shared Line, and Settings.
- Keep Memoria UI functional inside its feature directory.

Acceptance:
- App opens to stable tabs.
- Memoria store/search still works.

### Phase 2: Importer And Internal Inbox

Goal:
- Add `RawCapture`.
- Add Inbox table and store.
- Add manual and clipboard import paths.
- Internal inbox rows track duplicate/status state.
- Track `contentHash`, `sourceApp`, and `sourceThreadId` so later matching can detect duplicate or continued external conversations.

Acceptance:
- Paste or type content into Importer.
- Importer automatically organizes and commits the capture.
- A DeepSeek share URL such as `https://chat.deepseek.com/share/suy08uspxl9wzja7uc` decodes into ordered conversation turns and a `RawCapture`.

### Phase 3: Review And Commit

Goal:
- Convert a pending Inbox item into an `ImportSession`.
- Segment large captures into `CaptureSegment` rows.
- Run `ReflectionService` per segment.
- Reconcile segment drafts into a session-level `DigestResult`.
- Commit digest candidates as provisional Memoria / Shared Line updates.

Acceptance:
- A large capture can be segmented and resumed.
- Every candidate memory or Shared Line update has session and segment provenance.
- User correction is post-commit: delete, edit, reject, or roll back digest output.

### Phase 3.5: Source Matching

Goal:
- Match a new capture to an existing external import thread when `sourceApp`, `sourceThreadId`, or content similarity indicates continuation.
- Produce merge suggestions only. Do not overwrite Memoria or Shared Line automatically.

Acceptance:
- Exact duplicate captures are detected through `contentHash`.
- Same external conversation can be grouped without becoming a Shared Line automatically.

### LLM Reflection Boundary

LLM reflection is required for real large-conversation digestion, but it is not allowed inside Importer, Memoria, or Continuity.

The interface is:

```swift
protocol ReflectionService {
    func reflect(segment: CaptureSegment) async throws -> SegmentReflectionDraft
    func reconcile(session: ImportSession, drafts: [SegmentReflectionDraft]) async throws -> DigestResult
}
```

Implementations:
- `RuleBasedReflectionService`: local placeholder for tests and offline mode. It does not create durable facts automatically.
- `OpenAICompatibleReflectionService`: remote LLM mode for OpenAI-compatible `/chat/completions` providers. Uses the API key stored through the app's Keychain settings. Keys must never be committed.

Large conversations must be processed as:

```text
RawCapture
  -> ImportSession
  -> CaptureSegment[]
  -> SegmentReflectionDraft[]
  -> DigestResult
  -> provisional commit
  -> user correction
```

### Phase 4: Share Extension

Goal:
- Add Share Extension target.
- Add App Group storage.
- Shared text from another app lands in Inbox.

Acceptance:
- Share text from Safari or ChatGPT into ClaraCore.
- Capture appears in Inbox on next app open.

### Phase 5: Continuity / Shared Line

Goal:
- Add local continuity schema.
- Add active thread list and detail.
- Let Review create or update a Shared Line entry.

Acceptance:
- User can create/update a thread with last position and next step.
- Shared Line survives app restart.

### Phase 6: Gateway / Automation

Goal:
- Add foreground-only automation surface.
- Prefer App Intents / Shortcuts first; local HTTP only if needed.

Acceptance:
- Shortcut can store or recall a memory through app-owned stores.

## Explicitly Deferred

- InnerLife daemon.
- Background agent runtime.
- MCP server.
- Vector search.
- iCloud sync.
- Desktop/mobile merge.
- Multi-provider remote LLM configuration UI.
- Fully automatic background import/merge.

These are not allowed to block v1.
