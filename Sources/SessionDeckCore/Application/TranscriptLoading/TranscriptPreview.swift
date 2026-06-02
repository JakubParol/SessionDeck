public enum TranscriptSegmentRole: Equatable, Sendable {
    case user
    case assistant
    case tool
    case diagnostic
    case unknown(String)
}

public struct TranscriptSegment: Equatable, Sendable {
    public let id: String
    public let role: TranscriptSegmentRole
    public let text: String
    public let timestampDescription: String?

    public init(
        id: String,
        role: TranscriptSegmentRole,
        text: String,
        timestampDescription: String?
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestampDescription = timestampDescription
    }
}

public struct TranscriptPreview: Equatable, Sendable {
    public let sessionID: SessionID
    public let title: String
    public let segments: [TranscriptSegment]
    public let isTruncated: Bool

    public init(
        sessionID: SessionID,
        title: String,
        segments: [TranscriptSegment],
        isTruncated: Bool
    ) {
        self.sessionID = sessionID
        self.title = title
        self.segments = segments
        self.isTruncated = isTruncated
    }
}
