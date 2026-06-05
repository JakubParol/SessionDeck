import Testing
@testable import SessionDeckCore

@Test("selected transcript diagnostics show malformed-line warning without hiding valid content")
func selectedTranscriptDiagnosticsShowMalformedLineWarningWithoutHidingContent() throws {
    let state = try selectedTranscriptState(for: .malformedLine, sessionID: "malformed-detail")

    #expect(state.statusMessage == "Loaded 3 transcript segment(s) with 1 warning(s).")
    #expect(state.severity == .warning)
    #expect(state.diagnosticMessages == [
        "Warning line 3: A Codex transcript line could not be decoded as JSON."
    ])
    #expect(state.rows.map(\.roleLabel) == ["User", "Diagnostic", "Assistant"])
    #expect(state.rows.map(\.text) == [
        "Exercise malformed-line handling.",
        "Malformed Codex JSONL line.",
        "Parsing should continue after the malformed line.",
    ])
}

@Test("selected transcript diagnostics show unknown events as visible unsupported rows")
func selectedTranscriptDiagnosticsShowUnknownEventsAsVisibleUnsupportedRows() throws {
    let state = try selectedTranscriptState(for: .unknownEvent, sessionID: "unknown-detail")

    #expect(state.statusMessage == "Loaded 3 transcript segment(s) from a partial transcript.")
    #expect(state.severity == .healthy)
    #expect(state.diagnosticMessages == [
        "Info line 3: A Codex transcript event is not mapped to a readable segment yet."
    ])
    #expect(state.rows.map(\.roleLabel) == ["User", "Unknown: future_codex_event", "Assistant"])
    #expect(state.rows[1].text == "Unsupported Codex event: future_codex_event")
}

@Test("selected transcript diagnostics show missing metadata warnings and readable turns")
func selectedTranscriptDiagnosticsShowMissingMetadataWarningsAndReadableTurns() throws {
    let state = try selectedTranscriptState(for: .missingMetadata, sessionID: "missing-metadata-detail")

    #expect(state.statusMessage == "Loaded 2 transcript segment(s) with 1 warning(s).")
    #expect(state.severity == .warning)
    #expect(state.diagnosticMessages == [
        "Warning line 1: Session metadata is incomplete; SessionDeck is using safe fallback labels."
    ])
    #expect(state.rows.map(\.roleLabel) == ["User", "Assistant"])
    #expect(state.rows.map(\.text) == [
        "Exercise missing cwd and project metadata handling.",
        "Catalog grouping should use a safe fallback when metadata is missing.",
    ])
}

@Test("selected transcript diagnostics stay quiet for normal transcripts")
func selectedTranscriptDiagnosticsStayQuietForNormalTranscripts() throws {
    let state = try selectedTranscriptState(for: .minimalConversationTurns, sessionID: "normal-detail")

    #expect(state.statusMessage == "Loaded 2 transcript segment(s).")
    #expect(state.severity == .healthy)
    #expect(state.diagnosticMessages.isEmpty)
    #expect(state.rows.map(\.roleLabel) == ["User", "Assistant"])
}

private func selectedTranscriptState(
    for fixtureID: CodexTranscriptFixtureID,
    sessionID rawSessionID: String
) throws -> AppShellSelectedTranscriptDetailState {
    let sessionID = SessionID(rawValue: rawSessionID)
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let file = CodexTranscriptFile(
        sessionID: sessionID,
        fileURL: try CodexTranscriptFixtureManifest.fixtureURL(for: fixtureID),
        source: TranscriptSegmentSourceReference(
            sourceID: sourceID,
            relativePath: try CodexTranscriptFixtureManifest.fixture(for: fixtureID).filename,
            lineNumber: nil
        ),
        fallbackTitle: "Fallback title"
    )
    let decodeResult = try CodexTranscriptDecodingAdapter(files: [file]).loadTranscript(sessionID: sessionID)
    let readModel = SelectedTranscriptReadModel(
        session: diagnosticRenderingSession(id: sessionID, sourceID: sourceID),
        decodeResult: decodeResult
    )

    return AppShellSelectedTranscriptDetailState.loaded(readModel)
}

private func diagnosticRenderingSession(
    id: SessionID,
    sourceID: SessionSourceID
) -> SessionSummary {
    SessionSummary(
        id: id,
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(sourceID: sourceID.rawValue, displayName: "Codex fixture", profileName: nil),
        title: "Diagnostic fixture",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck/diagnostic.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        health: CatalogEntryHealth(parseStatus: .malformed(reason: "Synthetic diagnostic fixture"))
    )
}
