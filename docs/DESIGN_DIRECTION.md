# ClaraCore Mobile Visual and Interaction Direction

Status: initial product/design baseline
Date: 2026-06-29

## 0. Brand Alignment With ClaraCore Desktop

ClaraCore Mobile must extend the existing ClaraCore Desktop product identity.

The primary mark is not a new mobile-only logo. Use the Desktop ClaraCore mark as the source of truth:

- `assets/brand/claracore-mark.svg`
- `assets/brand/claracore-mark-flat.svg`
- `assets/brand/claracore-symbol-mono.svg`
- `assets/brand/claracore-wordmark.svg`

The existing mark already carries the right product meaning: an open C, a shared line, and a central memory point. Mobile should reuse that logic and adapt the surrounding UI for capture/review flows.

Mobile-specific icon or illustration work should be treated as secondary product assets, not as a replacement brand identity.

## 1. Product Positioning

ClaraCore Mobile should feel like a quiet memory companion for existing AI chat habits, not another general chat app.

The core product promise is:

- Capture useful context from mobile AI conversations with low friction.
- Turn messy chat material into reviewable memory.
- Let the user see what ClaraCore understood before it becomes durable truth.
- Bring the user back to the right thread, fact, or next action later.

This means the first mobile product surface should center on an import/share inbox, memory review, continuity, and retrieval. Gateway, agent execution, and model controls can exist later, but they should not dominate the first visual impression.

## 2. Design Keywords

- Quiet: calm, low-noise, readable, no flashy AI-dashboard theatrics.
- Trustworthy: every memory state is visible and reversible.
- Personal: the product feels close to the user's thinking history, not enterprise admin software.
- Lightly alive: enough runtime state to show digestion, review, and continuity, without noisy automation.
- Precise: small labels, clear timestamps, explicit source traces, strong empty states.

Avoid:

- Generic chatbot layout as the primary screen.
- Purple-blue AI gradient identity.
- Overly dark sci-fi command center styling.
- Decorative glassmorphism that weakens legibility.
- Heavy gamified memory metaphors.

## 3. Visual Style

### Overall Mood

Use a warm, minimal mobile utility style that stays close to ClaraCore Desktop: soft off-white backgrounds, graphite text, calm green as the primary product accent, blue for Shared Line / continuity, and amber for paused/review states.

The app should feel more like a private notebook with intelligent digestion than a model playground.

### Color System

Use the Desktop CSS variables as the canonical palette and map them into mobile tokens.

Base colors:

- `bg`: `#f7f7f4` for main app background.
- `sidebar`: `#fbfbf8` for top-level shell surfaces and grouped backgrounds.
- `surface`: `#ffffff` for sheets, cards, input panels.
- `surfaceSoft`: `#f4f4f0` for grouped sections and disabled surfaces.
- `surfaceWarm`: `#fbf8f1` for warm review/empty surfaces.
- `text`: `#202421` for primary text.
- `muted`: `#656d68` for secondary text.
- `faint`: `#8c928c` for tertiary metadata.
- `border`: `#d9dad2` for separators.
- `borderStrong`: `#c4c7bd` for stronger dividers.

Functional accents:

- `green`: `#28745a` for accepted memory, primary actions, and the ClaraCore core point.
- `greenBg`: `#e3f0e8` for positive/ready backgrounds.
- `blue`: `#365f84` for Shared Line / continuity.
- `blueBg`: `#e3ebf2` for continuity backgrounds.
- `amber`: `#91651f` for paused, optional, needs-review, or deferred states.
- `amberBg`: `#efe6d5` for review backgrounds.
- `red`: `#a64036` for destructive or rejected items.
- `redBg`: `#f3e3df` for destructive backgrounds.

Usage rules:

- Most screens should be neutral and text-led.
- Use accent colors as small signals: icon fill, status dot, thin left rail, segmented-control active state.
- Do not flood entire cards with accent color.
- Do not introduce a second dominant green/teal or blue system that competes with Desktop.

### Typography

Use the system font stack on mobile.

Hierarchy:

- Screen title: 24-28 pt, semibold.
- Section label: 13-15 pt, medium, muted.
- Primary body: 16-17 pt, regular.
- Memory snippet text: 15-16 pt, regular, comfortable line-height.
- Metadata: 12-13 pt, muted.

