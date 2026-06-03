# Testing Standards

These standards extend [coding-standards.md](./coding-standards.md).

## Navigation

- ↑ [Standards Index](./index.md)
- ↑ [Documentation Index](../INDEX.md)

---

## Test Strategy

SessionDeck should test behavior at the lowest useful layer.

| Type | Use For | Real IO? |
|---|---|---|
| Unit | Domain parsing-independent rules, grouping, filtering, sorting, value objects | No |
| Application | Use-case orchestration with injected ports and fakes | No real user HOME; fakes/temp fixtures only |
| Infrastructure | Codex/Hermes adapters, JSONL decoding, SQLite/file index, file watchers | Yes, but only against temp directories/fixtures |
| UI/View Model | Navigation state, display transformations, transcript segment rendering decisions | No real IO |
| End-to-end smoke | App can launch, index fixture sessions, show transcript, refresh on append | Temp fixture sources only |

---

## Fixture Rules

- Never test against Kuba’s real `~/.codex`, `~/.hermes`, or project workspaces.
- Use checked-in minimal fixture transcripts for known formats.
- Use generated temporary directories for large-file, append, malformed-line, and watcher tests.
- Construct fixture roots through the explicit test-support helpers, not by reading process `HOME` implicitly.
- Guard fixture roots with `FixturePathGuard` before a test creates or reads a source directory.
- Reject real `.codex` and `.hermes` roots, including descendants and equivalent expanded paths.
- Fixtures must include malformed and unknown events to enforce defensive parsing.
- Redact or synthesize all fixture content. Do not commit private transcripts.

Required fixture categories once implementation starts:

- minimal Codex rollout JSONL
- Codex rollout with tool calls and tool outputs
- malformed JSONL line inside otherwise valid transcript
- large transcript / large tool output
- missing metadata / missing cwd
- non-project chat
- profile/source path fixture

## Synthetic Fixture Harness

The SessionDeck test target owns a synthetic Codex fixture harness for parser,
catalog, and application smoke tests. Use this harness instead of Kuba's real
`~/.codex`, `~/.hermes`, or project workspaces.

Harness building blocks:

- Checked-in fixtures live under
  `Tests/SessionDeckCoreTests/Fixtures/CodexTranscripts/` and are read through
  `CodexTranscriptFixtureManifest`.
- Temporary Codex-like stores are created with `TempCodexSessionStoreFactory`.
  Generated stores may contain `.codex/sessions/...` layouts, but only inside a
  validated temp root.
- `GeneratedCodexTranscriptFixtures` creates deterministic large transcript and
  large tool-output scenarios with small default sizes for normal gates.
- `FixturePathGuard` and `FixtureTempRoot` must guard any fixture root that a
  test reads or writes. Unsafe real HOME paths must fail with actionable errors.
- Application-level smoke tests can compose fixture-backed fake ports instead of
  introducing real source discovery, catalog indexing, transcript decoding, or
  watcher behavior before those slices are implemented.

Required harness coverage in the normal quality gate:

- A checked-in synthetic fixture is read through the manifest.
- A generated temp Codex-like store is created and cleaned up.
- Real HOME `.codex` and `.hermes` roots, including descendants or equivalent
  paths, are rejected.
- Required categories remain represented: minimal rollout, tool calls/output,
  malformed line, large output, missing metadata, non-project chat, and
  source/profile path fixture.

`./scripts/quality-gate.sh` runs `./scripts/test.sh`, and `./scripts/test.sh`
runs `swift test`, so harness tests in `SessionDeckCoreTests` are part of the
documented local gate. A fresh checkout must pass this gate without any real
agent session stores present.

---

## Testing Rules

- One behavior per test. Multiple assertions are fine when they verify one behavior.
- Tests must not depend on execution order.
- Tests must clean up temporary files and watchers.
- Inject clocks, file systems, watchers, and stores rather than relying on globals.
- Prefer deterministic fake watchers in application tests; use real file-system watchers only in infrastructure tests.
- Parser tests must assert graceful degradation, not only happy path decoding.
- Performance-sensitive code needs bounded tests that prove large files are not fully rendered or loaded into UI state unnecessarily.

---

## Expected Coverage by Area

- Session identity extraction: unit tests
- Project grouping fallback rules: unit tests
- Transcript decoding: fixture-based infrastructure tests
- Catalog indexing: application + infrastructure tests
- Live refresh / append handling: application tests with fake watcher, infrastructure smoke with temp directory
- View models and filters: unit tests
- UI rendering: targeted smoke/UI tests only; do not over-test layout details

---

## Quality Gate

When the implementation toolchain is selected, document exact commands here and in the README.

Native Swift/macOS expected baseline:

```bash
swift test
xcodebuild test -scheme <Scheme> -destination 'platform=macOS'
```

If linting/formatting tools are added, the repository must expose a documented lint command. Warnings fail the gate.
