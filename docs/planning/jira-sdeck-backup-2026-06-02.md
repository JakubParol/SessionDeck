# SDECK Jira Backup — 2026-06-02

Generated: 2026-06-02 15:28:52 CEST (+0200)
Source Jira Space/project: `SDECK` — SessionDeck
Board observed: `SDECK board` (`id=67`, type `simple`)

## Why this backup exists

Kuba decided the desired Jira hierarchy is option C:

```text
Epic / larger product area
  -> Feature / capability
      -> User Story / delivery unit
```

The current SDECK Space was created as a simple Kanban-style project. Live Jira inspection showed that the board/backlog currently treats `Feature` as the standard backlog item (`hierarchyLevel=0`), while `Epic` is above it (`hierarchyLevel=1`). A real `Story` could not be created as a child of `Feature` in this configuration; Jira returned `Please select valid parent issue.` Therefore `SDECK-18` was created as a `Subtask` under `SDECK-5`, even though its content is written as a user story.

This file backs up the current epics, features, and first US-like item before deleting/recreating the Space or changing configuration.

## Current issue hierarchy

```text
SDECK-1 Epic: Native macOS App Foundation
  SDECK-5 Feature: Native macOS scaffold and quality gate
    SDECK-18 Subtask/US: Open, build, test, and launch the native macOS scaffold
  SDECK-6 Feature: Clean Architecture boundaries and composition root
  SDECK-7 Feature: Synthetic fixture test harness

SDECK-2 Epic: Local Session Catalog and Navigation
  SDECK-8 Feature: Read-only local source discovery
  SDECK-9 Feature: Lightweight session catalog index
  SDECK-10 Feature: Project, chat, source, and fallback navigation
  SDECK-11 Feature: Catalog search and filtering

SDECK-3 Epic: Readable Transcript Viewer
  SDECK-12 Feature: Transcript decoder and segment read model
  SDECK-13 Feature: Readable selected-session transcript UI
  SDECK-14 Feature: Tool output collapsing and large transcript handling

SDECK-4 Epic: Live Session Monitoring and Diagnostics
  SDECK-15 Feature: File watcher plus reconciliation pipeline
  SDECK-16 Feature: Live append refresh for selected sessions
  SDECK-17 Feature: Diagnostics and source health UI
```

All backed-up Jira items were observed in status `To Do` at backup time.

---

# Epics

## SDECK-1 — Native macOS App Foundation

Type: Epic
Status: To Do
Labels: foundation, local-first, mvp

### Description

Problem statement

SessionDeck needs a maintainable native macOS foundation before product slices can be delivered safely. Without explicit architecture, quality gates, fixture strategy, and app shell boundaries, parser and UI work will become tightly coupled to unstable local Codex internals.

Target user / workflow

Kuba runs SessionDeck locally on macOS to inspect AI-agent sessions. Developers/agents need a clean, testable app structure that can evolve without regressions.

Outcome

A native, local-first, privacy-preserving macOS app foundation with documented build/test commands, clear Clean Architecture boundaries, and no transcript upload or remote sync.

Non-goals

No transcript parsing beyond minimal fixture-driven smoke paths. No Jira/GitHub automation. No command execution or session mutation.

Scope boundaries

In scope: app scaffold, architecture folders/modules, dependency injection/composition root, local app state location, fixture test harness, documented quality gates.

Out of scope: full session catalog, full transcript rendering, live monitoring.

Key features

- Native app scaffold and quality gate
- Clean Architecture module boundaries
- Fixture-based test harness

Architectural implications

Presentation, Application, Domain, and Infrastructure boundaries must be explicit from the first code slice. Domain/Application must be testable without real `~/.codex` or `~/.hermes` data.

Risks / open questions

- Final packaging approach: Swift Package, Xcode project, or both.
- macOS sandbox/permissions strategy for reading local session folders.

Epic acceptance criteria

- A new developer can build and test the app from documented commands.
- Production code has explicit layer boundaries and no direct transcript IO from UI code.
- Tests can run against synthetic fixtures without accessing Kuba’s real HOME.
- The app stores its own state outside Codex/Hermes stores.
- No network calls or transcript uploads exist in the foundation.

