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
