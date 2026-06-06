public enum AppShellMonitoringHealthSeverity: Equatable, Sendable {
    case healthy
    case info
    case warning
    case error
}

public struct AppShellMonitoringHealthRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let severity: AppShellMonitoringHealthSeverity
    public let diagnosticCode: String?
    public let sourceID: SessionSourceID?

    public init(
        id: String,
        title: String,
        detail: String,
        severity: AppShellMonitoringHealthSeverity,
        diagnosticCode: String?,
        sourceID: SessionSourceID?
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
        self.diagnosticCode = diagnosticCode
        self.sourceID = sourceID
    }
}

public struct AppShellMonitoringHealthSummary: Equatable, Sendable {
    public static let notStarted = AppShellMonitoringHealthSummary(
        statusMessage: "Live monitoring has not started.",
        severity: .info,
        rows: [
            AppShellMonitoringHealthRow(
                id: "live-monitoring.not-started",
                title: "Monitoring not started",
                detail: "Watcher and reconciliation health will appear after live monitoring starts.",
                severity: .info,
                diagnosticCode: nil,
                sourceID: nil
            ),
        ]
    )

    public let statusMessage: String
    public let severity: AppShellMonitoringHealthSeverity
    public let rows: [AppShellMonitoringHealthRow]

    public init(
        statusMessage: String,
        severity: AppShellMonitoringHealthSeverity,
        rows: [AppShellMonitoringHealthRow]
    ) {
        self.statusMessage = statusMessage
        self.severity = severity
        self.rows = rows
    }

    public static func make(states: [LiveMonitoringState]) -> AppShellMonitoringHealthSummary {
        guard states.isEmpty == false else {
            return .notStarted
        }

        let rows = rows(from: states)
        let severity = highestSeverity(in: rows)

        return AppShellMonitoringHealthSummary(
            statusMessage: statusMessage(for: severity, rows: rows),
            severity: severity,
            rows: rows
        )
    }

    private static func rows(from states: [LiveMonitoringState]) -> [AppShellMonitoringHealthRow] {
        let latestStates = latestStateByBucket(states)
        let rows = latestStates.values
            .sorted { $0.key < $1.key }
            .map(row)

        if rows.isEmpty {
            return [
                AppShellMonitoringHealthRow(
                    id: "live-monitoring.healthy",
                    title: "Live monitoring healthy",
                    detail: "Configured sources are being watched and reconciliation is available.",
                    severity: .healthy,
                    diagnosticCode: nil,
                    sourceID: nil
                ),
            ]
        }

        return rows
    }

    private static func latestStateByBucket(
        _ states: [LiveMonitoringState]
    ) -> [MonitoringBucket: MonitoringBucketedState] {
        var latestStates: [MonitoringBucket: MonitoringBucketedState] = [:]
        for state in states {
            guard let bucketedState = MonitoringBucketedState(state: state) else {
                continue
            }
            latestStates[bucketedState.bucket] = bucketedState
        }
        return latestStates
    }

