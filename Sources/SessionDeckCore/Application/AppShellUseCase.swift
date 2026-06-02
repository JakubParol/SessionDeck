public struct AppShellUseCase: Sendable {
    private let launchConfigurationProvider: any LaunchConfigurationProviding

    public init(launchConfigurationProvider: any LaunchConfigurationProviding) {
        self.launchConfigurationProvider = launchConfigurationProvider
    }

    public func makeViewModel() -> AppShellViewModel {
        let configuration = launchConfigurationProvider.loadConfiguration()

        return AppShellViewModel(
            title: configuration.title,
            subtitle: configuration.subtitle,
            statusMessage: configuration.statusMessage,
            configuredSourceCount: configuration.configuredSourceCount,
            safetyPolicy: configuration.safetyPolicy
        )
    }
}
