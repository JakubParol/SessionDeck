public struct AppShellUseCase: Sendable {
    private let launchConfigurationProvider: any LaunchConfigurationProviding
    private let discoverSessionSources: DiscoverSessionSourcesUseCase?

    public init(
        launchConfigurationProvider: any LaunchConfigurationProviding,
        discoverSessionSources: DiscoverSessionSourcesUseCase? = nil
    ) {
        self.launchConfigurationProvider = launchConfigurationProvider
        self.discoverSessionSources = discoverSessionSources
    }

    public func makeViewModel() -> AppShellViewModel {
        makeViewModel(refreshState: .idle)
    }

    public func refreshingViewModel() -> AppShellViewModel {
        makeViewModel(refreshState: .refreshing)
    }

    public func refreshViewModel() -> AppShellViewModel {
        makeViewModel(refreshState: .idle)
    }

    private func makeViewModel(refreshState: AppShellRefreshState) -> AppShellViewModel {
        let configuration = launchConfigurationProvider.loadConfiguration()
        let discoveryResult = sourceDiscoverySummary()

        return AppShellViewModel(
            title: configuration.title,
            subtitle: configuration.subtitle,
            statusMessage: configuration.statusMessage,
            configuredSourceCount: discoverSessionSources == nil
                ? configuration.configuredSourceCount
                : discoveryResult.summary.configuredSourceCount,
            sourceDiscoverySummary: discoveryResult.summary,
            refreshState: discoveryResult.refreshState ?? refreshState,
            safetyPolicy: configuration.safetyPolicy
        )
    }

    private func sourceDiscoverySummary() -> (
        summary: AppShellSourceDiscoverySummary,
        refreshState: AppShellRefreshState?
    ) {
        guard let discoverSessionSources else {
            return (.placeholder, nil)
        }

        do {
            return (.make(report: try discoverSessionSources.discoveryReport()), nil)
        } catch {
            let message = "Source discovery failed before a summary could be built."
            return (.failed(message: message), .failed(message))
        }
    }
}
