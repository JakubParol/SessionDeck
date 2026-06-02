public struct PlaceholderTranscriptLoadingAdapter: TranscriptLoadingPort, Sendable {
    public init() {}

    public func loadTranscriptPreview(sessionID: SessionID) throws -> TranscriptPreview {
        throw PlaceholderTranscriptLoadingError.previewUnavailable(sessionID)
    }
}

public enum PlaceholderTranscriptLoadingError: Error, Equatable, Sendable {
    case previewUnavailable(SessionID)
}
