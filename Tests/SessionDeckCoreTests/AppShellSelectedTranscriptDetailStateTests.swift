import Testing
@testable import SessionDeckCore

@Test("selected transcript detail state exposes distinct reading surface modes")
func selectedTranscriptDetailStateExposesDistinctReadingSurfaceModes() throws {
    let sessionID = SessionID(rawValue: "surface-mode-session")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let healthyReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Healthy selected session",
            segments: [
                TranscriptSegment(
                    id: "user",
                    kind: .userMessage,
                    text: "Read this.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )
    let warningReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Warning selected session",
            segments: [],
            diagnostics: [
                TranscriptDecodeDiagnostic(
                    code: "codex.unknown_event",
                    severity: .warning,
                    message: "Unknown event was preserved.",
                    source: transcriptSource(sourceID: sourceID, lineNumber: 2),
                    allowsDecodingToContinue: true
                ),
            ],
            isPartial: false
        )
    )

    #expect(AppShellSelectedTranscriptDetailState.noSelection.displayMode == .noSelection)
    #expect(AppShellSelectedTranscriptDetailState.loading(sessionTitle: "Loading").displayMode == .loading)
    #expect(AppShellSelectedTranscriptDetailState.loaded(healthyReadModel).displayMode == .loaded)
    #expect(AppShellSelectedTranscriptDetailState.loaded(warningReadModel).displayMode == .warning)
    #expect(AppShellSelectedTranscriptDetailState.failed(
        SelectedTranscriptLoadingError.transcriptUnreadable(sessionID)
    ).displayMode == .error)
}

@Test("selected transcript detail state maps loaded read models into presentation content")
func selectedTranscriptDetailStateMapsLoadedReadModel() throws {
    let sessionID = SessionID(rawValue: "selected-session")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let readModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Decoded selected session",
            segments: [
                TranscriptSegment(
                    id: "assistant",
                    kind: .assistantMessage,
                    text: "Second",
                    order: TranscriptSegmentOrder(index: 1),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 2),
                    timestampDescription: "10:01"
                ),
                TranscriptSegment(
                    id: "user",
                    kind: .userMessage,
                    text: "First",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: "10:00"
                ),
            ],
            diagnostics: [
                TranscriptDecodeDiagnostic(
                    code: "codex.unknown_event",
                    severity: .warning,
                    message: "Unknown event was kept as a diagnostic.",
                    source: transcriptSource(sourceID: sourceID, lineNumber: 3),
                    allowsDecodingToContinue: true
                ),
            ],
            isPartial: true
        )
    )

    let state = AppShellSelectedTranscriptDetailState.loaded(readModel)

    #expect(state.title == "Decoded selected session")
    #expect(state.statusMessage == "Loaded 2 transcript segment(s) with 1 warning(s).")
    #expect(state.severity == .warning)
    #expect(state.metadataRows.map(\.title) == [
        "Title",
        "Source",
        "Project",
        "Path",
        "Created",
        "Last Activity",
    ])
    #expect(state.metadataRows.map(\.value) == [
        "Decoded selected session",
        "Codex fixture / Fixture",
        "SessionDeck",
        "/tmp/sessiondeck/selected-session.jsonl",
        "1",
        "2",
    ])
    #expect(state.metadataRows.allSatisfy { $0.isFallback == false })
    #expect(state.rows.map(\.text) == ["First", "Second"])
    #expect(state.rows.map(\.roleLabel) == ["User", "Assistant"])
    #expect(state.diagnosticMessages == ["Warning line 3: Unknown event was kept as a diagnostic."])
}

@Test("selected transcript rows expose stable role styles for conversation rendering")
func selectedTranscriptRowsExposeRoleStyles() {
    let source = transcriptSource(sourceID: SessionSourceID(rawValue: "fixture"), lineNumber: 1)
    let userRow = AppShellTranscriptSegmentRow.make(
        segment: TranscriptSegment(
            id: "user",
            kind: .userMessage,
            text: "Hello",
            order: TranscriptSegmentOrder(index: 0),
            source: source,
            timestampDescription: "10:00"
        )
    )
    let assistantRow = AppShellTranscriptSegmentRow.make(
        segment: TranscriptSegment(
            id: "assistant",
            kind: .assistantMessage,
            text: "Hi",
            order: TranscriptSegmentOrder(index: 1),
            source: source,
            timestampDescription: "10:01"
        )
    )
    let toolRow = AppShellTranscriptSegmentRow.make(
        segment: TranscriptSegment(
            id: "tool",
            kind: .toolOutput(callID: "call-1"),
            text: "Tool output",
            order: TranscriptSegmentOrder(index: 2),
            source: source,
            timestampDescription: nil
        )
    )

    #expect(userRow.roleStyle == .userTurn)
    #expect(assistantRow.roleStyle == .assistantTurn)
    #expect(toolRow.roleStyle == .supporting)
}

