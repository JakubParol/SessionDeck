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
    #expect(state.diagnosticRows.map(\.severity) == [.warning])
    #expect(state.diagnosticRows.map(\.message) == state.diagnosticMessages)
}

@Test("selected transcript detail state distinguishes warning and blocking diagnostics")
func selectedTranscriptDetailStateDistinguishesWarningAndBlockingDiagnostics() {
    let sessionID = SessionID(rawValue: "diagnostic-severity-session")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let readModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Diagnostic severity session",
            segments: [],
            diagnostics: [
                TranscriptDecodeDiagnostic(
                    code: "codex.missing_metadata",
                    severity: .warning,
                    message: "Session metadata is incomplete.",
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    allowsDecodingToContinue: true
                ),
                TranscriptDecodeDiagnostic(
                    code: "blocking_failure",
                    severity: .error,
                    message: "Readable transcript content is blocked.",
                    source: transcriptSource(sourceID: sourceID, lineNumber: 2),
                    allowsDecodingToContinue: false
                ),
            ],
            isPartial: true
        )
    )

    let state = AppShellSelectedTranscriptDetailState.loaded(readModel)

    #expect(state.severity == .error)
    #expect(state.displayMode == .error)
    #expect(state.diagnosticRows.map(\.severity) == [.warning, .error])
    #expect(state.diagnosticRows.map(\.message) == [
        "Warning line 1: Session metadata is incomplete.",
        "Error line 2: Readable transcript content is blocked.",
    ])
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

@Test("selected transcript detail state keeps last-known-good rows during failed live refresh")
func selectedTranscriptDetailStateKeepsLastKnownGoodRowsDuringFailedLiveRefresh() {
    let sessionID = SessionID(rawValue: "live-refresh-failed")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let previousReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Readable before append",
            segments: [
                TranscriptSegment(
                    id: "stable-tool-output",
                    kind: .toolOutput(callID: "call-1"),
                    text: "Expanded output stays readable.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )

    let state = AppShellSelectedTranscriptDetailState.liveRefresh(
        .failed(previous: previousReadModel, message: "Malformed appended line.")
    )

    #expect(state.title == "Readable before append")
    #expect(state.rows.map(\.id) == ["stable-tool-output"])
    #expect(state.rows.first?.toolPresentation?.expandedText == "Expanded output stays readable.")
    #expect(state.refreshStatus == .failed(message: "Malformed appended line."))
    #expect(state.statusMessage == "Refresh failed: Malformed appended line. Last readable content is still shown.")
    #expect(state.isLoading == false)
}

@Test("selected transcript detail state preserves expanded stable tool rows after append refresh")
func selectedTranscriptDetailStatePreservesExpandedStableToolRowsAfterAppendRefresh() {
    let sessionID = SessionID(rawValue: "live-refresh-expanded-tool")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let refreshedReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Refreshed transcript",
            segments: [
                TranscriptSegment(
                    id: "stable-tool-output",
                    kind: .toolOutput(callID: "call-1"),
                    text: "Existing output.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: nil
                ),
                TranscriptSegment(
                    id: "new-assistant-turn",
                    kind: .assistantMessage,
                    text: "New content arrived.",
                    order: TranscriptSegmentOrder(index: 1),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 2),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )
    let refreshedState = AppShellSelectedTranscriptDetailState.liveRefresh(.loaded(refreshedReadModel))

    let preservedExpansion = refreshedState.preservedExpandedToolRowIDs(
        from: ["stable-tool-output", "stale-tool-output", "new-assistant-turn"]
    )

    #expect(preservedExpansion == ["stable-tool-output"])
}

@Test("selected transcript detail state exposes refresh status and conservative follow tail policy")
func selectedTranscriptDetailStateExposesRefreshStatusAndConservativeFollowTailPolicy() {
    let sessionID = SessionID(rawValue: "live-refresh-follow-tail")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let previousReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Previous transcript",
            segments: [
                TranscriptSegment(
                    id: "line-1",
                    kind: .assistantMessage,
                    text: "Already visible.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )
    let refreshedReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Previous transcript",
            segments: [
                TranscriptSegment(
                    id: "line-1",
                    kind: .assistantMessage,
                    text: "Already visible.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: nil
                ),
                TranscriptSegment(
                    id: "line-2",
                    kind: .assistantMessage,
                    text: "New append.",
                    order: TranscriptSegmentOrder(index: 1),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 2),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )

    let refreshingState = AppShellSelectedTranscriptDetailState.liveRefresh(.refreshing(previous: previousReadModel))
    let refreshedState = AppShellSelectedTranscriptDetailState.liveRefresh(.loaded(refreshedReadModel))

    #expect(refreshingState.rows.map(\.id) == ["line-1"])
    #expect(refreshingState.refreshStatus == .refreshing)
    #expect(refreshingState.shouldFollowTailAfterRefresh(isUserAtTail: true) == false)
    #expect(refreshedState.rows.map(\.id) == ["line-1", "line-2"])
    #expect(refreshedState.refreshStatus == .refreshed)
    #expect(refreshedState.shouldFollowTailAfterRefresh(isUserAtTail: true))
    #expect(refreshedState.shouldFollowTailAfterRefresh(isUserAtTail: false) == false)
}

@Test("selected transcript detail state surfaces refresh diagnostics and recovers after success")
func selectedTranscriptDetailStateSurfacesRefreshDiagnosticsAndRecoversAfterSuccess() {
    let sessionID = SessionID(rawValue: "live-refresh-diagnostics")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let previousReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Recoverable transcript",
            segments: [
                TranscriptSegment(
                    id: "line-1",
                    kind: .assistantMessage,
                    text: "Last readable content.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )
    let recoveredReadModel = SelectedTranscriptReadModel(
        session: selectedTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Recoverable transcript",
            segments: [
                TranscriptSegment(
                    id: "line-1",
                    kind: .assistantMessage,
                    text: "Last readable content.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 1),
                    timestampDescription: nil
                ),
                TranscriptSegment(
                    id: "line-2",
                    kind: .assistantMessage,
                    text: "Recovered append.",
                    order: TranscriptSegmentOrder(index: 1),
                    source: transcriptSource(sourceID: sourceID, lineNumber: 2),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )

    let failedState = AppShellSelectedTranscriptDetailState.liveRefresh(
        .failed(previous: previousReadModel, message: "Unreadable temporary append.")
    )
    let recoveredState = AppShellSelectedTranscriptDetailState.liveRefresh(.loaded(recoveredReadModel))

    #expect(failedState.rows.map(\.id) == ["line-1"])
    #expect(failedState.diagnosticMessages == ["Refresh error: Unreadable temporary append."])
    #expect(recoveredState.rows.map(\.id) == ["line-1", "line-2"])
    #expect(recoveredState.diagnosticMessages.isEmpty)
    #expect(recoveredState.refreshStatus == .refreshed)
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
