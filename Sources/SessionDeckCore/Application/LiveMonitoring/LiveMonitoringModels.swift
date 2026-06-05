public enum LiveSourceChangeKind: Equatable, Sendable {
    case created
    case modified
    case deleted
    case moved
    case unknown
}

public enum LiveRefreshIdentity: Equatable, Sendable {
    case source(SessionSourceID)
    case session(SessionID, sourceID: SessionSourceID)
    case path(String, sourceID: SessionSourceID?)
    case unidentified
}

public struct LiveSourceChangeEvent: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let affectedPath: String
    public let sessionID: SessionID?
    public let kind: LiveSourceChangeKind

    public init(
        sourceID: SessionSourceID,
        affectedPath: String,
        sessionID: SessionID? = nil,
        kind: LiveSourceChangeKind
    ) {
        self.sourceID = sourceID
        self.affectedPath = affectedPath
        self.sessionID = sessionID
        self.kind = kind
    }

    public var identity: LiveRefreshIdentity {
        guard let sessionID else {
            return .path(affectedPath, sourceID: sourceID)
        }

        return .session(sessionID, sourceID: sourceID)
    }
}

public enum LiveSourceWatcherDegradedReason: Equatable, Sendable {
    case missingPath
    case deletedPath
    case permissionDenied
    case unsupportedEvent
    case unavailable

    public var code: String {
        switch self {
        case .missingPath:
            return "live_monitoring.missing_path"
        case .deletedPath:
            return "live_monitoring.deleted_path"
        case .permissionDenied:
            return "live_monitoring.permission_denied"
        case .unsupportedEvent:
            return "live_monitoring.unsupported_event"
        case .unavailable:
            return "live_monitoring.unavailable"
        }
    }
}

public struct LiveSourceWatcherDegradedState: Equatable, Sendable {
    public let sourceID: SessionSourceID?
    public let path: String
    public let reason: LiveSourceWatcherDegradedReason

    public init(sourceID: SessionSourceID?, path: String, reason: LiveSourceWatcherDegradedReason) {
        self.sourceID = sourceID
        self.path = path
        self.reason = reason
    }
}

public enum LiveRefreshScope: Equatable, Sendable {
    case allSources
    case source(SessionSourceID)
    case session(SessionID, sourceID: SessionSourceID)
    case path(String, sourceID: SessionSourceID?)
}

public enum LiveRefreshTrigger: Equatable, Sendable {
    case sourceChange
    case watcherDegraded
    case manualRefresh
}

public struct LiveRefreshRequest: Equatable, Sendable {
    public let scope: LiveRefreshScope
    public let trigger: LiveRefreshTrigger
    public let eventCount: Int

    public init(scope: LiveRefreshScope, trigger: LiveRefreshTrigger, eventCount: Int) {
        self.scope = scope
        self.trigger = trigger
        self.eventCount = eventCount
    }
}
