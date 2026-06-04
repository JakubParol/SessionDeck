import Testing
@testable import SessionDeckCore

@Test("transcript segment loading use case returns decoder results through an injected port")
func transcriptSegmentLoadingUseCaseUsesInjectedPort() throws {
    let sessionID = SessionID(rawValue: "session-1")
    let source = TranscriptSegmentSourceReference(
        sourceID: SessionSourceID(rawValue: "codex-fixture"),
        relativePath: "2026/06/04/rollout.jsonl",
        lineNumber: 1
    )
    let result = TranscriptDecodeResult(
        sessionID: sessionID,
        title: "Fixture transcript",
        segments: [
            TranscriptSegment(
                id: "segment-1",
                kind: .userMessage,
                text: "Hello",
                order: TranscriptSegmentOrder(index: 0),
                source: source,
                timestampDescription: nil
            ),
        ],
        diagnostics: [],
        isPartial: false
    )
    let useCase = LoadTranscriptSegmentsUseCase(
        transcriptDecoding: FakeTranscriptDecodingPort(results: [result])
    )

    let loaded = try useCase.loadTranscript(sessionID: sessionID)

    #expect(loaded == result)
}

@Test("selected transcript loading use case returns ordered segments and diagnostics")
func selectedTranscriptLoadingUseCaseReturnsReadModel() throws {
    let sessionID = SessionID(rawValue: "selected-session")
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let session = makeSelectedTranscriptSession(
        id: sessionID,
        sourceID: sourceID,
        sessionPath: "/tmp/sessiondeck/selected-session.jsonl"
    )
    let source = TranscriptSegmentSourceReference(
        sourceID: sourceID,
        relativePath: "selected-session.jsonl",
        lineNumber: 3
    )
    let diagnostic = TranscriptDecodeDiagnostic(
        code: "codex.unsupported_event",
        severity: .info,
        message: "Unsupported fixture event.",
        source: source,
        allowsDecodingToContinue: true
    )
    let unorderedResult = TranscriptDecodeResult(
        sessionID: sessionID,
        title: "Decoded selected session",
        segments: [
            TranscriptSegment(
                id: "assistant",
                kind: .assistantMessage,
                text: "Second",
                order: TranscriptSegmentOrder(index: 1),
                source: source,
                timestampDescription: nil
            ),
            TranscriptSegment(
                id: "user",
                kind: .userMessage,
                text: "First",
                order: TranscriptSegmentOrder(index: 0),
                source: source,
                timestampDescription: nil
            ),
        ],
        diagnostics: [diagnostic],
        isPartial: true
    )
    let useCase = LoadSelectedTranscriptUseCase(
        selectedTranscriptLoading: FakeSelectedTranscriptLoadingPort(results: [sessionID: unorderedResult])
    )

    let readModel = try useCase.loadTranscript(for: session)

    #expect(readModel.sessionID == sessionID)
    #expect(readModel.title == "Decoded selected session")
    #expect(readModel.sourceID == sourceID)
    #expect(readModel.sessionPath == "/tmp/sessiondeck/selected-session.jsonl")
    #expect(readModel.segments.map(\.text) == ["First", "Second"])
    #expect(readModel.diagnostics == [diagnostic])
    #expect(readModel.isPartial)
}

@Test("selected transcript loading use case surfaces typed missing path errors")
func selectedTranscriptLoadingUseCaseSurfacesTypedMissingPathErrors() throws {
    let sessionID = SessionID(rawValue: "missing-session")
    let session = makeSelectedTranscriptSession(
        id: sessionID,
        sourceID: SessionSourceID(rawValue: "codex-fixture"),
        sessionPath: "/tmp/sessiondeck/missing-session.jsonl"
    )
    let useCase = LoadSelectedTranscriptUseCase(
        selectedTranscriptLoading: FakeSelectedTranscriptLoadingPort(
            errorsBySessionID: [
                sessionID: SelectedTranscriptLoadingError.transcriptMissing(sessionID)
            ]
        )
    )

    #expect(throws: SelectedTranscriptLoadingError.transcriptMissing(sessionID)) {
        try useCase.loadTranscript(for: session)
    }
}

private func makeSelectedTranscriptSession(
    id: SessionID,
    sourceID: SessionSourceID,
    sessionPath: String
) -> SessionSummary {
    SessionSummary(
        id: id,
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex fixture",
            profileName: "Fixture"
        ),
        title: "Selected fixture",
        projectHint: CatalogProjectHint.unavailable,
        sessionPath: sessionPath,
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
