# ClaraCore Mobile Agent Rules

## Boundary

This directory is the authoritative repo for ClaraCore Mobile. Do not route mobile implementation, review, commit, or push work through the broader ClaraCore root.

Before changing files, inspect:

- `git status --short`
- `docs/ARCHITECTURE_AND_SEQUENCE.md`
- `docs/MOBILE_FIX_PLAN_2026-06-30.md` when staged repair work is involved
- `docs/MANUAL_E2E_CHECKLIST.md` when phone delivery or release readiness is involved

## Product Shape

Keep the v1 model simple:

- `Context Card`: role/profile context
- `Shared Line` / `共同线`: rich continuity for copy-to-external-AI flows
- `Memory`: lighter factual or useful recall, not full Memoria

The app is a capture, organization, and copy surface for external AI workflows. Do not turn it into a full agent runtime unless the user explicitly changes that direction.

## Implementation Pattern

Prefer one phone-usable loop at a time: configure model, import conversation or text, organize and commit, inspect role-scoped Memory and Shared Line, then copy a natural continuation brief.

For importer or model-output failures, treat live sample parse errors as code-fix work with regression tests. `OpenAICompatibleReflectionService` and importer stores are common hardening points.

Keep Memory and Shared Line scoped to the active Context Card so role spaces do not mix.

## Validation

Use real validation, scaled to the change:

- `plutil -lint` for plist changes
- XcodeBuildMCP simulator build/test after checking session defaults, or equivalent `xcodebuild test -scheme ClaraCoreMobile -destination 'platform=iOS Simulator,name=iPhone 17'`
- Device build/install when the user asks for phone delivery or install

If the user says they already completed real device testing, treat that as authoritative and move to the next release or product question.
