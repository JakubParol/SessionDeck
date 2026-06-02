public protocol LaunchConfigurationProviding: Sendable {
    func loadConfiguration() -> AppShellLaunchConfiguration
}
