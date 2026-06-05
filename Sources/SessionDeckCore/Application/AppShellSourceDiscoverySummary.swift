public enum AppShellSourceHealthSeverity: Equatable, Sendable {
    case healthy
    case info
    case warning
    case error
}

public struct AppShellSourceHealthRow: Equatable, Sendable {
    public let id: String
    public let title: String
    public let location: String
    public let statusLabel: String
    public let detail: String
    public let severity: AppShellSourceHealthSeverity
    public let isBlocking: Bool

    public init(
        id: String,
        title: String,
        location: String,
        statusLabel: String,
        detail: String,
        severity: AppShellSourceHealthSeverity,
        isBlocking: Bool
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.statusLabel = statusLabel
        self.detail = detail
        self.severity = severity
        self.isBlocking = isBlocking
    }
}

public struct AppShellSourceDiscoverySummary: Equatable, Sendable {
    public static let placeholder = AppShellSourceDiscoverySummary(
        configuredSourceCount: 0,
        availableSourceCount: 0,
        candidateFileCount: nil,
        warningCount: 0,
        errorCount: 0,
        sourceHealthRows: [],
        statusMessage: "Source discovery has not run yet."
    )

    public let configuredSourceCount: Int
    public let availableSourceCount: Int
    public let candidateFileCount: Int?
    public let warningCount: Int
    public let errorCount: Int
    public let sourceHealthRows: [AppShellSourceHealthRow]
    public let statusMessage: String

    public init(
        configuredSourceCount: Int,
        availableSourceCount: Int,
        candidateFileCount: Int?,
        warningCount: Int,
        errorCount: Int,
        sourceHealthRows: [AppShellSourceHealthRow] = [],
        statusMessage: String
    ) {
        self.configuredSourceCount = configuredSourceCount
        self.availableSourceCount = availableSourceCount
        self.candidateFileCount = candidateFileCount
        self.warningCount = warningCount
        self.errorCount = errorCount
        self.sourceHealthRows = sourceHealthRows
        self.statusMessage = statusMessage
    }

    public static func make(report: SessionSourceDiscoveryReport) -> AppShellSourceDiscoverySummary {
        let warningCount = report.diagnostics.filter { $0.diagnostic.severity == .warning }.count
            + report.candidateDiagnostics.filter { $0.diagnostic.severity == .warning }.count
        let errorCount = report.diagnostics.filter { $0.diagnostic.severity == .error }.count
            + report.candidateDiagnostics.filter { $0.diagnostic.severity == .error }.count

        return AppShellSourceDiscoverySummary(
            configuredSourceCount: report.sources.count,
            availableSourceCount: report.availableSources.count,
            candidateFileCount: report.candidateFileCount,
            warningCount: warningCount,
            errorCount: errorCount,
            sourceHealthRows: sourceHealthRows(report: report),
            statusMessage: statusMessage(
                report: report,
                warningCount: warningCount,
                errorCount: errorCount
            )
        )
    }

    public static func failed(message: String) -> AppShellSourceDiscoverySummary {
        AppShellSourceDiscoverySummary(
            configuredSourceCount: 0,
            availableSourceCount: 0,
            candidateFileCount: nil,
            warningCount: 0,
            errorCount: 1,
            sourceHealthRows: [],
            statusMessage: message
        )
    }

    private static func sourceHealthRows(report: SessionSourceDiscoveryReport) -> [AppShellSourceHealthRow] {
        let candidateDiagnosticsBySourceID = Dictionary(grouping: report.candidateDiagnostics, by: \.sourceID)
        return report.sources.map { source in
            let candidateDiagnostic = candidateDiagnosticsBySourceID[source.id]?.first?.diagnostic
            let severity = sourceHealthSeverity(source: source, candidateDiagnostic: candidateDiagnostic)
            return AppShellSourceHealthRow(
                id: source.id.rawValue,
                title: source.displayName,
                location: source.locationDescription,
                statusLabel: sourceHealthStatusLabel(source: source, candidateDiagnostic: candidateDiagnostic),
                detail: sourceHealthDetail(source: source, candidateDiagnostic: candidateDiagnostic),
                severity: severity,
                isBlocking: source.diagnostic?.allowsDiscoveryToContinue == false
                    || candidateDiagnostic?.allowsDiscoveryToContinue == false
            )
        }
    }

    private static func sourceHealthSeverity(
        source: SessionSourceSummary,
        candidateDiagnostic: CandidateSessionFileDiagnostic?
    ) -> AppShellSourceHealthSeverity {
        if let diagnostic = source.diagnostic {
            return appSeverity(for: diagnostic.severity)
        }
        if let candidateDiagnostic {
            return appSeverity(for: candidateDiagnostic.severity)
        }
        return .healthy
    }

    private static func sourceHealthStatusLabel(
        source: SessionSourceSummary,
        candidateDiagnostic: CandidateSessionFileDiagnostic?
    ) -> String {
        if let code = source.diagnostic?.code {
            switch code {
            case .codexSessionsRootMissing:
                return "Missing path"
            case .codexSessionsRootPermissionDenied:
                return "Permission denied"
            case .codexSessionsRootEmpty:
                return "Empty"
            case .codexSessionsRootStale:
                return "Stale"
            case .codexSessionsRootUnreadable:
                return "Unreadable"
            case .sourceRootDuplicate:
                return "Duplicate"
            case .sourceKindUnsupported:
                return "Unsupported"
            case .sourceRootDisabled:
                return "Disabled"
            }
        }
        if candidateDiagnostic != nil {
            return "Parse warning"
        }
        return "Available"
    }

    private static func sourceHealthDetail(
        source: SessionSourceSummary,
        candidateDiagnostic: CandidateSessionFileDiagnostic?
    ) -> String {
        if let message = source.diagnostic?.message {
            return message
        }
        if let message = candidateDiagnostic?.message {
            return message
        }
        return candidateCountDetail(source.counts)
    }

    private static func candidateCountDetail(_ counts: SessionSourceCounts) -> String {
        let transcriptLabel = counts.transcriptFileCount == 1 ? "candidate transcript" : "candidate transcripts"
        let bucketLabel = counts.sessionBucketDirectoryCount == 1 ? "bucket" : "buckets"
        return "\(counts.transcriptFileCount) \(transcriptLabel) in \(counts.sessionBucketDirectoryCount) \(bucketLabel)."
    }

    private static func appSeverity(for severity: SourceDiagnosticSeverity) -> AppShellSourceHealthSeverity {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func statusMessage(
        report: SessionSourceDiscoveryReport,
        warningCount: Int,
        errorCount: Int
    ) -> String {
        if report.sources.isEmpty {
            return "No session sources are configured."
        }
        if errorCount > 0 {
            return "Source discovery found errors that need attention."
        }
        if warningCount > 0 {
            return "Source discovery completed with warnings."
        }
        if report.availableSources.isEmpty {
            return "No available session sources were found."
        }

        return "Source discovery found \(report.availableSources.count) available source(s)."
    }
}