Suggested delivery order

Deliver first.

## SDECK-2 — Local Session Catalog and Navigation

Type: Epic
Status: To Do
Labels: catalog, local-first, mvp, navigation

### Description

Problem statement

Codex CLI/App sessions exist locally but are hard to browse reliably, especially CLI-resumed, non-project, older, or profile-originated sessions. SessionDeck needs a trustworthy catalog and navigation model before transcript viewing can be useful.

Target user / workflow

Kuba opens SessionDeck and immediately sees local Codex work grouped by Projects, Chats, Non-project Chats, sources/profiles, and recent activity.

Outcome

A read-only local session catalog that discovers supported local sources, extracts lightweight metadata, groups sessions safely, and exposes a stable navigation model.

Non-goals

No transcript editing, deleting, archiving, remote sync, or command execution. No deep analytics.

Scope boundaries

In scope: read-only source discovery, lightweight catalog, project/chat grouping, fallback groups, search/filter metadata.

Out of scope: full transcript rendering, live tail UI, resume/open actions.

Key features

- Read-only Codex source discovery
- Lightweight session catalog index
- Project/chat/source navigation model
- Search and filter over catalog metadata

Architectural implications

Infrastructure adapters read local Codex/Hermes stores. Application owns catalog/indexing use cases. Domain owns grouping/fallback rules. Presentation only renders navigation view models.

Risks / open questions

- Codex JSONL and SQLite metadata may change.
- Project grouping can be ambiguous for worktrees, scratch directories, and missing cwd.
- Hermes/Naomi profile paths may need explicit configuration.

Epic acceptance criteria

- Sessions are visible even when metadata is incomplete.
- CLI sessions and non-project chats have safe fallback groups.
- Catalog indexing does not require full transcript rendering.
- Real source paths are read-only.
- Tests use fixtures/temp directories, not real `~/.codex` or `~/.hermes`.

Suggested delivery order

Deliver after app foundation.

## SDECK-3 — Readable Transcript Viewer

Type: Epic
Status: To Do
Labels: local-first, mvp, transcript, viewer

### Description

Problem statement

Raw rollout JSONL files are difficult to read and large tool outputs can make editors unusable. SessionDeck needs a readable transcript view that presents useful conversation history without overwhelming the user or UI.

Target user / workflow

Kuba selects a session from the catalog and reads user prompts, assistant replies, tool calls, tool outputs, errors, and timestamps in a clean right-side viewer.

Outcome

A resilient transcript read model and viewer that renders selected sessions clearly, collapses noisy details by default, and handles unknown/malformed events gracefully.

Non-goals

No transcript editing. No sending prompts. No command execution. No full-text cloud indexing.

Scope boundaries

In scope: fixture-driven transcript decoding, segment model, readable rendering, collapsed tool output, large-output handling, parse diagnostics.

Out of scope: live append handling and source discovery beyond selected session handoff.

Key features

- Transcript event decoder and read model
- Readable session detail rendering
- Tool call/output collapsing
- Large transcript and malformed event resilience

Architectural implications

Infrastructure decodes concrete transcript formats. Application builds a transcript read model. Domain defines stable transcript segment concepts. Presentation renders display sections and expansion state.

Risks / open questions

- Codex event schema may be unstable.
- Markdown rendering could become too heavy for large sessions.
- Tool outputs may contain sensitive data and must remain local.

Epic acceptance criteria

- User and assistant turns are readable for fixture sessions.
- Tool outputs are collapsed by default and expandable on demand.
- Unknown/malformed events are visible as diagnostics, not silently dropped.
- Large outputs do not freeze the UI.
- No transcript content leaves the machine.

Suggested delivery order

Deliver after catalog can select a session.

## SDECK-4 — Live Session Monitoring and Diagnostics

Type: Epic
Status: To Do
Labels: diagnostics, live-monitoring, local-first, mvp

### Description

Problem statement

