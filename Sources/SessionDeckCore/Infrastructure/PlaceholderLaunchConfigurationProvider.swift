public struct PlaceholderLaunchConfigurationProvider: LaunchConfigurationProviding, Sendable {
    public init() {}

    public func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "SessionDeck",
            subtitle: "Local-first session viewer scaffold",
            statusMessage: "Read-only source discovery is active. Session catalog is not implemented yet.",
            configuredSourceCount: 0,
            safetyPolicy: LaunchSafetyPolicy(
                readsRealAgentStores: true,
                permitsNetworkCalls: false,
                permitsCommandExecution: false,
                permitsSessionMutation: false
            )
        )
    }
}
