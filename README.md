# SessionDeck

SessionDeck is a macOS-focused project for viewing and monitoring local AI agent session activity, initially centered on Codex sessions.

## Purpose

The first product direction is a local-first session viewer that helps Kuba browse, search, and live-monitor Codex CLI/App session transcripts without relying on Codex App refresh behavior.

Target experience:

- left navigation organized by Projects and Chats
- support for non-project Codex chats
- visibility into CLI-started/resumed sessions
- readable transcript rendering
- live updates when local session logs change
- optional profile/source filtering for Hermes/Naomi-style workflows when supported

## References

- Jira board: https://jakubparol.atlassian.net/jira/software/projects/SDECK/boards/67
- GitHub repository: https://github.com/JakubParol/SessionDeck
- Local path: `/Users/jakubparol/Repos/SessionDeck`

## Native macOS scaffold

SessionDeck currently contains a Swift Package Manager native macOS scaffold:

- `SessionDeckApp` — SwiftUI executable target with Presentation code for the placeholder launch screen.
- `SessionDeckCore` — core module with explicit Domain, Application, Infrastructure, and composition-root folders, including Application-owned ports/DTOs for source discovery, session catalogs, and transcript previews.
- `SessionDeckCoreTests` — smoke, use-case, fake-port, and architecture-boundary tests for the placeholder launch state and safety policy.

The placeholder app shell intentionally has no session catalog implementation yet. It configures zero session sources and performs no local agent-store reads, network activity, command execution, telemetry, uploads, or session mutation.

Architecture dependency direction is documented in `docs/ARCHITECTURE_V1.md`:

```text
Presentation → Application → Domain
Infrastructure → Application / Domain
Composition Root → Application + Infrastructure
```

## Developer quality gate

Fresh checkout requirements:

```bash
./scripts/build.sh
./scripts/test.sh
```

The scripts are CI-suitable wrappers around the native SwiftPM commands:

```bash
swift build
swift test
```

Run the combined local quality gate before committing production code:

```bash
./scripts/quality-gate.sh
```

Warnings are treated as quality-gate failures by project standard; fix root causes instead of suppressing warnings. No separate Swift lint/format tool has been selected yet.

To manually launch the placeholder app from the package during development:

```bash
swift run SessionDeck
```

## Documentation

See `docs/INDEX.md`.

Key standards:

- `docs/standards/index.md`
- `docs/standards/coding-standards.md`
- `docs/standards/macos-app-standards.md`
- `docs/standards/testing-standards.md`
- `docs/standards/planning-standards.md`
- `docs/standards/documentation.md`

## Agent coordination

See `AGENTS.md` for the James/Hermes ↔ Codex communication protocol and project operating rules.
