public struct LoadTranscriptPreviewUseCase: Sendable {
    private let transcriptLoading: any TranscriptLoadingPort

    public init(transcriptLoading: any TranscriptLoadingPort) {
        self.transcriptLoading = transcriptLoading
    }

    public func loadPreview(sessionID: SessionID) throws -> TranscriptPreview {
        try transcriptLoading.loadTranscriptPreview(sessionID: sessionID)
    }
}