Kuba wants to see Codex session activity appended through CLI/App flows without quitting and reopening Codex App. SessionDeck needs live monitoring with diagnostics so missed watcher events, parse failures, and permission problems are visible.

Target user / workflow

Kuba keeps SessionDeck open while James/Hermes/Codex sessions run. Active sessions update automatically, and problems are shown clearly rather than failing silently.

Outcome

A live-refresh pipeline for active local sessions using file-system watching plus reconciliation, with user-visible diagnostics for parser, path, permission, and drift issues.

Non-goals

No autonomous command execution. No resume/send prompt button in MVP. No remote notifications. No rewriting source session files.

Scope boundaries

In scope: active-session append detection, debounced refresh, reconciliation, diagnostics surface, permission/path problem reporting.

Out of scope: remote sync, mobile companion, command dispatch.

Key features

- File watcher plus reconciliation loop
- Live transcript append refresh
- Diagnostics view and health state
- Source/profile configuration diagnostics

Architectural implications

Infrastructure owns concrete watchers and file reads. Application owns refresh orchestration and health state. Presentation renders live state and diagnostics.

Risks / open questions

- macOS file watchers can miss events during bursts.
- Codex may write files in patterns that require debounce/retry.
- Permission-denied paths need clear recovery UX.

Epic acceptance criteria

- App updates selected active sessions after local transcript append.
- Watcher misses are corrected by periodic reconciliation.
- Permission/path/parse failures are visible in diagnostics.
- Live refresh does not block the main UI.
- Source session files remain read-only.

Suggested delivery order

Deliver after catalog and selected-session viewer exist.

---

# Features

## SDECK-5 — Native macOS scaffold and quality gate

Type: Feature
Status: To Do
Parent: SDECK-1 — Native macOS App Foundation
Labels: foundation, mvp, quality-gate

### Description

User value

Developers and agents can open, build, and test SessionDeck consistently before feature work starts.

Inputs and outputs

Inputs: empty/bootstrap repository, SessionDeck standards.

Outputs: native macOS app scaffold, documented build/test commands, initial test target, and no production network/transcript upload code.

In-scope behavior

- Create the native macOS app/project scaffold.
- Document exact build and test commands in README or scripts.
- Add a minimal smoke test that proves the test target runs.
- Keep app runtime local-first and read-only by default.

Out-of-scope behavior

- No session catalog implementation.
- No transcript parser beyond minimal fixture smoke if needed.
- No command execution or Codex session mutation.

Acceptance criteria

- Fresh checkout can run the documented build command successfully.
- Fresh checkout can run the documented test command successfully.
- The app launches to a placeholder/shell screen without reading real `~/.codex` or `~/.hermes`.
- No network calls or telemetry code are present.
- The quality gate is documented and suitable for future CI.

Data/source assumptions

No real local session stores are required for this feature.

Dependency boundaries

Presentation may render placeholder UI. Domain/Application/Infrastructure folders or modules may be present but should not be bypassed by future work.

Verification approach

Run documented build/test commands on a clean working tree.

Failure/edge cases

If Xcode/SPM tooling choice blocks a reproducible gate, stop and document the blocker before adding product code.

## SDECK-6 — Clean Architecture boundaries and composition root

Type: Feature
Status: To Do
Parent: SDECK-1 — Native macOS App Foundation
Labels: architecture, foundation, mvp

### Description

User value

Future SessionDeck features can be implemented without coupling UI code directly to Codex files, SQLite, or file watchers.

Inputs and outputs

Inputs: SessionDeck standards and app scaffold.

Outputs: explicit Presentation, Application, Domain, and Infrastructure boundaries with a composition root.

In-scope behavior

- Define initial module/folder structure for the four layers.
- Add minimal protocols/ports for source discovery, catalog access, transcript loading, and clock/file-system abstractions where needed.
- Ensure Presentation depends on Application DTO/view models rather than concrete Infrastructure.
- Document dependency direction in code comments or architecture notes if the project structure needs explanation.

Out-of-scope behavior

- No full parser implementation.
- No real source scanning beyond fakes/minimal stubs.
- No broad framework abstractions not needed by MVP.