Writing style:

- Use short, concrete labels.
- Prefer state labels over marketing copy: `待确认`, `已入记忆`, `可恢复`, `来自 Claude 导出`.
- Avoid long instructions inside the app. Let the interface reveal the workflow.

### Shape and Layout

- Cards: 8 px radius maximum.
- Buttons: 8 px radius maximum.
- Sheets: large top radius is acceptable for native mobile bottom sheets.
- Separators: subtle hairlines over heavy borders.
- Spacing: dense but breathable; prioritize scan speed.

The visual rhythm should be closer to iOS Notes, Things, or a clean email triage app than a landing page.

## 4. App Structure

Recommended first-version navigation:

1. Inbox
2. Memory
3. Continuity
4. Search
5. Settings

Use a native bottom tab bar on mobile. Keep tab labels short and stable.

### Inbox

Purpose: the first landing surface for shared snippets, imported chat exports, pasted transcripts, screenshots/OCR later, and files.

Core components:

- Source chips: `Claude`, `DeepSeek`, `ChatGPT`, `手动粘贴`, `文件导入`.
- Import queue cards with source, time, preview, and digestion state.
- Review summary card: facts found, possible preferences, unresolved context, suggested continuity notes.
- Swipe actions: accept, defer, reject.
- Batch review mode for imported long chats.

Key states:

- `待解析`: captured but not processed.
- `解析中`: lightweight progress, no theatrical loading.
- `待确认`: ClaraCore has extracted candidates.
- `已整理`: reviewed and routed.
- `已忽略`: explicitly discarded.

### Memory

Purpose: durable facts and stable user/project knowledge.

Core components:

- Memory list grouped by project/person/topic.
- Fact cards with source trace and confidence/review status.
- Edit/retract flow.
- Conflict indicator when new import contradicts an existing fact.

Important rule:

Memoria-style facts must look different from reflection notes. A durable fact should feel audited, source-backed, and editable.

### Continuity

Purpose: show the current shared line: where the user and agents are resuming from.

Core components:

- Current position panel.
- Recent threads/projects.
- Resume packet preview.
- "Start from here" action.
- Lightweight timeline of decisions and open threads.

Visual treatment:

Use the `continuity` accent as a thin vertical rail or timeline line. Do not make it look like chat history; it is state and direction, not conversation.

### Search

Purpose: retrieve memory, continuity, imported source, and review history.

Core components:

- Universal search input.
- Filter row: `记忆`, `共同线`, `导入源`, `待确认`.
- Result cards with compact source and timestamp.
- "Use in..." action later for sending context to an external app/agent.

### Settings

Purpose: account, local storage, import sources, privacy controls, model/provider settings later.

Keep settings utilitarian. Do not mix operational model controls into the primary memory review flow.

## 5. Core Interaction Model

### Primary Flow: Share or Import

1. User finishes a useful AI chat in another app.
2. User shares/export/imports it into ClaraCore Mobile.
3. ClaraCore creates an inbox item.
4. The app extracts candidate facts, continuity notes, and reflection items.
5. User reviews a concise digest.
6. Accepted items are routed to Memory, Continuity, or Reflection.
7. Later, user searches or resumes from the organized context.

This flow must minimize repeated manual copy/paste. If paste exists, it should be an escape hatch, not the main product promise.

### Review Interaction

Each extracted candidate should support:

- Accept
- Edit
- Move target
- Defer
- Reject
- View source

Use bottom sheets for detail review. Keep list scanning fast.

### Trust Interaction

Every durable memory should show:

- Source app or file.
- Date captured.
- Whether user accepted it directly or it was inferred.
- Retraction/edit action.

Never make the app feel like it silently rewrites the user's memory store.

### Runtime State

Use small visible status, not large progress theatrics:

- `正在整理 3 条导入`
- `2 条需要确认`
- `上次同步 14:32`
- `本地优先`

## 6. Key Screens

### First Launch

Goal: establish what the app does in one useful action.

Recommended first screen:

- Top: `ClaraCore`
- Subtitle: `把有价值的 AI 对话整理成可恢复的记忆`
- Primary action: `导入对话`
- Secondary action: `打开分享说明`
- Below: empty inbox surface with one sample row shape, not marketing cards.

