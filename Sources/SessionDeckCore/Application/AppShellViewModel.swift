public struct AppShellViewModel: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let statusMessage: String
    public let configuredSourceCount: Int
    public let safetyPolicy: LaunchSafetyPolicy

    public init(
        title: String,
        subtitle: String,
        statusMessage: String,
        configuredSourceCount: Int,
        safetyPolicy: LaunchSafetyPolicy
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusMessage = statusMessage
        self.configuredSourceCount = configuredSourceCount
        self.safetyPolicy = safetyPolicy
    }
}
