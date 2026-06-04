public struct LoadTranscriptSegmentsUseCase: Sendable {
    private let transcriptDecoding: any TranscriptDecodingPort

    public init(transcriptDecoding: any TranscriptDecodingPort) {
        self.transcriptDecoding = transcriptDecoding
    }

    public func loadTranscript(sessionID: SessionID) throws -> TranscriptDecodeResult {
        try transcriptDecoding.loadTranscript(sessionID: sessionID)
    }
}