Avoid multi-page educational onboarding until the import flow exists.

### Inbox Item Detail

Layout:

- Header: source, import time, state.
- Digest section: concise summary.
- Candidate sections:
  - `可入记忆`
  - `可作为共同线`
  - `需要你确认`
  - `不确定的想法`
- Source preview collapsed by default.

### Memory Detail

Layout:

- Fact text.
- Tags/project.
- Source trace.
- Last updated.
- Related continuity.
- Edit/retract actions.

### Continuity Detail

Layout:

- Current position.
- What changed.
- Open questions.
- Next possible action.
- Source memory/import references.

## 7. Icon and Visual Asset System

### Icon Style

Use a consistent 24 px outline icon family:

- 1.75-2 px stroke.
- Rounded caps and joins.
- No filled cartoon icons.
- Accent only on active/semantic states.
- Use SF Symbols on iOS if building native SwiftUI; otherwise use Lucide as the cross-platform reference.

### Required App Icons

Primary product icon direction:

- Source of truth: ClaraCore Desktop mark.
- Meaning: open C, shared line, central memory point.
- Color: Desktop gradient/full mark for app icon and brand moments; flat mark for small digital use; monochrome symbol for constrained contexts.
- Avoid: new mobile-only logo, brain icons, robot heads, chat bubbles as the main brand, purple AI sparkles.

App icon variants needed:

- iOS app icon full set generated from the Desktop mark or a mobile-safe crop of it.
- Android adaptive icon foreground/background.
- Monochrome icon.
- Small favicon/web icon if there is a web share/import helper.
- Mac/desktop companion already exists and should remain the brand reference.

### Navigation Icons

- Inbox: tray/inbox icon.
- Memory: archive/card-stack/bookmark icon.
- Continuity: route/timeline/git-branch-like icon.
- Search: search icon.
- Settings: sliders or gear icon.

### Functional Icons

Import and capture:

- Share in
- File import
- Paste
- Camera/OCR later
- Link/source

Review:

- Accept/check
- Reject/x
- Edit/pencil
- Defer/clock
- Move/arrow-right
- Merge
- Conflict/warning
- Source/quote

Memory types:

- Fact
- Preference
- Project
- Person
- Decision
- Open question
- Reflection/uncertain

System state:

- Local storage
- Sync later
- Private/lock
- Processing
- Error
- Needs review

### Illustration and Empty-State Assets

Keep these sparse. The product should not become illustration-led.

Needed assets:

- Empty inbox: one quiet imported transcript turning into small organized cards.
- Empty memory: small stack of accepted cards.
- Empty continuity: a simple line with current-position marker.
- Import success: compact confirmation mark.
- Source unavailable/error: plain warning panel.

Style:

- Flat, low-saturation, few colors.
- No large mascot.
- No synthetic "AI magic" beams.

## 8. Motion and Feedback

Motion should communicate state change and preserve trust.

Use:

- Subtle slide-in for shared/imported item arrival.
- Small progress shimmer only inside the active inbox item.
- Card collapse/expand for candidate sections.
- Check/reject micro animation under 200 ms.
- Haptic feedback for accept/reject if native mobile.

Avoid:

- Long thinking animations.
- Floating particles.
- Overly playful celebrations.

## 9. Accessibility and Mobile Rules

- Minimum touch target: 44 x 44 px.
- Body text should stay at native readable size; do not shrink dense memory text below 15 pt.
- Support dynamic type where possible.
- Color must not be the only state indicator.
- Review actions must be undoable.
- Important destructive actions require confirmation or undo snackbar.

## 10. First Design Milestone

The first Figma or implementation milestone should include:

1. App icon direction: 3 variants.
2. Color and type tokens.
3. Bottom tab shell.
4. Inbox list.
5. Import detail/review sheet.
6. Memory list and memory detail.
7. Continuity current-position screen.
8. Search result screen.
9. Empty states for Inbox, Memory, Continuity.
10. Icon set v1 covering navigation, import, review, and memory types.

## 11. Design Principle Summary

ClaraCore Mobile should make memory capture feel like triage, not chatting.

The strongest visual product center is:

`external AI chat -> ClaraCore inbox -> user-reviewed memory -> continuity/search`

Everything in the UI should support that loop: fast capture, calm review, visible provenance, and reliable retrieval.