Acceptance criteria

- Domain has no imports from Presentation or Infrastructure.
- Application owns ports used by Infrastructure adapters.
- UI code cannot directly read rollout JSONL files.
- Composition root is the only place wiring concrete adapters into use cases.
- Tests can instantiate Application use cases with fakes.

Data/source assumptions

This feature may use synthetic in-memory sources only.

Dependency boundaries

Strict Clean Architecture direction: Presentation -> Application -> Domain; Infrastructure -> Application/Domain.

Verification approach

Run build/test gate and inspect imports/module dependencies for boundary violations.

Failure/edge cases

If Swift/Xcode module layout cannot enforce boundaries cleanly, document the chosen compromise before implementation continues.

## SDECK-7 — Synthetic fixture test harness

Type: Feature
Status: To Do
Parent: SDECK-1 — Native macOS App Foundation
Labels: fixtures, foundation, mvp, testing

### Description

User value

SessionDeck behavior can be verified safely without exposing or depending on Kuba’s private real session history.

Inputs and outputs

Inputs: synthetic Codex-like transcript samples and temporary directories.

Outputs: fixture strategy, fixture files, and test helpers for catalog/parser/live-refresh tests.

In-scope behavior

- Add minimal redacted/synthetic fixture transcripts.
- Add helpers to create temp Codex-like session directories.
- Include fixtures for happy path, malformed line, missing metadata, non-project chat, and large output.
- Ensure tests never access real `~/.codex` or `~/.hermes`.

Out-of-scope behavior

- No committing real transcript content.
- No exhaustive coverage of every Codex event type in the first slice.
- No benchmarking suite unless needed later.

Acceptance criteria

- Tests fail if they accidentally target real user HOME paths.
- Fixture transcripts contain no private data.
- At least one malformed/unknown event fixture exists.
- At least one large-output fixture or generated fixture path exists.
- Application tests can use fakes; Infrastructure tests use temp directories.

Data/source assumptions

Codex-like JSONL shape is synthetic and intentionally minimal.

Dependency boundaries

Fixture helpers live in test/support areas and do not leak into production runtime.

Verification approach

Run test gate and review fixture contents for privacy.

Failure/edge cases

If real examples are needed for schema discovery, derive redacted minimal fixtures and do not commit raw source logs.

## SDECK-8 — Read-only local source discovery

Type: Feature
Status: To Do
Parent: SDECK-2 — Local Session Catalog and Navigation
Labels: catalog, mvp, read-only, source-discovery

### Description

User value

Kuba can point SessionDeck at known local agent stores and see which sources are available without the app modifying them.

Inputs and outputs

Inputs: configured/default source roots such as `~/.codex/sessions` and optional profile roots.

Outputs: source availability list with path, source type, permission status, and read-only capability.

In-scope behavior

- Discover default Codex session root under the active user HOME.
- Represent optional additional source/profile roots without hardcoding Naomi-only behavior.
- Detect missing paths and permission-denied paths.
- Expose source health to Application/Presentation.

Out-of-scope behavior

- No writing to source roots.
- No transcript parsing beyond detecting candidate files.
- No automatic scanning of arbitrary user directories.

Acceptance criteria

- Existing source roots are reported as available.
- Missing source roots are reported without crashing.
- Permission failures are visible as source diagnostics.
- Source discovery is read-only.
- Tests use temp directories, not real `~/.codex`.

Data/source assumptions

Initial MVP supports Codex rollout JSONL roots first; Hermes/profile roots are configurable extension points.

Dependency boundaries

Infrastructure owns concrete file-system checks; Application exposes source health DTOs.

Verification approach

Fixture tests for available/missing/permission-like paths plus build/test gate.

Failure/edge cases

Missing cwd, empty sessions directory, and inaccessible folder must not block the whole catalog.

## SDECK-9 — Lightweight session catalog index

Type: Feature
Status: To Do
Parent: SDECK-2 — Local Session Catalog and Navigation
Labels: catalog, indexing, mvp

### Description

User value

SessionDeck can show many sessions quickly without fully loading every transcript at launch.

