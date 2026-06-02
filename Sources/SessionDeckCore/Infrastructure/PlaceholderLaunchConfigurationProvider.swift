public struct PlaceholderLaunchConfigurationProvider: LaunchConfigurationProviding, Sendable {
    public init() {}

    public func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "SessionDeck",
            subtitle: "Local-first session viewer scaffold",
            statusMessage: "Placeholder app shell only. Session catalog is not implemented yet.",
            configuredSourceCount: 0,
            safetyPolicy: .placeholderSafe
        )
    }
}
