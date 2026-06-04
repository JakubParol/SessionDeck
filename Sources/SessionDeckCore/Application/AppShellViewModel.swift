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
}

public struct AppShellViewModel: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let statusMessage: String
    public let configuredSourceCount: Int
    public let sourceDiscoverySummary: AppShellSourceDiscoverySummary
    public let refreshState: AppShellRefreshState
    public let safetyPolicy: LaunchSafetyPolicy

    public init(
        title: String,
        subtitle: String,
        statusMessage: String,
        configuredSourceCount: Int,
        sourceDiscoverySummary: AppShellSourceDiscoverySummary = .placeholder,
        refreshState: AppShellRefreshState = .idle,
        safetyPolicy: LaunchSafetyPolicy
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusMessage = statusMessage
        self.configuredSourceCount = configuredSourceCount
        self.sourceDiscoverySummary = sourceDiscoverySummary
        self.refreshState = refreshState
        self.safetyPolicy = safetyPolicy
    }
}
