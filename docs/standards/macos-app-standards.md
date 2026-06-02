# macOS App Standards

These standards apply to SessionDeck macOS app work. They extend [coding-standards.md](./coding-standards.md).

## Navigation

- ↑ [Standards Index](./index.md)
- ↑ [Documentation Index](../INDEX.md)

---

## Product Experience Principles

- SessionDeck should feel like a cockpit for local agent activity, not a raw log viewer.
- The default experience is readable, calm, and fast: Projects/Chats navigation on the left, transcript detail on the right.
- The app must make hidden local work visible: CLI sessions, non-project chats, project sessions, and selected profile/session sources.
- The app must be safe: read-only by default, transparent about what paths it reads, and explicit before any command execution.

---

## UI Architecture

Default native macOS direction:

```text
Presentation/
  Navigation/
  SessionList/
  TranscriptViewer/
  Diagnostics/
Application/
  SessionCatalog/
  TranscriptReadModel/
  LiveRefresh/
  SourceConfiguration/
Domain/
  SessionIdentity
  SessionSource
  ProjectGrouping
  TranscriptEvent
  TranscriptSegment
Infrastructure/
  CodexStoreAdapter
  HermesStoreAdapter
  FileWatcher
  LocalIndexStore
```

Rules:

- SwiftUI views are thin. They compose state and render view models.
- View models transform application DTOs into display-ready data. They do not perform file IO or decode rollout JSONL.
- Application use cases own refresh/indexing workflows.
- Infrastructure adapters own concrete file paths, SQLite access, JSONL decoding, and file-system watchers.
- The composition root is the only place that creates concrete infrastructure adapters for the UI.

---

## Navigation and Grouping

The left navigation should be modeled explicitly instead of inferred ad hoc in the UI.

Required grouping concepts:

- All Chats
- Projects
- Non-project Chats
- Sources / Profiles
- Recently Active
- Diagnostics / Unparsed or Problem Sessions

Rules:

- Project grouping must tolerate worktrees, scratch directories, missing `cwd`, and non-project chats.
- A session may have multiple useful labels: source, profile, project, model, and last activity.
- Do not hide sessions just because metadata is incomplete. Show them under a safe fallback group.

---

## Transcript Rendering

- Render user and assistant turns as first-class content.
- Tool calls and tool outputs are collapsed by default.
- Large outputs must support lazy expansion or truncation with an explicit “show more” action.
- Preserve timestamps and source metadata where available.
- Markdown-like content should be readable, but rendering failures must not break the whole transcript.
- Unknown event types should render as diagnostic events, not disappear.

---

## Live Updates

- Prefer file-system watching plus periodic reconciliation. Watchers can miss events; reconciliation prevents drift.
- Debounce bursts from active session writes.
- The UI should update incrementally, not rebuild the entire catalog for every append.
- Live tailing must not block the main thread.
- Indexer progress and failures should be observable in diagnostics.

---

## Performance

- Do not eagerly parse every transcript fully on launch.
- Build a lightweight catalog first: identity, source, title, project, timestamps, path, size, parse status.
- Load transcript detail on selection.
- Cache derived summaries/read models only when invalidation is explicit and tested.
- Very large files must be chunked or partially read.

---

## Privacy and Safety

- No network calls unless the feature explicitly requires them and Kuba approves.
- Do not transmit transcript content, file paths, user names, tokens, or command output.
- Do not watch arbitrary directories by default. Use known local agent stores and user-configured paths.
- Never delete, archive, rename, or rewrite Codex/Hermes session files in MVP.
- If future resume/open actions are added, commands must be visible, explicit, and user-triggered.

---

## macOS Integration

- Request only the permissions required to read configured local folders.
- Handle permission-denied states with clear recovery instructions.
- Prefer platform-native file watching and sandbox-aware access patterns.
- Keep app state separate from source transcript stores.
- Store SessionDeck indexes/config under the app’s own local application support directory, not inside Codex/Hermes stores.
