import Testing
@testable import SessionDeckCore

@Test("selected transcript tool rows expose collapsed default metadata without raw output text")
func selectedTranscriptToolRowsExposeCollapsedDefaultMetadata() {
    let row = AppShellTranscriptSegmentRow.make(
        segment: TranscriptSegment(
            id: "tool-output",
            kind: .toolOutput(callID: "call-1"),
            text: "large raw output that should stay hidden while collapsed",
            order: TranscriptSegmentOrder(index: 0),
            source: transcriptToolSource(lineNumber: 4),
            timestampDescription: nil,
            toolMetadata: TranscriptToolMetadata(
                displayLabel: "exec_command",
                status: "failed",
                bodyAvailability: .available,
                characterCount: 54,
                byteCount: 54,
                lineCount: 1
            )
        )
    )

    #expect(row.text == "Tool output from exec_command")
    #expect(row.toolPresentation == AppShellTranscriptToolPresentation(
        displayLabel: "exec_command",
        metadataSummary: "failed - 54 characters - 1 line",
        expandedText: "large raw output that should stay hidden while collapsed",
        isCollapsedByDefault: true
    ))
}

@Test("fixture tool activity rows are collapsed and preserve surrounding transcript order")
func fixtureToolActivityRowsAreCollapsedAndOrdered() throws {
    let state = try selectedToolTranscriptState(for: .toolActivityMixed, sessionID: "mixed-tools")

    #expect(state.rows.map(\.text) == [
        "Inspect the synthetic tool activity fixture.",
        "I will call a synthetic fixture tool.",
        "Tool call: synthetic_fixture_probe",
        "Tool output from synthetic_fixture_probe",
        "Tool call: synthetic_fixture_failure_probe",
        "Tool output from synthetic_fixture_failure_probe",
        "Tool call: unknown_tool",
        "Tool output from tool output",
        "Tool call: synthetic_structured_failure_probe",
        "Tool output from synthetic_structured_failure_probe",
    ])

    let firstToolOutput = try #require(state.rows.first { $0.text == "Tool output from synthetic_fixture_probe" })
    #expect(firstToolOutput.toolPresentation?.isCollapsedByDefault == true)
    #expect(firstToolOutput.toolPresentation?.metadataSummary == "status unknown - 21 characters - 1 line")
    #expect(firstToolOutput.toolPresentation?.expandedText == "synthetic tool output")
    #expect(firstToolOutput.text != firstToolOutput.toolPresentation?.expandedText)

    let failedToolOutput = try #require(state.rows.first { $0.text == "Tool output from synthetic_fixture_failure_probe" })
    #expect(failedToolOutput.toolPresentation?.metadataSummary == "failed - 24 characters - 1 line")
}

@Test("fixture large tool output stays out of collapsed row text")
func fixtureLargeToolOutputStaysOutOfCollapsedRowText() throws {
    let state = try selectedToolTranscriptState(for: .boundedReadTruncated, sessionID: "large-tool-output")
    let toolRow = try #require(state.rows.first)
    let presentation = try #require(toolRow.toolPresentation)

    #expect(toolRow.text == "Tool output from tool output")
    #expect(presentation.isCollapsedByDefault)
    #expect(presentation.metadataSummary.contains("characters"))
    #expect(presentation.expandedText.contains("synthetic bounded-read payload"))
    #expect(!toolRow.text.contains("synthetic bounded-read payload"))
}

@Test("tool rows without structured metadata expose explicit fallback")
func toolRowsWithoutStructuredMetadataExposeFallback() {
    let row = AppShellTranscriptSegmentRow.make(
        segment: TranscriptSegment(
            id: "tool-without-metadata",
            kind: .toolCall(name: "legacy_tool", callID: nil),
            text: "{}",
            order: TranscriptSegmentOrder(index: 0),
            source: transcriptToolSource(lineNumber: 9),
            timestampDescription: nil
        )
    )

    #expect(row.text == "Tool call: Unknown tool")
    #expect(row.toolPresentation?.metadataSummary == "metadata unavailable")
    #expect(row.toolPresentation?.expandedText == "{}")
}

private func selectedToolTranscriptState(
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
        session: toolTranscriptSession(id: sessionID, sourceID: sourceID),
        decodeResult: decodeResult
    )

    return AppShellSelectedTranscriptDetailState.loaded(readModel)
}

private func toolTranscriptSession(
    id: SessionID,
    sourceID: SessionSourceID
) -> SessionSummary {
    SessionSummary(
        id: id,
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(sourceID: sourceID.rawValue, displayName: "Codex fixture", profileName: nil),
        title: "Tool fixture",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck/tool.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}

private func transcriptToolSource(lineNumber: Int) -> TranscriptSegmentSourceReference {
    TranscriptSegmentSourceReference(
        sourceID: SessionSourceID(rawValue: "fixture"),
        relativePath: "selected-session.jsonl",
        lineNumber: lineNumber
    )
}
