public struct SessionID: Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct SessionSummary: Equatable, Sendable {
    public let id: SessionID
    public let identity: CatalogSessionIdentity
    public let sourceID: SessionSourceID
    public let sourceLabel: CatalogSourceLabel
    public let title: String?
    public let previewText: String?
    public let fallbackTitle: String
    public let projectHint: CatalogProjectHint
    public let sessionPath: String
    public let activity: CatalogActivityTimestamps
    public let fileSize: CatalogFileSize
    public let metadata: CatalogSessionMetadata
    public let fallbackReasons: [CatalogSessionFallbackReason]
    public let health: CatalogEntryHealth

    public init(
        id: SessionID,
        identity: CatalogSessionIdentity? = nil,
        sourceID: SessionSourceID,
        sourceLabel: CatalogSourceLabel,
        title: String?,
        previewText: String? = nil,
        fallbackTitle: String? = nil,
        projectHint: CatalogProjectHint,
        sessionPath: String,
        activity: CatalogActivityTimestamps,
        fileSize: CatalogFileSize,
        metadata: CatalogSessionMetadata = CatalogSessionMetadata(modelName: nil, agentProfileName: nil),
        fallbackReasons: [CatalogSessionFallbackReason] = [],
        health: CatalogEntryHealth
    ) {
        self.id = id
        self.identity = identity ?? CatalogSessionIdentity(rawValue: id.rawValue)
        self.sourceID = sourceID
        self.sourceLabel = sourceLabel
        self.title = title
        self.previewText = previewText
        self.fallbackTitle = fallbackTitle ?? "Session \(id.rawValue)"
        self.projectHint = projectHint
        self.sessionPath = sessionPath
        self.activity = activity
        self.fileSize = fileSize
        self.metadata = metadata
        self.fallbackReasons = fallbackReasons
        self.health = health
    }

    public var displayTitle: String {
        guard let title, title.isEmpty == false else {
            return fallbackTitle
        }

        return title
    }

    public var projectDisplayName: String {
        projectHint.displayName
    }

    public var lastActivityDescription: String {
        guard let sortKey = lastActivitySortKey else {
            return "Unknown activity"
        }

        return "\(sortKey)"
    }

    public var lastActivitySortKey: Int64? {
        activity.lastActivityEpochSeconds ?? activity.createdAtEpochSeconds
    }
}

public enum SessionCatalogOrdering {
    public static func sort(_ sessions: [SessionSummary]) -> [SessionSummary] {
        sessions.sorted { lhs, rhs in
            switch (lhs.lastActivitySortKey, rhs.lastActivitySortKey) {
            case let (lhsTimestamp?, rhsTimestamp?) where lhsTimestamp != rhsTimestamp:
                return lhsTimestamp > rhsTimestamp
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                if lhs.displayTitle != rhs.displayTitle {
                    return lhs.displayTitle < rhs.displayTitle
                }

                return lhs.id.rawValue < rhs.id.rawValue
            }
        }
    }
}
