import Foundation
import Testing
@testable import SessionDeckCore

@Test("Codex transcript decoder maps a minimal conversation into ordered user and assistant segments")
func codexTranscriptDecoderMapsMinimalConversationTurns() throws {
    let result = try decodeFixture(.minimalConversationTurns, sessionID: "minimal-session")

    #expect(result.title == "Minimal Conversation Turns")
    #expect(result.isPartial == false)
    #expect(result.diagnostics.isEmpty)
    #expect(result.orderedSegments.map(\.kind) == [.userMessage, .assistantMessage])
    #expect(result.orderedSegments.map(\.text) == [
        "Open the synthetic session.",
        "The synthetic session is open.",
    ])
    #expect(result.orderedSegments.map(\.timestampDescription) == [
        "2026-01-02T00:00:01Z",
        "2026-01-02T00:00:02Z",
    ])
    #expect(result.orderedSegments.map(\.source.lineNumber) == [2, 3])
    #expect(result.orderedSegments.map(\.metadata["role"]) == ["user", "assistant"])
}

@Test("Codex transcript decoder preserves multi-turn ordering and unsupported event visibility")
func codexTranscriptDecoderPreservesMultiTurnOrderingAndUnsupportedEvents() throws {
    let result = try decodeFixture(.multiTurnConversation, sessionID: "multi-turn-session")
    let orderedSegments = result.orderedSegments

    #expect(result.isPartial)
    #expect(result.diagnostics.map(\.code) == ["codex.unsupported_event"])
    #expect(orderedSegments.map(\.kind) == [
        .userMessage,
        .assistantMessage,
        .userMessage,
        .unknown(eventType: "future_codex_event"),
        .assistantMessage,
    ])
    #expect(orderedSegments.map(\.source.lineNumber) == [2, 3, 4, 5, 6])
    #expect(orderedSegments.map(\.order.index) == [0, 1, 2, 3, 4])
    #expect(orderedSegments[3].text == "Unsupported Codex event: future_codex_event")
    #expect(orderedSegments[3].metadata["event_type"] == "future_codex_event")
}

@Test("Codex transcript decoder converts malformed lines into recoverable diagnostics")
func codexTranscriptDecoderConvertsMalformedLinesIntoDiagnostics() throws {
    let result = try decodeFixture(.malformedLine, sessionID: "malformed-session")
    let orderedSegments = result.orderedSegments

    #expect(result.title == "Synthetic Malformed Line Session")
    #expect(result.isPartial)
    #expect(result.canContinueDecoding)
    #expect(result.diagnostics.map(\.code) == ["codex.malformed_jsonl"])
    #expect(orderedSegments.map(\.kind) == [
        .userMessage,
        .error(code: "codex.malformed_jsonl"),
        .assistantMessage,
    ])
    #expect(orderedSegments.map(\.source.lineNumber) == [2, 3, 4])
    #expect(orderedSegments[1].text == "Malformed Codex JSONL line.")
}

@Test("Codex transcript decoder records safe line diagnostics for malformed input")
func codexTranscriptDecoderRecordsSafeLineDiagnosticsForMalformedInput() throws {
    let result = try decodeFixture(.malformedLine, sessionID: "safe-malformed-session")
    let diagnostic = try #require(result.diagnostics.first)

    #expect(diagnostic.severity == .warning)
    #expect(diagnostic.source?.lineNumber == 3)
    #expect(diagnostic.allowsDecodingToContinue)
    #expect(diagnostic.message == "A Codex transcript line could not be decoded as JSON.")
    #expect(!diagnostic.message.contains("intentionally malformed"))
    #expect(!diagnostic.message.contains("{this line"))
}