Inputs and outputs

Inputs: candidate session files and lightweight metadata sources.

Outputs: catalog entries with id, source, path, title/preview, project path if known, timestamps, size, and parse/index status.

In-scope behavior

- Create a lightweight catalog entry model.
- Extract bounded metadata from candidate rollout files and available metadata stores where safe.
- Avoid full transcript rendering during catalog build.
- Mark parse/index failures per session instead of failing the entire catalog.

Out-of-scope behavior

- No full-text transcript search in MVP.
- No persistent index optimization until needed by measured performance.
- No mutation of source stores.

Acceptance criteria

- Catalog can list fixture sessions with lightweight metadata.
- Large transcript fixture does not require full render/load to appear in the catalog.
- Failed/malformed sessions remain visible with diagnostic status.
- Catalog entries include enough data for navigation grouping.
- Tests prove catalog build uses temp fixtures only.

Data/source assumptions

Rollout JSONL file path and bounded first/last event reads may be enough for MVP metadata; SQLite metadata can be added behind a port if needed.

Dependency boundaries

Application owns catalog build use case; Infrastructure owns concrete file reads and optional metadata adapters.

Verification approach

Unit tests for models/grouping plus infrastructure fixture tests for metadata extraction.

Failure/edge cases

Empty files, malformed first line, missing timestamps, duplicate ids, and huge files must be handled gracefully.

## SDECK-10 — Project, chat, source, and fallback navigation

Type: Feature
Status: To Do
Parent: SDECK-2 — Local Session Catalog and Navigation
Labels: catalog, grouping, mvp, navigation

### Description

User value

Kuba can navigate sessions the way he thinks about the work: Projects, Chats, Non-project Chats, sources/profiles, and recency.

Inputs and outputs

Inputs: lightweight catalog entries with optional cwd/project/source metadata.

Outputs: navigation tree/view model with safe fallback groups.

In-scope behavior

- Group sessions by project when cwd/project metadata is available.
- Place missing-cwd sessions under Non-project Chats or Unknown Project fallback.
- Represent source/profile labels without hardcoding named agents.
- Sort by last activity where available.

Out-of-scope behavior

- No manual reclassification UI in MVP.
- No mutation of source metadata.
- No assumptions that every session belongs to a project.

Acceptance criteria

- Project sessions appear under project groups.
- Non-project chats appear under a dedicated fallback group.
- Missing or ambiguous metadata does not hide a session.
- Source/profile filters can be represented in the navigation model.
- Unit tests cover worktree/scratch/missing-cwd cases.

Data/source assumptions

Project path may be unavailable or ambiguous; fallback grouping is required.

Dependency boundaries

Domain owns grouping rules; Presentation only renders grouped view models.

Verification approach

Unit tests for grouping matrix plus catalog fixture smoke.

Failure/edge cases

Duplicate project names, worktrees, archived/missing source files, and unknown source kind must remain visible.

## SDECK-11 — Catalog search and filtering

Type: Feature
Status: To Do
Parent: SDECK-2 — Local Session Catalog and Navigation
Labels: catalog, filtering, mvp, search

### Description

User value

Kuba can quickly narrow a growing local session catalog without relying on Codex App’s incomplete recent-list behavior.

Inputs and outputs

Inputs: catalog entries and user query/filter state.

Outputs: filtered/sorted catalog list and selected navigation state.

In-scope behavior

- Search by title/preview/path/source/profile metadata.
- Filter by project, source/profile, non-project, and parse status.
- Sort by last activity with stable fallback ordering.
- Keep filters local and deterministic.

Out-of-scope behavior

- No full transcript content search in MVP.
- No cloud index or sync.
- No saved search management unless later approved.

Acceptance criteria

- Search works over catalog metadata for fixture entries.
- Filters can combine without losing sessions unexpectedly.
- Empty-result state distinguishes “no matching sessions” from source/index failure.
- Sorting is deterministic when timestamps are missing.
- Tests cover query, filter, and sort combinations.

Data/source assumptions

Catalog metadata is available without fully reading transcripts.