    private static func row(for bucketedState: MonitoringBucketedState) -> AppShellMonitoringHealthRow {
        switch bucketedState.state {
        case let .watching(sourceID), let .current(sourceID):
            return AppShellMonitoringHealthRow(
                id: bucketedState.key,
                title: "Watcher healthy",
                detail: "Source updates are being watched\(sourceSuffix(sourceID)).",
                severity: .healthy,
                diagnosticCode: nil,
                sourceID: sourceID
            )
        case let .refreshPending(request):
            return AppShellMonitoringHealthRow(
                id: bucketedState.key,
                title: "Refresh pending",
                detail: "A live update is queued from \(triggerLabel(request.trigger)).",
                severity: .info,
                diagnosticCode: nil,
                sourceID: AppShellMonitoringHealthSummary.sourceID(for: request.scope)
            )
        case let .refreshRunning(request):
            return AppShellMonitoringHealthRow(
                id: bucketedState.key,
                title: "Refresh running",
                detail: "A live update is loading changes from \(triggerLabel(request.trigger)).",
                severity: .info,
                diagnosticCode: nil,
                sourceID: AppShellMonitoringHealthSummary.sourceID(for: request.scope)
            )
        case let .reconciling(sourceID, _):
            return AppShellMonitoringHealthRow(
                id: bucketedState.key,
                title: "Reconciliation running",
                detail: "SessionDeck is checking for missed filesystem events\(sourceSuffix(sourceID)).",
                severity: .info,
                diagnosticCode: nil,
                sourceID: sourceID
            )
        case let .stale(sourceID, reason):
            return AppShellMonitoringHealthRow(
                id: bucketedState.key,
                title: "Reconciliation fallback active",
                detail: staleDetail(reason, sourceID: sourceID),
                severity: .warning,
                diagnosticCode: reason.code,
                sourceID: sourceID
            )
        case let .degraded(failure):
            return AppShellMonitoringHealthRow(
                id: bucketedState.key,
                title: degradedTitle(for: failure.reason),
                detail: failure.message,
                severity: degradedSeverity(for: failure.reason),
                diagnosticCode: failure.reason.code,
                sourceID: failure.sourceID
            )
        case .stopped:
            return AppShellMonitoringHealthRow(
                id: bucketedState.key,
                title: "Monitoring stopped",
                detail: "Live monitoring is stopped; manual refresh still keeps browsing available.",
                severity: .warning,
                diagnosticCode: nil,
                sourceID: nil
            )
        }
    }

    private static func highestSeverity(
        in rows: [AppShellMonitoringHealthRow]
    ) -> AppShellMonitoringHealthSeverity {
        if rows.contains(where: { $0.severity == .error }) {
            return .error
        }
        if rows.contains(where: { $0.severity == .warning }) {
            return .warning
        }
        if rows.contains(where: { $0.severity == .info }) {
            return .info
        }
        return .healthy
    }

    private static func statusMessage(
        for severity: AppShellMonitoringHealthSeverity,
        rows: [AppShellMonitoringHealthRow]
    ) -> String {
        switch severity {
        case .healthy:
            return "Live monitoring is healthy."
        case .info:
            return "Live monitoring is active."
        case .warning:
            return "Live monitoring is using fallback diagnostics."
        case .error:
            let count = rows.filter { $0.severity == .error }.count
            return "Live monitoring has \(count == 1 ? "1 blocking diagnostic" : "\(count) blocking diagnostics")."
        }
    }
}

private struct MonitoringBucket: Hashable {
    let kind: String
    let sourceID: SessionSourceID?
}

private struct MonitoringBucketedState {
    let bucket: MonitoringBucket
    let key: String
    let state: LiveMonitoringState

    init?(state: LiveMonitoringState) {
        self.state = state
        switch state {
        case let .watching(sourceID), let .current(sourceID):
            self.bucket = MonitoringBucket(kind: "watcher", sourceID: sourceID)
        case let .refreshPending(request), let .refreshRunning(request):
            self.bucket = MonitoringBucket(
                kind: "refresh",
                sourceID: AppShellMonitoringHealthSummary.sourceID(for: request.scope)
            )
        case let .reconciling(sourceID, _), let .stale(sourceID, _):
            self.bucket = MonitoringBucket(kind: "reconciliation", sourceID: sourceID)
        case let .degraded(failure):
            self.bucket = MonitoringBucket(kind: "degraded-\(failure.reason.code)", sourceID: failure.sourceID)
        case .stopped:
            self.bucket = MonitoringBucket(kind: "stopped", sourceID: nil)
        }
        self.key = "\(bucket.kind).\(bucket.sourceID?.rawValue ?? "all")"
    }
}

private extension LiveMonitoringStaleReason {
    var code: String {
        switch self {
        case .missedChangeRecovered:
            return "live_monitoring.missed_change_recovered"
        case .sourceSnapshotMissing:
            return "live_monitoring.source_snapshot_missing"
        }
    }
}