@Test("Codex transcript decoder preserves unknown fixture events as ordered diagnostic segments")
func codexTranscriptDecoderPreservesUnknownFixtureEventsAsOrderedDiagnosticSegments() throws {
    let result = try decodeFixture(.unknownEvent, sessionID: "unknown-session")
    let orderedSegments = result.orderedSegments
    let diagnostic = try #require(result.diagnostics.first)

    #expect(result.title == "Synthetic Unknown Event Session")
    #expect(result.isPartial)
    #expect(result.canContinueDecoding)
    #expect(result.diagnostics.map(\.code) == ["codex.unsupported_event"])
    #expect(diagnostic.severity == .info)
    #expect(diagnostic.source?.lineNumber == 3)
    #expect(diagnostic.message == "A Codex transcript event is not mapped to a readable segment yet.")
    #expect(orderedSegments.map(\.kind) == [
        .userMessage,
        .unknown(eventType: "future_codex_event"),
        .assistantMessage,
    ])
    #expect(orderedSegments.map(\.source.lineNumber) == [2, 3, 4])
    #expect(orderedSegments.map(\.order.index) == [0, 1, 2])
    #expect(orderedSegments[1].metadata["event_type"] == "future_codex_event")
    #expect(!orderedSegments[1].text.contains("preserve-or-diagnose"))
}

@Test("Codex transcript decoder tolerates missing optional metadata and timestamps")
func codexTranscriptDecoderToleratesMissingOptionalMetadataAndTimestamps() throws {
    let result = try decodeFixture(.missingMetadata, sessionID: "missing-metadata-session")

    #expect(result.title == "Synthetic Missing Metadata Session")
    #expect(result.isPartial == false)
    #expect(result.diagnostics.isEmpty)
    #expect(result.orderedSegments.map(\.timestampDescription) == [
        "2026-01-01T00:03:01Z",
        nil,
    ])
}

@Test("Codex transcript decoder maps tool call events into distinct segments")
func codexTranscriptDecoderMapsToolCallEventsIntoDistinctSegments() throws {
    let result = try decodeFixture(.projectSession, sessionID: "project-tool-call-session")
    let orderedSegments = result.orderedSegments

    #expect(orderedSegments.count == 4)
    #expect(orderedSegments[2].kind == .toolCall(name: "synthetic_fixture_probe", callID: "call_synthetic_001"))
    #expect(orderedSegments[2].role == .tool)
    #expect(orderedSegments[2].text == "{\"target\":\"fixture\"}")
    #expect(orderedSegments[2].timestampDescription == "2026-01-01T00:00:03Z")
    #expect(orderedSegments[2].source.lineNumber == 4)
    #expect(orderedSegments[2].metadata["event_type"] == "response_item")
    #expect(orderedSegments[2].metadata["payload_type"] == "function_call")
    #expect(orderedSegments[2].metadata["tool_name"] == "synthetic_fixture_probe")
    #expect(orderedSegments[2].metadata["call_id"] == "call_synthetic_001")
}

@Test("Codex transcript decoder maps tool outputs and failures into distinct segments")
func codexTranscriptDecoderMapsToolOutputsAndFailuresIntoDistinctSegments() throws {
    let result = try decodeFixture(.toolActivityMixed, sessionID: "tool-output-session")
    let orderedSegments = result.orderedSegments

    #expect(orderedSegments.map(\.kind) == [
        .userMessage,
        .assistantMessage,
        .toolCall(name: "synthetic_fixture_probe", callID: "call_tool_activity_001"),
        .toolOutput(callID: "call_tool_activity_001"),
        .toolCall(name: "synthetic_fixture_failure_probe", callID: "call_tool_activity_002"),
        .toolOutput(callID: "call_tool_activity_002"),
        .toolCall(name: "unknown_tool", callID: nil),
        .toolOutput(callID: nil),
        .toolCall(name: "synthetic_structured_failure_probe", callID: "call_tool_activity_003"),
        .toolOutput(callID: "call_tool_activity_003"),
    ])
    #expect(orderedSegments[3].text == "synthetic tool output")
    #expect(orderedSegments[3].metadata["payload_type"] == "function_call_output")
    #expect(orderedSegments[3].metadata["call_id"] == "call_tool_activity_001")
    #expect(orderedSegments[5].text == "synthetic failure output")
    #expect(orderedSegments[5].metadata["status"] == "failed")
    #expect(orderedSegments[7].text == "synthetic missing call id failure")
    #expect(orderedSegments[7].metadata["status"] == "failed")
    #expect(orderedSegments[7].metadata["call_id"] == nil)
    #expect(orderedSegments[9].text == "synthetic_error: synthetic structured failure")
    #expect(orderedSegments[9].metadata["call_id"] == "call_tool_activity_003")
}

