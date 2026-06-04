public protocol SelectedTranscriptLoadingPort: Sendable {
    func loadSelectedTranscript(for session: SessionSummary) throws -> TranscriptDecodeResult
}

public enum SelectedTranscriptLoadingError: Error, Equatable, Sendable {
    case transcriptMissing(SessionID)
    case transcriptUnreadable(SessionID)
    case transcriptUnavailable(SessionID)
}

public struct SelectedTranscriptReadModel: Equatable, Sendable {
    public let sessionID: SessionID
    public let title: String
    public let sourceID: SessionSourceID
    public let sourceLabel: CatalogSourceLabel
    public let projectHint: CatalogProjectHint
    public let sessionPath: String
    public let activity: CatalogActivityTimestamps
    public let segments: [TranscriptSegment]
    public let diagnostics: [TranscriptDecodeDiagnostic]
    public let isPartial: Bool
    public let metadata: CatalogSessionMetadata

    public init(session: SessionSummary, decodeResult: TranscriptDecodeResult) {
        self.sessionID = session.id
        self.title = decodeResult.title
        self.sourceID = session.sourceID
        self.sourceLabel = session.sourceLabel
        self.projectHint = session.projectHint
        self.sessionPath = session.sessionPath
        self.activity = session.activity
        self.segments = decodeResult.orderedSegments
        self.diagnostics = decodeResult.diagnostics
        self.isPartial = decodeResult.isPartial
        self.metadata = session.metadata
    }
}

public struct LoadSelectedTranscriptUseCase: Sendable {
    private let selectedTranscriptLoading: any SelectedTranscriptLoadingPort

    public init(selectedTranscriptLoading: any SelectedTranscriptLoadingPort) {
        self.selectedTranscriptLoading = selectedTranscriptLoading
    }

    public func loadTranscript(for session: SessionSummary) throws -> SelectedTranscriptReadModel {
        let result = try selectedTranscriptLoading.loadSelectedTranscript(for: session)
        return SelectedTranscriptReadModel(session: session, decodeResult: result)
    }
}