Dependency boundaries

Application/ViewModel owns filter orchestration; Domain owns pure filter/sort policies where useful.

Verification approach

Unit tests for filter/sort logic and UI state smoke tests if app shell exists.

Failure/edge cases

Missing title, duplicate paths, unknown source, and missing timestamps must not crash filtering.

## SDECK-12 — Transcript decoder and segment read model

Type: Feature
Status: To Do
Parent: SDECK-3 — Readable Transcript Viewer
Labels: decoder, mvp, read-model, transcript

### Description

User value

SessionDeck can convert Codex-like transcript files into stable internal segments that the UI can render safely.

Inputs and outputs

Inputs: selected session transcript path or byte stream from Infrastructure.

Outputs: transcript read model containing ordered segments, metadata, and diagnostics.

In-scope behavior

- Decode supported Codex JSONL event shapes from fixtures.
- Map user turns, assistant turns, tool calls, tool outputs, errors, and unknown events into stable segments.
- Preserve timestamps and source/event metadata where available.
- Report line-level parse diagnostics without aborting the whole transcript.

Out-of-scope behavior

- No full schema reverse engineering.
- No editing or rewriting transcript files.
- No sending prompts or resume actions.

Acceptance criteria

- Fixture user/assistant turns become readable segments.
- Tool calls and outputs are represented distinctly.
- Malformed lines produce diagnostics and do not drop the rest of the file.
- Unknown events are preserved as diagnostic segments.
- Decoder tests do not access real `~/.codex`.

Data/source assumptions

Codex event formats are unstable; decoder must be tolerant and version-aware where possible.

Dependency boundaries

Infrastructure owns concrete JSONL decoding; Domain/Application own stable segment concepts/read model.

Verification approach

Fixture-based decoder tests for happy path, unknown event, malformed line, missing metadata, and large output marker.

Failure/edge cases

Truncated writes, invalid JSON, missing roles, and very long output fields must degrade gracefully.

## SDECK-13 — Readable selected-session transcript UI

Type: Feature
Status: To Do
Parent: SDECK-3 — Readable Transcript Viewer
Labels: mvp, transcript, ui, viewer

### Description

User value

Kuba can select a catalog session and read the conversation in a clean right-side view instead of opening raw JSONL.

Inputs and outputs

Inputs: transcript read model for the selected session.

Outputs: rendered transcript detail with role labels, timestamps, metadata, and readable content blocks.

In-scope behavior

- Render user and assistant turns as first-class content.
- Render session metadata: title/source/project/path/timestamps when available.
- Show parse diagnostics inline or in a clearly reachable diagnostics section.
- Maintain readable macOS UI layout matching the Projects/Chats sidebar concept.

Out-of-scope behavior

- No reply/send prompt box.
- No transcript editing.
- No complex markdown plugin system in MVP.

Acceptance criteria

- Selecting a fixture session shows its transcript detail.
- User and assistant messages are visually distinguishable.
- Missing metadata has clear fallback labels.
- Parse diagnostics are visible but do not dominate normal reading.
- UI does not perform direct file IO.

Data/source assumptions

The selected transcript read model is supplied by Application, not decoded in the view.

Dependency boundaries

Presentation renders view models only; Application loads selected transcript.

Verification approach

View model tests plus app smoke/manual verification on fixture data.

Failure/edge cases

Empty transcript, missing title, all-diagnostic transcript, and very long message content must be handled safely.

## SDECK-14 — Tool output collapsing and large transcript handling

Type: Feature
Status: To Do
Parent: SDECK-3 — Readable Transcript Viewer
Labels: large-files, mvp, tool-output, transcript

### Description

User value

Kuba can inspect useful tool details without huge outputs overwhelming the transcript viewer or freezing the app.

Inputs and outputs

Inputs: transcript segments containing tool calls, tool outputs, errors, and long content.

Outputs: collapsed/expanded display model with safe truncation and explicit show-more behavior.

In-scope behavior

- Collapse tool calls and outputs by default.
- Show concise labels for command/tool name, status, and output size when known.
- Provide explicit expansion for bounded output detail.
- Handle very large output segments without loading/rendering everything at once.

