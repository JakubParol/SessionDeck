public struct SessionID: Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct SessionSummary: Equatable, Sendable {
    public let id: SessionID
    public let sourceID: SessionSourceID
    public let title: String
    public let projectDisplayName: String?
    public let lastActivityDescription: String?
    public let previewText: String?

    public init(
        id: SessionID,
        sourceID: SessionSourceID,
        title: String,
        projectDisplayName: String?,
        lastActivityDescription: String?,
        previewText: String?
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.projectDisplayName = projectDisplayName
        self.lastActivityDescription = lastActivityDescription
        self.previewText = previewText
    }
}
