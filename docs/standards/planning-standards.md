# Planning Standards

These standards apply before drafting SessionDeck epics, features, stories, or Jira issues. They extend [coding-standards.md](./coding-standards.md).

## Navigation

- ↑ [Standards Index](./index.md)
- ↑ [Documentation Index](../INDEX.md)

---

## Planning Principle

Plan outcomes first, implementation second.

SessionDeck planning must connect product value to engineering boundaries:

```text
Product outcome → Epic → Feature → Story/Task → Verified slice
```

Do not create Jira epics/features until Kuba explicitly asks. Draft them in repository docs first when alignment is needed.

---

## Epic Standard

An epic is a coherent product outcome, not a technology bucket.

Every epic draft must include:

- Problem statement
- Target user / workflow
- Outcome and non-goals
- Scope boundaries
- Key features underneath it
- Architectural implications
- Risks and open questions
- Acceptance criteria at epic level
- Suggested delivery order

Good epic names:

- “Local Session Catalog and Navigation”
- “Readable Transcript Viewer”
- “Live Session Monitoring”

Bad epic names:

- “SwiftUI Work”
- “Build Backend”
- “Codex Parser Stuff”

---

## Feature Standard

A feature is a user-visible capability or a necessary technical capability that enables one.

Every feature draft must include:

- User value
- Inputs and outputs
- In-scope behavior
- Out-of-scope behavior
- Acceptance criteria
- Data/source assumptions
- Dependency boundaries
- Verification approach
- Failure/edge cases

Feature acceptance criteria must be observable. Avoid vague criteria like “works well” or “is fast” unless paired with concrete measurement.

---

## MVP Planning Rules

MVP must be narrow and valuable:

1. Read-only local source discovery.
2. Lightweight session catalog.
3. Project/chat grouping with safe fallbacks.
4. Readable transcript detail for selected sessions.
5. Live update for active sessions.
6. Diagnostics for parse/path/permission problems.

Do not include in MVP unless explicitly approved:

- Editing, deleting, archiving, or rewriting source session files.
- Remote sync.
- Telemetry upload.
- Autonomous command execution.
- Multi-user/team features.
- Deep analytics unrelated to monitoring current work.

---

## Architecture-Aware Planning Checklist

Before finalizing an epic or feature, answer:

- Which layer owns this behavior: Domain, Application, Infrastructure, or Presentation?
- What ports/interfaces are needed?
- What source files or stores are read?
- What is the fallback when metadata is incomplete?
- How do we test it without Kuba’s real HOME data?
- What can fail and how is the failure visible?
- Does this preserve read-only local-first safety?
- Does this avoid committing us to unstable Codex internals more than necessary?

---

## Jira Creation Rule

Creating Jira epics/features is a separate action.

Before creating Jira items, James must have:

1. Repository standards in place.
2. A draft epic/feature breakdown reviewed in docs or chat.
3. Kuba’s explicit instruction to create the Jira items.

No Jira mutation should happen as a side effect of planning.
