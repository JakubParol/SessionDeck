# AGENTS.md

## Project

SessionDeck is a local-first project for browsing and monitoring local AI agent session activity, starting with Codex session transcripts.

Canonical project references:
- Jira board: https://jakubparol.atlassian.net/jira/software/projects/SDECK/boards/67
- GitHub repository: https://github.com/JakubParol/SessionDeck
- Local repository path: /Users/jakubparol/Repos/SessionDeck

## Operating principles

- Keep the app local-first and privacy-preserving.
- Prefer read-only ingestion of local session/transcript files unless Kuba explicitly asks for write behavior.
- Favor clean architecture, separation of concerns, explicit dependency boundaries, testability, and maintainability.
- Treat large transcript files carefully: use incremental/lazy loading, indexing, and resilient parsing.
- Do not assume Codex transcript formats are stable; parsers should be defensive.

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

## Current repository bootstrap

Initial repository structure:

- `AGENTS.md` — project and agent operating guidance.
- `README.md` — project overview.
- `docs/INDEX.md` — documentation index placeholder.
