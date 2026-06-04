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
