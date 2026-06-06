public enum AppShellDiagnosticSeverity: Equatable, Sendable {
    case healthy
    case info
    case warning
    case error
}

public enum AppShellDiagnosticCategory: Equatable, Sendable {
    case source
    case sessionParse
    case liveMonitoring
    case reconciliation
    case refresh
}

public struct AppShellDiagnosticScope: Equatable, Sendable {
    public let sourceID: SessionSourceID?
    public let sessionID: SessionID?
    public let label: String?

    public init(
        sourceID: SessionSourceID? = nil,
        sessionID: SessionID? = nil,
        label: String? = nil
    ) {
        self.sourceID = sourceID
        self.sessionID = sessionID
        self.label = label
    }
}

public struct AppShellDiagnosticSummaryRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let category: AppShellDiagnosticCategory
    public let severity: AppShellDiagnosticSeverity
    public let title: String
    public let detail: String
    public let recoveryGuidance: String
    public let diagnosticCode: String?
    public let scope: AppShellDiagnosticScope

    public init(
        id: String,
        category: AppShellDiagnosticCategory,
        severity: AppShellDiagnosticSeverity,
        title: String,
        detail: String,
        recoveryGuidance: String,
        diagnosticCode: String?,
        scope: AppShellDiagnosticScope = AppShellDiagnosticScope()
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.title = title
        self.detail = detail
        self.recoveryGuidance = recoveryGuidance
        self.diagnosticCode = diagnosticCode
        self.scope = scope
    }
}

public struct AppShellDiagnosticsSummary: Equatable, Sendable {
    public static let healthy = AppShellDiagnosticsSummary(
        statusMessage: "No diagnostics need attention.",
        severity: .healthy,
        rows: [
            AppShellDiagnosticSummaryRow(
                id: "diagnostics.healthy",
                category: .source,
                severity: .healthy,
                title: "Healthy",
                detail: "No source, parser, watcher, reconciliation, or refresh diagnostics are active.",
                recoveryGuidance: "Keep browsing sessions normally.",
                diagnosticCode: nil
            ),
        ]
    )

    public let statusMessage: String
    public let severity: AppShellDiagnosticSeverity
    public let rows: [AppShellDiagnosticSummaryRow]

    public init(
        statusMessage: String,
        severity: AppShellDiagnosticSeverity,
        rows: [AppShellDiagnosticSummaryRow]
    ) {
        self.statusMessage = statusMessage
        self.severity = severity
        self.rows = rows
    }

    public static func make(rows: [AppShellDiagnosticSummaryRow]) -> AppShellDiagnosticsSummary {
        guard rows.isEmpty == false else {
            return .healthy
        }

        let sortedRows = rows.sorted(by: rowSort)
        let severity = highestSeverity(in: sortedRows)
        return AppShellDiagnosticsSummary(
            statusMessage: statusMessage(for: severity, rows: sortedRows),
            severity: severity,
            rows: sortedRows
        )
    }

    private static func highestSeverity(
        in rows: [AppShellDiagnosticSummaryRow]
    ) -> AppShellDiagnosticSeverity {
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
        for severity: AppShellDiagnosticSeverity,
        rows: [AppShellDiagnosticSummaryRow]
    ) -> String {
        switch severity {
        case .healthy:
            return "No diagnostics need attention."
        case .info:
            return "Diagnostics include informational health notes."
        case .warning:
            let warningCount = rows.filter { $0.severity == .warning }.count
            return "\(warningCount == 1 ? "1 warning needs" : "\(warningCount) warnings need") attention."
        case .error:
            let errorCount = rows.filter { $0.severity == .error }.count
            return "\(errorCount == 1 ? "1 blocking diagnostic needs" : "\(errorCount) blocking diagnostics need") attention."
        }
    }

    private static func rowSort(
        _ lhs: AppShellDiagnosticSummaryRow,
        _ rhs: AppShellDiagnosticSummaryRow
    ) -> Bool {
        let lhsRank = severityRank(lhs.severity)
        let rhsRank = severityRank(rhs.severity)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.id < rhs.id
    }

    private static func severityRank(_ severity: AppShellDiagnosticSeverity) -> Int {
        switch severity {
        case .error:
            return 0
        case .warning:
            return 1
        case .info:
            return 2
        case .healthy:
            return 3
        }
    }
}
