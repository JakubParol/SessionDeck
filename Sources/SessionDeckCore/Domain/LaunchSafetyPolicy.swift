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

    public static let placeholderSafe = LaunchSafetyPolicy(
        readsRealAgentStores: false,
        permitsNetworkCalls: false,
        permitsCommandExecution: false,
        permitsSessionMutation: false
    )
}
