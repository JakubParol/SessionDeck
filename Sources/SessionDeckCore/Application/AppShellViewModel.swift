public enum AppShellRefreshState: Equatable, Sendable {
    case idle
    case refreshing
    case failed(String)
}

public struct AppShellSourceDiscoverySummary: Equatable, Sendable {
    public static let placeholder = AppShellSourceDiscoverySummary(
        configuredSourceCount: 0,
        availableSourceCount: 0,
        candidateFileCount: nil,
        warningCount: 0,
        errorCount: 0,
        statusMessage: "Source discovery has not run yet."
    )

    public let configuredSourceCount: Int
    public let availableSourceCount: Int
    public let candidateFileCount: Int?
    public let warningCount: Int
    public let errorCount: Int
    public let statusMessage: String

    public init(
        configuredSourceCount: Int,
        availableSourceCount: Int,
        candidateFileCount: Int?,
        warningCount: Int,
        errorCount: Int,
        statusMessage: String
    ) {
        self.configuredSourceCount = configuredSourceCount
        self.availableSourceCount = availableSourceCount
        self.candidateFileCount = candidateFileCount
        self.warningCount = warningCount
        self.errorCount = errorCount
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
            statusMessage: message
        )
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

public struct AppShellViewModel: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let statusMessage: String
    public let configuredSourceCount: Int
    public let sourceDiscoverySummary: AppShellSourceDiscoverySummary
    public let catalogSummary: AppShellCatalogSummary
    public let refreshState: AppShellRefreshState
    public let safetyPolicy: LaunchSafetyPolicy

    public init(
        title: String,
        subtitle: String,
        statusMessage: String,
        configuredSourceCount: Int,
        sourceDiscoverySummary: AppShellSourceDiscoverySummary = .placeholder,
        catalogSummary: AppShellCatalogSummary = .placeholder,
        refreshState: AppShellRefreshState = .idle,
        safetyPolicy: LaunchSafetyPolicy
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusMessage = statusMessage
        self.configuredSourceCount = configuredSourceCount
        self.sourceDiscoverySummary = sourceDiscoverySummary
        self.catalogSummary = catalogSummary
        self.refreshState = refreshState
        self.safetyPolicy = safetyPolicy
    }
}
