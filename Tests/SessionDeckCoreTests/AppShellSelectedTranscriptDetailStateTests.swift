import Testing
@testable import SessionDeckCore

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
    #expect(state.rows.map(\.text) == ["First", "Second"])
    #expect(state.rows.map(\.roleLabel) == ["User", "Assistant"])
    #expect(state.diagnosticMessages == ["Unknown event was kept as a diagnostic."])
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

private func selectedTranscriptSession(id: SessionID, sourceID: SessionSourceID) -> SessionSummary {
    SessionSummary(
        id: id,
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex fixture",
            profileName: "Fixture"
        ),
        title: "Selected fixture",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck/selected-session.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        health: CatalogEntryHealth(parseStatus: .complete)
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