Out-of-scope behavior

- No exporting tool outputs.
- No copying secrets detection in MVP unless later approved.
- No remote rendering service.

Acceptance criteria

- Tool output is collapsed by default in fixture transcript UI.
- User can expand a bounded output segment.
- Large output fixture does not freeze the viewer.
- Truncation is explicit and does not pretend content is complete.
- Sensitive content remains local and is never uploaded.

Data/source assumptions

Tool output size may be known only after bounded read or segment construction.

Dependency boundaries

Application/ViewModel computes display-safe expansion state; Presentation renders it.

Verification approach

Unit/view-model tests for collapsed/expanded/truncated states plus large-output fixture smoke.

Failure/edge cases

Huge single-line output, binary-looking output, repeated tool output bursts, and malformed tool event ordering must remain readable enough for diagnostics.

## SDECK-15 — File watcher plus reconciliation pipeline

Type: Feature
Status: To Do
Parent: SDECK-4 — Live Session Monitoring and Diagnostics
Labels: live-monitoring, mvp, reconciliation, watcher

### Description

User value

SessionDeck notices active local session changes quickly while still recovering if file-system events are missed.

Inputs and outputs

Inputs: configured source roots and catalog entries with file paths/timestamps.

Outputs: refresh events, changed session notifications, and source health state.

In-scope behavior

- Watch configured source roots or active session files for changes.
- Debounce bursts from active transcript writes.
- Add periodic reconciliation to detect missed watcher events.
- Expose refresh state to Application/Presentation.

Out-of-scope behavior

- No command execution.
- No resume/send prompt actions.
- No remote notifications or sync.

Acceptance criteria

- App detects append/change in a temp fixture source.
- Reconciliation catches a change when watcher event is not emitted in the test path.
- Debounce prevents excessive refresh loops on burst writes.
- Watcher/reconciliation runs off the main UI path.
- Source files remain read-only.

Data/source assumptions

macOS watchers can miss events; reconciliation is mandatory.

Dependency boundaries

Infrastructure owns concrete watcher implementation; Application owns refresh orchestration and state.

Verification approach

Application tests with fake watcher plus infrastructure smoke test using temp directory append.

Failure/edge cases

Deleted file, rotated/replaced file, inaccessible source, and burst writes must not crash the app.

## SDECK-16 — Live append refresh for selected sessions

Type: Feature
Status: To Do
Parent: SDECK-4 — Live Session Monitoring and Diagnostics
Labels: live-monitoring, mvp, refresh, transcript

### Description

User value

Kuba can keep a selected active session open and see new turns appear without restarting or reopening Codex App.

Inputs and outputs

Inputs: selected session, refresh events, updated transcript bytes/segments.

Outputs: updated transcript read model and UI state preserving scroll/selection where practical.

In-scope behavior

- Refresh selected active transcript after append/change events.
- Parse only the needed changed data where practical, or safely reload bounded read model for MVP.
- Preserve existing rendered content and expansion state where practical.
- Show a visible updating/error state when refresh fails.

Out-of-scope behavior

- No sending prompts from SessionDeck.
- No writing to the active transcript.
- No real-time streaming protocol beyond local file updates.

Acceptance criteria

- App updates a selected fixture transcript after append.
- Refresh does not block the main UI.
- Existing view state is not unnecessarily reset on every append.
- Parse failure after append is shown as a diagnostic while prior readable content remains available.
- Tests simulate append using temp fixture files.

Data/source assumptions

Active files may be appended while incomplete; parser must tolerate truncated writes/retry.

Dependency boundaries

Application coordinates refresh; Infrastructure reads changed data; Presentation renders updated view model.

Verification approach

Fake watcher/application test plus temp-file append integration smoke.

Failure/edge cases

Partial JSON line, rapid consecutive appends, selected file deletion, and stale catalog metadata must degrade gracefully.

## SDECK-17 — Diagnostics and source health UI

Type: Feature
Status: To Do
Parent: SDECK-4 — Live Session Monitoring and Diagnostics
Labels: diagnostics, mvp, source-health, ux

