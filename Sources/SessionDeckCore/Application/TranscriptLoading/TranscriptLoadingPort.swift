public protocol TranscriptLoadingPort: Sendable {
    func loadTranscriptPreview(sessionID: SessionID) throws -> TranscriptPreview
}
