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

public struct LaunchSafetyPolicy: Equatable, Sendable {
    public let readsRealAgentStores: Bool
    public let permitsNetworkCalls: Bool
    public let permitsCommandExecution: Bool
    public let permitsSessionMutation: Bool

    public init(
        readsRealAgentStores: Bool,
        permitsNetworkCalls: Bool,
        permitsCommandExecution: Bool,
        permitsSessionMutation: Bool
    ) {
        self.readsRealAgentStores = readsRealAgentStores
        self.permitsNetworkCalls = permitsNetworkCalls
        self.permitsCommandExecution = permitsCommandExecution
        self.permitsSessionMutation = permitsSessionMutation
    }
}

public enum AppBootstrap {
    public static func makeShellViewModel() -> AppShellViewModel {
        AppShellViewModel(
            title: "SessionDeck",
            subtitle: "Local-first session viewer scaffold",
            statusMessage: "Placeholder app shell only. Session catalog is not implemented yet.",
            configuredSourceCount: 0,
            safetyPolicy: LaunchSafetyPolicy(
                readsRealAgentStores: false,
                permitsNetworkCalls: false,
                permitsCommandExecution: false,
                permitsSessionMutation: false
            )
        )
    }
}
