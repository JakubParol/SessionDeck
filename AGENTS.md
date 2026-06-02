# AGENTS.md — SessionDeck

## What This Is

SessionDeck is a local-first macOS project for browsing and monitoring local AI-agent session activity, starting with Codex session transcripts.

Canonical project references:
- Jira board: https://jakubparol.atlassian.net/jira/software/projects/SDECK/boards/67
- GitHub repository: https://github.com/JakubParol/SessionDeck
- Local repository path: /Users/jakubparol/Repos/SessionDeck

## Scope

- **In scope:** local session discovery, cataloging, project/chat grouping, transcript rendering, live monitoring, diagnostics, standards, planning docs, and safe read-only integrations with local agent stores.
- **Out of scope:** transcript upload, telemetry, remote sync, autonomous command execution, editing/deleting/rewriting source session files, Jira/GitHub mutation without Kuba’s explicit instruction, and building a generic multi-user SaaS product.

## Required Reading (Mandatory)

1. This file
2. [docs/INDEX.md](./docs/INDEX.md)
3. [docs/standards/index.md](./docs/standards/index.md)
4. [docs/standards/coding-standards.md](./docs/standards/coding-standards.md)
5. [docs/standards/documentation.md](./docs/standards/documentation.md)

Read stack-specific standards before touching that area:
- [docs/standards/macos-app-standards.md](./docs/standards/macos-app-standards.md) before macOS/UI/app work
- [docs/standards/testing-standards.md](./docs/standards/testing-standards.md) before tests
- [docs/standards/planning-standards.md](./docs/standards/planning-standards.md) before epics/features/stories/Jira work

## Rules

- Treat standards as implementation rules. Architecture describes direction; standards govern how code and docs are written.
- Keep the app local-first and privacy-preserving.
- Prefer read-only ingestion of local session/transcript files unless Kuba explicitly asks for write behavior.
- Favor Clean Architecture, separation of concerns, explicit dependency boundaries, testability, and maintainability.
- Treat large transcript files carefully: use incremental/lazy loading, indexing, and resilient parsing.
- Do not assume Codex transcript formats are stable; parsers should be defensive.
- Do not create Jira epics/features/issues, push to GitHub, or mutate external project systems unless Kuba explicitly asks.

## James/Hermes and Codex communication

Kuba created a dedicated Codex App session for SessionDeck coordination:

- Codex session id: 019e8823-895e-7e42-8cd5-74622f5b7363
- Visible title/context: James-Codex Communication under the SessionDeck project.

James/Hermes communicates into that Codex session from the local machine with the user HOME session store, for example:

```bash
HOME=/Users/jakubparol codex resume 019e8823-895e-7e42-8cd5-74622f5b7363 \
  -C /Users/jakubparol/Repos/SessionDeck \
  --no-alt-screen "James/Hermes here. <message>"
```

Operational notes:

- WhatsApp with Kuba remains the human control plane.
- The Codex session above is the James-Codex coordination thread for this project.
- Codex should not send WhatsApp messages, modify Jira, push to GitHub, or change configuration unless Kuba explicitly authorizes that action.
- When James asks Codex only for discussion or assessment, Codex should keep output concise and avoid file edits.
- Codex App UI may cache session state; CLI `codex resume` can append to the local thread even if the app view needs refresh/reopen to display new turns.

## Current repository structure

- `AGENTS.md` — project and agent operating guidance.
- `README.md` — project overview.
- `docs/INDEX.md` — documentation index.
- `docs/standards/` — project standards adapted from the CrackerAi workspace standards.
