extension AppShellMonitoringHealthSummary {
    static func sourceSuffix(_ sourceID: SessionSourceID?) -> String {
        sourceID.map { " for \($0.rawValue)" } ?? " for all sources"
    }

    static func triggerLabel(_ trigger: LiveRefreshTrigger) -> String {
        switch trigger {
        case .sourceChange:
            return "a filesystem event"
        case .debouncedSourceChange:
            return "coalesced filesystem events"
        case .watcherDegraded:
            return "watcher diagnostics"
        case .manualRefresh:
            return "manual refresh"
        case .appStartup:
            return "app startup"
        case .reconciliation:
            return "reconciliation"
        }
    }

    static func staleDetail(
        _ reason: LiveMonitoringStaleReason,
        sourceID: SessionSourceID?
    ) -> String {
        switch reason {
        case .missedChangeRecovered:
            return "Reconciliation found changes missed by file watching\(sourceSuffix(sourceID))."
        case .sourceSnapshotMissing:
            return "Reconciliation needs a fresh source snapshot\(sourceSuffix(sourceID))."
        }
    }

    static func degradedTitle(for reason: LiveMonitoringFailureReason) -> String {
        switch reason {
        case .watcherSetupFailed:
            return "Watcher unavailable"
        case .sourceMissing:
            return "Watched source missing"
        case .permissionDenied:
            return "Watcher permission denied"
        case .reconciliationFailed:
            return "Reconciliation failed"
        }
    }

    static func degradedSeverity(for reason: LiveMonitoringFailureReason) -> AppShellMonitoringHealthSeverity {
        switch reason {
        case .watcherSetupFailed, .sourceMissing, .permissionDenied:
            return .warning
        case .reconciliationFailed:
            return .error
        }
    }
}

extension AppShellMonitoringHealthSummary {
    static func sourceID(for scope: LiveRefreshScope) -> SessionSourceID? {
        switch scope {
        case .allSources:
            return nil
        case let .source(sourceID):
            return sourceID
        case let .session(_, sourceID):
            return sourceID
        case let .path(_, sourceID):
            return sourceID
        }
    }
}
