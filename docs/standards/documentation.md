# Documentation Standard

Every SessionDeck documentation change follows this structure.

## Navigation

- ↑ [Standards Index](./index.md)
- ↑ [Documentation Index](../INDEX.md)

---

## Required Documentation Trio

Every project starts with:

```text
project-root/
├── README.md       # For humans: what it is, how to run it, architecture overview
├── AGENTS.md       # For AI agents: context, scope, required reading, rules
└── docs/
    └── INDEX.md    # Table of contents for all docs in this project
```

SessionDeck already follows this trio.

---

## docs/INDEX.md

The documentation index must:

- List every maintained doc under `docs/`.
- Link to standards.
- Link up to README and AGENTS.
- Avoid orphaned markdown files.

---

## File Naming

- Use `UPPER_SNAKE_CASE` for durable reference docs: `ARCHITECTURE_V1.md`, `PRODUCT_VISION_V1.md`.
- Append `_V1`, `_V2` when a document describes a versioned design or contract.
- Use `kebab-case` with a date suffix for time-bound records: `ui-audit-2026-06-02.md`.
- Shared standards live in `docs/standards/`.
- Superseded docs move to `docs/_archive/` and must be removed from the main index.

---

## Language and Style

- Repository documentation is written in English.
- Keep docs scannable: headers, bullets, tables, short sections.
- Lead with the most important information.
- Prefer concrete examples over abstract prose.
- Avoid duplicating the same rule in many places. Link to the source of truth.

---

## When to Create Documentation

Create docs when:

- A product/architecture decision needs shared memory.
- A complex feature needs explanation beyond code comments.
- Setup or verification has non-obvious steps.
- A planning artifact must be reviewed before Jira creation.

Do not create docs when:

- The code or README already explains it sufficiently.
- The doc would go stale faster than it helps.
- It duplicates an existing standard or plan.

---

## Required Review Before Commit

Before committing documentation changes:

- Check every link path.
- Ensure every new doc is linked from `docs/INDEX.md` or a parent doc.
- Ensure the docs do not claim implementation exists before it does.
- Ensure planning drafts are clearly marked as drafts unless approved.