@Test("Codex transcript decoder attaches structured metadata to tool segments")
func codexTranscriptDecoderAttachesStructuredMetadataToToolSegments() throws {
    let result = try decodeFixture(.toolActivityMixed, sessionID: "tool-metadata-session")
    let orderedSegments = result.orderedSegments
    let toolCallMetadata = try #require(orderedSegments[2].toolMetadata)
    let toolOutputMetadata = try #require(orderedSegments[3].toolMetadata)
    let failedOutputMetadata = try #require(orderedSegments[5].toolMetadata)

    #expect(toolCallMetadata.displayLabel == "synthetic_fixture_probe")
    #expect(toolCallMetadata.status == nil)
    #expect(toolCallMetadata.bodyAvailability == .available)
    #expect(toolCallMetadata.characterCount == 26)
    #expect(toolCallMetadata.byteCount == 26)
    #expect(toolCallMetadata.lineCount == 1)

    #expect(toolOutputMetadata.displayLabel == "tool output")
    #expect(toolOutputMetadata.status == nil)
    #expect(toolOutputMetadata.bodyAvailability == .available)
    #expect(toolOutputMetadata.characterCount == 21)
    #expect(toolOutputMetadata.byteCount == 21)
    #expect(toolOutputMetadata.lineCount == 1)

    #expect(failedOutputMetadata.status == "failed")
    #expect(failedOutputMetadata.bodyAvailability == .available)
    #expect(failedOutputMetadata.characterCount == 24)
    #expect(failedOutputMetadata.byteCount == 24)
    #expect(failedOutputMetadata.lineCount == 1)
}

@Test("Codex transcript decoder preserves mixed tool ordering and source metadata")
func codexTranscriptDecoderPreservesMixedToolOrderingAndSourceMetadata() throws {
    let result = try decodeFixture(.toolActivityMixed, sessionID: "mixed-tool-ordering-session")
    let orderedSegments = result.orderedSegments

    #expect(result.isPartial == false)
    #expect(result.diagnostics.isEmpty)
    #expect(orderedSegments.map(\.order.index) == Array(0..<10))
    #expect(orderedSegments.map(\.source.lineNumber) == Array(2...11))
    #expect(orderedSegments.compactMap { $0.metadata["call_id"] } == [
        "call_tool_activity_001",
        "call_tool_activity_001",
        "call_tool_activity_002",
        "call_tool_activity_002",
        "call_tool_activity_003",
        "call_tool_activity_003",
    ])
}

@Test("Codex transcript decoder uses path-guarded synthetic fixtures for degraded cases")
func codexTranscriptDecoderUsesPathGuardedSyntheticFixturesForDegradedCases() throws {
    for fixtureID in [CodexTranscriptFixtureID.malformedLine, .unknownEvent, .missingMetadata] {
        let url = try CodexTranscriptFixtureManifest.fixtureURL(for: fixtureID)

        #expect(url.path.contains("CodexTranscripts"))
        #expect(!url.path.contains("/.codex"))
        #expect(!url.path.contains("/.hermes"))
        _ = try decodeFixture(fixtureID, sessionID: "guarded-\(fixtureID.rawValue)")
    }
}

private func decodeFixture(
    _ fixtureID: CodexTranscriptFixtureID,
    sessionID rawSessionID: String
) throws -> TranscriptDecodeResult {
    let sessionID = SessionID(rawValue: rawSessionID)
    let source = TranscriptSegmentSourceReference(
        sourceID: SessionSourceID(rawValue: "codex-fixture"),
        relativePath: try CodexTranscriptFixtureManifest.fixture(for: fixtureID).filename,
        lineNumber: nil
    )
    let file = CodexTranscriptFile(
        sessionID: sessionID,
        fileURL: try CodexTranscriptFixtureManifest.fixtureURL(for: fixtureID),
        source: source,
        fallbackTitle: "Fallback title"
    )
    let decoder = CodexTranscriptDecodingAdapter(files: [file])

    return try decoder.loadTranscript(sessionID: sessionID)
}
