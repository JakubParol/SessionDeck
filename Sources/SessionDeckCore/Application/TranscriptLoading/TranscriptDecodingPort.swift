public protocol TranscriptDecodingPort: Sendable {
    func loadTranscript(sessionID: SessionID) throws -> TranscriptDecodeResult
}
