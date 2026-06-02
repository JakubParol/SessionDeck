# Coding Standards

These standards apply to SessionDeck unless a more specific project document overrides them.

## Navigation

- ↑ [Standards Index](./index.md)
- ↑ [Documentation Index](../INDEX.md)

## Required Reading by Work Type

Before working on a layer, read this entire file and the relevant specific standard:

- **macOS / UI / app shell:** [macos-app-standards.md](./macos-app-standards.md)
- **Tests:** [testing-standards.md](./testing-standards.md)
- **Planning / Jira breakdown:** [planning-standards.md](./planning-standards.md)
- **Documentation:** [documentation.md](./documentation.md)

---

## Core Architecture

SessionDeck uses Clean Architecture as the default direction.

Required dependency direction:

```text
Presentation → Application → Domain
Infrastructure → Application / Domain
```

Rules:

- Domain does not import UI, persistence, file-system, OS, network, or framework concerns.
- Application orchestrates use cases through ports/interfaces owned by Application.
- Infrastructure implements adapters for local file systems, Codex stores, indexes, persistence, notifications, and external tools.
- Presentation renders view models and invokes application use cases. It does not parse Codex JSONL, query SQLite directly, or scan the file system directly.
- Composition root wires concrete adapters to application ports.

Layer responsibilities:

| Layer | Does | Does NOT |
|---|---|---|
| Domain | Entities, value objects, parsing-independent concepts, grouping rules, pure policies | File IO, OS APIs, UI state, database calls |
| Application | Use cases, ports, orchestration, DTOs, indexing workflow, refresh workflow | SwiftUI/AppKit rendering, concrete file watchers, SQLite details |
| Infrastructure | File watching, Codex/Hermes source adapters, SQLite/file indexes, transcript decoders, OS integrations | Business decisions, view composition |
| Presentation | SwiftUI/AppKit views, view models, navigation, readable transcript rendering | Direct IO, direct transcript parsing, domain mutation bypassing use cases |

---

## Local-First and Read-Only by Default

- SessionDeck is local-first. No telemetry, no transcript upload, no remote logging.
- Transcript/source ingestion is read-only by default.
- Any feature that writes to Codex/Hermes session stores, modifies archives, launches commands, or resumes sessions must be explicitly designed and approved.
- Never treat local Codex file formats as stable public contracts. Parsers must be defensive and forward-compatible.
- Large transcript files must use bounded reads, lazy rendering, chunking, or indexing. Do not load unbounded multi-MB files into UI state.

---

## Tooling Rules

- Use the platform-native toolchain selected for the app. If the app is native macOS, prefer Swift, SwiftUI, Swift Package Manager, and Xcode-compatible build/test commands.
- Do not introduce a cross-platform runtime, Electron, web server, or shell-script runtime layer without an explicit architecture decision.
- Root scripts are allowed only for developer orchestration: install, lint, test, build, and local diagnostics.
- Do not implement product runtime behavior through shell scripts, process wrappers, or CLI chaining.
- If a code project is introduced, the same change must introduce explicit build, lint, and test commands in the README or scripts.

---

## Quality Gate

Before every commit that touches production code, run the narrowest available quality gate for the changed project:

```bash
# examples; exact commands must be documented when the code project is scaffolded
swift test
xcodebuild test -scheme <Scheme> -destination 'platform=macOS'
./scripts/lint.sh
./scripts/test.sh
```

Rules:

- Zero warnings policy. Every warning is a bug unless the toolchain has a documented false positive.
- No suppression hacks. Do not use blanket lint weakening, ignored warnings, force-casts, or force-unwraps to hide issues.
- Fix root causes. No duct tape.
- If no quality gate exists for code you are changing, stop and add/document the gate before continuing.

Documentation-only commits must at minimum be reviewed for links, navigation, and consistency with [documentation.md](./documentation.md).

---

## File Size and Splitting

- Hard limit: 300 lines per source file.
- One primary type per file unless the secondary type is private and tightly coupled.
- Split by concern before a folder grows into a mixed bag.
- Avoid `Utils`, `Helpers`, or `Common` dumping grounds. Name modules by intent.

---

## Code Quality

- Type everything explicitly at boundaries.
- Prefer immutable values and pure functions for parsing, grouping, filtering, and sorting.
- Use dependency injection for clocks, file-system access, file watchers, stores, and command execution.
- Domain/application code should be deterministic and testable without real user HOME data.
- Keep DTOs separate from persistence records and UI view models.
- DRY with judgment: extract after a real repeated concept appears, not preemptively.
- YAGNI: build only what the current epic/feature needs.

---

## Error Handling and Observability

- Use typed domain/application errors instead of stringly typed failure paths.
- Surface user-actionable errors in the UI; log diagnostic detail locally where appropriate.
- Parser failures should degrade gracefully: keep the session visible, mark the failed segment, and continue when possible.
- File watcher/indexer failures must be observable to the user or diagnostics view; silent drift is not acceptable.

---

## Git Workflow

- Work on feature branches once active implementation starts. Do not treat `main` as a scratchpad.
- Commit small, coherent changes with meaningful messages.
- Do not push, open PRs, create Jira issues, or mutate external project systems unless Kuba explicitly asks.