### Description

User value

When SessionDeck cannot read, parse, watch, or refresh something, Kuba sees the reason and recovery path instead of silent drift.

Inputs and outputs

Inputs: source discovery health, parser diagnostics, watcher status, refresh failures, permission/path failures.

Outputs: diagnostics UI/read model with severity, affected source/session, message, and suggested recovery.

In-scope behavior

- Show source health: available, missing, permission denied, empty, stale, parse warnings.
- Show session-level parse diagnostics.
- Show watcher/reconciliation health.
- Keep diagnostics local and non-noisy.

Out-of-scope behavior

- No automatic permission repair.
- No telemetry upload.
- No automated issue creation from diagnostics.

Acceptance criteria

- Missing source path appears in diagnostics.
- Malformed transcript fixture appears as session-level diagnostic.
- Watcher failure/reconciliation fallback is visible.
- Diagnostics distinguish warning vs blocking error.
- Normal sessions remain usable when another source/session has diagnostics.

Data/source assumptions

Diagnostics may come from multiple layers and must be normalized for UI display.

Dependency boundaries

Application owns diagnostic aggregation; Infrastructure emits typed source/parser/watcher failures; Presentation renders diagnostics only.

Verification approach

Unit tests for diagnostic aggregation plus fixture/temp-path smoke for missing and malformed cases.

Failure/edge cases

Many repeated errors must be deduplicated/debounced enough to stay readable; diagnostics must not leak transcript content unnecessarily.

---

# User-story-like item currently present

## SDECK-18 — US: Open, build, test, and launch the native macOS scaffold

Type: Subtask
Status: To Do
Parent: SDECK-5 — Native macOS scaffold and quality gate
Labels: foundation, mvp, quality-gate, user-story

### Description

User story

As a developer or implementation agent, I want a native macOS app scaffold with documented build/test commands and a placeholder launch screen, so that future SessionDeck work starts from a reproducible quality gate.

Parent feature

SDECK-5 — Native macOS scaffold and quality gate

Scope

- Create the native macOS app/project scaffold.
- Add a placeholder/shell screen only.
- Add an initial test target and at least one smoke test proving the test target runs.
- Document exact build and test commands.
- Keep runtime local-first and read-only by default.

Acceptance criteria

- Fresh checkout can run the documented build command successfully.
- Fresh checkout can run the documented test command successfully.
- The app launches to a placeholder/shell screen.
- Launch does not read real `~/.codex`, `~/.hermes`, or other local transcript stores.
- No network calls, telemetry, transcript upload, command execution, or Codex session mutation code is present.
- The quality gate is documented in repo docs/README or scripts and is suitable for future CI.

Out of scope

- Session catalog implementation.
- Transcript parser implementation.
- Live monitoring.
- Resume/send prompt commands.

Verification

Run the documented build and test commands on a clean working tree and confirm the placeholder app launches.

---

# Recreate recommendation for option C

When recreating the Jira Space, use a setup that supports this hierarchy:

```text
Epic / parent product area
  -> Feature / capability container
      -> Story / user-value delivery unit
          -> Sub-task / technical task, optional
```

Recommended operational meaning:

- Epic: larger product area or milestone-level outcome.
- Feature: capability/spec container under an Epic.
- Story/User Story: delivery unit used by Hermes/Kanban/Codex flow.
- Sub-task: optional technical decomposition inside Jira; otherwise keep technical tasks in Hermes Kanban.

If Jira cannot make `Story` a child of `Feature` in the selected Space type, do not recreate the same simple Kanban setup. Choose a company-managed/project template or hierarchy configuration that supports Feature -> Story, or use an Advanced Roadmaps/Plans-compatible hierarchy.

# Notes from live verification

- SDECK board observed as `simple`.
- `Feature` issues are currently standard backlog items.
- `Epic` issues are parent issues above Features.
- `Story` could not be created under Feature in this current setup.
- `SDECK-18` was created as `Subtask` only because current Jira hierarchy rejected `Story` as child of `Feature`.