@Test("selected transcript detail state renders multi-turn fixture conversations in order")
func selectedTranscriptDetailStateRendersMultiTurnFixtureConversationsInOrder() throws {
    let sessionID = SessionID(rawValue: "multi-turn-selected-session")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let source = TranscriptSegmentSourceReference(
        sourceID: sourceID,
        relativePath: try CodexTranscriptFixtureManifest.fixture(for: .multiTurnConversation).filename,
        lineNumber: nil
    )
    let file = CodexTranscriptFile(
        sessionID: sessionID,
        fileURL: try CodexTranscriptFixtureManifest.fixtureURL(for: .multiTurnConversation),
        source: source,
        fallbackTitle: "Fallback title"
    )
    let decodeResult = try CodexTranscriptDecodingAdapter(files: [file]).loadTranscript(sessionID: sessionID)
    let readModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: decodeResult
    )

    let state = AppShellSelectedTranscriptDetailState.loaded(readModel)

    #expect(state.rows.map(\.roleStyle) == [
        .userTurn,
        .assistantTurn,
        .userTurn,
        .supporting,
        .assistantTurn,
    ])
    #expect(state.rows.map(\.text) == [
        "List the synthetic steps.",
        "First, inspect the fixture. Second, decode the turns.",
        "Keep the order stable.",
        "Unsupported Codex event: future_codex_event",
        "Order and roles remain stable.",
    ])
}

@Test("selected transcript row exposes readable fallback text for empty content")
func selectedTranscriptRowExposesReadableFallbackTextForEmptyContent() {
    let row = AppShellTranscriptSegmentRow.make(
        segment: TranscriptSegment(
            id: "empty",
            kind: .assistantMessage,
            text: "  ",
            order: TranscriptSegmentOrder(index: 0),
            source: transcriptSource(sourceID: SessionSourceID(rawValue: "fixture"), lineNumber: 1),
            timestampDescription: nil
        )
    )

    #expect(row.text == "Empty transcript segment.")
    #expect(row.roleStyle == .assistantTurn)
}

@Test("selected transcript detail state exposes readable metadata fallbacks")
func selectedTranscriptDetailStateExposesReadableMetadataFallbacks() {
    let sessionID = SessionID(rawValue: "missing-metadata")
    let sourceID = SessionSourceID(rawValue: "unknown-source")
    let readModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(
            id: sessionID,
            sourceID: sourceID,
            sourceLabel: CatalogSourceLabel(sourceID: sourceID.rawValue, displayName: "", profileName: nil),
            title: nil,
            projectHint: CatalogProjectHint(cwdPath: nil, displayName: ""),
            sessionPath: "",
            activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: nil),
            metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: nil),
            health: CatalogEntryHealth(parseStatus: .missingMetadata)
        ),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "",
            segments: [],
            diagnostics: [],
            isPartial: false
        )
    )

    let state = AppShellSelectedTranscriptDetailState.loaded(readModel)

    #expect(state.title == "Untitled session")
    #expect(state.metadataRows.map(\.value) == [
        "Untitled session",
        "Unknown source",
        "Project unavailable",
        "Path unavailable",
        "Created time unavailable",
        "Last activity unavailable",
    ])
    #expect(state.metadataRows.allSatisfy { $0.isFallback })
}

@Test("selected transcript detail state maps typed loading failures to user-actionable copy")
func selectedTranscriptDetailStateMapsTypedFailures() {
    let sessionID = SessionID(rawValue: "missing-session")

    let missing = AppShellSelectedTranscriptDetailState.failed(
        SelectedTranscriptLoadingError.transcriptMissing(sessionID)
    )
    let unavailable = AppShellSelectedTranscriptDetailState.failed(
        SelectedTranscriptLoadingError.transcriptUnavailable(sessionID)
    )

    #expect(missing.title == "Transcript unavailable")
    #expect(missing.statusMessage == "The selected transcript file is missing.")
    #expect(missing.severity == .error)
    #expect(unavailable.statusMessage == "The selected session cannot be loaded yet.")
    #expect(unavailable.severity == .warning)
}

private func selectedTranscriptSession(
    id: SessionID,
    sourceID: SessionSourceID,
    sourceLabel: CatalogSourceLabel? = nil,
    title: String? = "Selected fixture",
    projectHint: CatalogProjectHint = CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
    sessionPath: String = "/tmp/sessiondeck/selected-session.jsonl",
    activity: CatalogActivityTimestamps = CatalogActivityTimestamps(
        createdAtEpochSeconds: 1,
        lastActivityEpochSeconds: 2
    ),
    metadata: CatalogSessionMetadata = CatalogSessionMetadata(modelName: nil, agentProfileName: nil),
    health: CatalogEntryHealth = CatalogEntryHealth(parseStatus: .complete)
) -> SessionSummary {
    let resolvedSourceLabel = sourceLabel ?? CatalogSourceLabel(
        sourceID: sourceID.rawValue,
        displayName: "Codex fixture",
        profileName: "Fixture"
    )

    return SessionSummary(
        id: id,
        sourceID: sourceID,
        sourceLabel: resolvedSourceLabel,
        title: title,
        projectHint: projectHint,
        sessionPath: sessionPath,
        activity: activity,
        fileSize: CatalogFileSize(byteCount: 128),
        metadata: metadata,
        health: health
    )
}

private func transcriptSource(
    sourceID: SessionSourceID,
    lineNumber: Int
) -> TranscriptSegmentSourceReference {
    TranscriptSegmentSourceReference(
        sourceID: sourceID,
        relativePath: "selected-session.jsonl",
        lineNumber: lineNumber
    )
}
