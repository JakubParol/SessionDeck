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
