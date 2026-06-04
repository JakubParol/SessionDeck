import Testing
@testable import SessionDeckCore

@Test("transcript segments represent conversation tool diagnostic unknown and metadata events")
func transcriptSegmentsRepresentSupportedEventKinds() throws {
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let source = TranscriptSegmentSourceReference(
        sourceID: sourceID,
        relativePath: "2026/06/04/rollout.jsonl",
        lineNumber: 12
    )

    let segments = [
        TranscriptSegment(
            id: "segment-1",
            kind: .userMessage,
            text: "Open the app",
            order: TranscriptSegmentOrder(index: 0),
            source: source,
            timestampDescription: "2026-06-04T10:00:00Z",
            metadata: ["profile": "naomi"]
        ),
        TranscriptSegment(
            id: "segment-2",
            kind: .assistantMessage,
            text: "I will inspect it.",
            order: TranscriptSegmentOrder(index: 1),
            source: source.withLineNumber(13),
            timestampDescription: "2026-06-04T10:00:01Z"
        ),
        TranscriptSegment(
            id: "segment-3",
            kind: .toolCall(name: "exec_command", callID: "call-1"),
            text: "swift test",
            order: TranscriptSegmentOrder(index: 2),
            source: source.withLineNumber(14),
            timestampDescription: nil
        ),
        TranscriptSegment(
            id: "segment-4",
            kind: .toolOutput(callID: "call-1"),
            text: "Test Suite passed",
            order: TranscriptSegmentOrder(index: 3),
            source: source.withLineNumber(15),
            timestampDescription: nil
        ),
        TranscriptSegment(
            id: "segment-5",
            kind: .error(code: "malformed_json"),
            text: "Line could not be decoded.",
            order: TranscriptSegmentOrder(index: 4),
            source: source.withLineNumber(16),
            timestampDescription: nil
        ),
        TranscriptSegment(
            id: "segment-6",
            kind: .unknown(eventType: "future_event"),
            text: "Unsupported event preserved for diagnostics.",
            order: TranscriptSegmentOrder(index: 5),
            source: source.withLineNumber(17),
            timestampDescription: nil
        ),
        TranscriptSegment(
            id: "segment-7",
            kind: .metadata(name: "session_summary"),
            text: "Model: gpt-test",
            order: TranscriptSegmentOrder(index: 6),
            source: source.withLineNumber(18),
            timestampDescription: nil,
            metadata: ["model": "gpt-test"]
        ),
    ]

    #expect(segments.map(\.kind) == [
        .userMessage,
        .assistantMessage,
        .toolCall(name: "exec_command", callID: "call-1"),
        .toolOutput(callID: "call-1"),
        .error(code: "malformed_json"),
        .unknown(eventType: "future_event"),
        .metadata(name: "session_summary"),
    ])
    #expect(segments.map(\.role) == [.user, .assistant, .tool, .tool, .diagnostic, .unknown("future_event"), .diagnostic])
    #expect(segments.map(\.source.lineNumber) == [12, 13, 14, 15, 16, 17, 18])
    #expect(segments.first?.metadata == ["profile": "naomi"])
    #expect(segments.last?.metadata == ["model": "gpt-test"])
}

@Test("transcript segment order provides deterministic sorting separate from source line numbers")
func transcriptSegmentOrderProvidesDeterministicSorting() throws {
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let source = TranscriptSegmentSourceReference(
        sourceID: sourceID,
        relativePath: "2026/06/04/rollout.jsonl",
        lineNumber: nil
    )
    let outOfOrderSegments = [
        TranscriptSegment(
            id: "segment-3",
            kind: .toolOutput(callID: "call-1"),
            text: "done",
            order: TranscriptSegmentOrder(index: 2),
            source: source.withLineNumber(99),
            timestampDescription: nil
        ),
        TranscriptSegment(
            id: "segment-1",
            kind: .userMessage,
            text: "run command",
            order: TranscriptSegmentOrder(index: 0),
            source: source.withLineNumber(nil),
            timestampDescription: nil
        ),
        TranscriptSegment(
            id: "segment-2",
            kind: .toolCall(name: "exec_command", callID: "call-1"),
            text: "date",
            order: TranscriptSegmentOrder(index: 1),
            source: source.withLineNumber(10),
            timestampDescription: nil
        ),
    ]

    let sorted = outOfOrderSegments.sorted { $0.order < $1.order }

    #expect(sorted.map(\.id) == ["segment-1", "segment-2", "segment-3"])
    #expect(sorted.map(\.source.lineNumber) == [nil, 10, 99])
}

@Test("transcript decode result preserves ordered segments diagnostics and preview projection")
func transcriptDecodeResultPreservesSegmentsDiagnosticsAndPreviewProjection() throws {
    let sessionID = SessionID(rawValue: "session-1")
    let source = TranscriptSegmentSourceReference(
        sourceID: SessionSourceID(rawValue: "codex-fixture"),
        relativePath: "2026/06/04/rollout.jsonl",
        lineNumber: 8
    )
    let segments = [
        TranscriptSegment(
            id: "segment-2",
            kind: .assistantMessage,
            text: "Done.",
            order: TranscriptSegmentOrder(index: 1),
            source: source.withLineNumber(9),
            timestampDescription: nil
        ),
        TranscriptSegment(
            id: "segment-1",
            kind: .userMessage,
            text: "Summarize this session.",
            order: TranscriptSegmentOrder(index: 0),
            source: source,
            timestampDescription: nil
        ),
    ]
    let diagnostics = [
        TranscriptDecodeDiagnostic(
            code: "unknown_event",
            severity: .warning,
            message: "Preserved unknown event as diagnostic segment.",
            source: source.withLineNumber(10),
            allowsDecodingToContinue: true
        ),
        TranscriptDecodeDiagnostic(
            code: "truncated_large_output",
            severity: .info,
            message: "Large tool output was truncated for preview.",
            source: source.withLineNumber(11),
            allowsDecodingToContinue: true
        ),
    ]

    let result = TranscriptDecodeResult(
        sessionID: sessionID,
        title: "Fixture session",
        segments: segments,
        diagnostics: diagnostics,
        isPartial: true
    )

    #expect(result.orderedSegments.map(\.id) == ["segment-1", "segment-2"])
    #expect(result.diagnostics.map(\.code) == ["unknown_event", "truncated_large_output"])
    #expect(result.diagnostics.map(\.severity) == [.warning, .info])
    #expect(result.canContinueDecoding)

    let preview = result.preview(isTruncated: true)

    #expect(preview.sessionID == sessionID)
    #expect(preview.title == "Fixture session")
    #expect(preview.segments.map(\.id) == ["segment-1", "segment-2"])
    #expect(preview.isTruncated)
}
