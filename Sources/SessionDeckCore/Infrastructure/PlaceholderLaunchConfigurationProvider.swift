public struct PlaceholderLaunchConfigurationProvider: LaunchConfigurationProviding, Sendable {
    public init() {}

    public func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "SessionDeck",
            subtitle: "Local-first session viewer",
            statusMessage: "Ready to refresh read-only local session sources.",
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
