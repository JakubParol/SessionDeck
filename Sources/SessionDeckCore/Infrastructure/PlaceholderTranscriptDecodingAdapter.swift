public struct PlaceholderTranscriptDecodingAdapter: TranscriptDecodingPort, Sendable {
    public init() {}

    public func loadTranscript(sessionID: SessionID) throws -> TranscriptDecodeResult {
        throw PlaceholderTranscriptDecodingError.transcriptUnavailable(sessionID)
    }
}

public enum PlaceholderTranscriptDecodingError: Error, Equatable, Sendable {
    case transcriptUnavailable(SessionID)
}
