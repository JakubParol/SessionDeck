public enum LiveSourceChangeKind: Equatable, Sendable {
    case created
    case modified
    case deleted
    case moved
    case unknown
}

public enum LiveRefreshIdentity: Equatable, Hashable, Sendable {
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

public struct LiveSourceWatchTarget: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let path: String
    public let sessionID: SessionID?

    public init(sourceID: SessionSourceID, path: String, sessionID: SessionID? = nil) {
        self.sourceID = sourceID
        self.path = path
        self.sessionID = sessionID
    }
}

public enum LiveSourceObservationEvent: Equatable, Sendable {
    case change(LiveSourceChangeEvent)
    case degraded(LiveSourceWatcherDegradedState)
}

public protocol LiveSourceObservation: AnyObject, Sendable {
    func cancel()
}

public protocol LiveSourceChangeObservationPort: AnyObject, Sendable {
    func observe(
        targets: [LiveSourceWatchTarget],
        eventHandler: @escaping (LiveSourceObservationEvent) -> Void
    ) -> any LiveSourceObservation
}

public enum LiveRefreshScope: Equatable, Sendable {
    case allSources
    case source(SessionSourceID)
    case session(SessionID, sourceID: SessionSourceID)
    case path(String, sourceID: SessionSourceID?)
}

public enum LiveRefreshTrigger: Equatable, Sendable {
    case sourceChange
    case debouncedSourceChange
    case watcherDegraded
    case manualRefresh
    case appStartup
    case reconciliation
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

public enum LiveMonitoringFailureReason: Equatable, Sendable {
    case watcherSetupFailed
    case sourceMissing
    case permissionDenied
    case reconciliationFailed

    public var code: String {
        switch self {
        case .watcherSetupFailed:
            return "live_monitoring.watcher_setup_failed"
        case .sourceMissing:
            return "live_monitoring.source_missing"
        case .permissionDenied:
            return "live_monitoring.permission_denied"
        case .reconciliationFailed:
            return "live_monitoring.reconciliation_failed"
        }
    }
}

public struct LiveMonitoringFailure: Equatable, Sendable {
    public let sourceID: SessionSourceID?
    public let reason: LiveMonitoringFailureReason
    public let message: String

    public init(sourceID: SessionSourceID?, reason: LiveMonitoringFailureReason, message: String) {
        self.sourceID = sourceID
        self.reason = reason
        self.message = message
    }
}

public enum LiveMonitoringStaleReason: Equatable, Sendable {
    case missedChangeRecovered
    case sourceSnapshotMissing
}

public enum LiveMonitoringState: Equatable, Sendable {
    case current(sourceID: SessionSourceID?)
    case watching(sourceID: SessionSourceID?)
    case refreshPending(LiveRefreshRequest)
    case refreshRunning(LiveRefreshRequest)
    case reconciling(sourceID: SessionSourceID?, trigger: LiveRefreshTrigger)
    case stale(sourceID: SessionSourceID?, reason: LiveMonitoringStaleReason)
    case degraded(LiveMonitoringFailure)
    case stopped
}
