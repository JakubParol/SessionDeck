public struct AppShellUseCase: Sendable {
    private let launchConfigurationProvider: any LaunchConfigurationProviding
    private let discoverSessionSources: DiscoverSessionSourcesUseCase?
    private let refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase?

    public init(
        launchConfigurationProvider: any LaunchConfigurationProviding,
        discoverSessionSources: DiscoverSessionSourcesUseCase? = nil,
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase? = nil
    ) {
        self.launchConfigurationProvider = launchConfigurationProvider
        self.discoverSessionSources = discoverSessionSources
        self.refreshCatalogSnapshot = refreshCatalogSnapshot
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
        let catalogResult = catalogAndNavigationSummary()

        return AppShellViewModel(
            title: configuration.title,
            subtitle: configuration.subtitle,
            statusMessage: configuration.statusMessage,
            configuredSourceCount: discoverSessionSources == nil
                ? configuration.configuredSourceCount
                : discoveryResult.summary.configuredSourceCount,
            sourceDiscoverySummary: discoveryResult.summary,
            catalogSummary: catalogResult.summary,
            navigationSummary: catalogResult.navigation,
            refreshState: discoveryResult.refreshState ?? catalogResult.refreshState ?? refreshState,
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

    private func catalogAndNavigationSummary() -> (
        summary: AppShellCatalogSummary,
        navigation: AppShellNavigationSummary,
        refreshState: AppShellRefreshState?
    ) {
        guard let refreshCatalogSnapshot else {
            return (.placeholder, .placeholder, nil)
        }

        do {
            let snapshot = try refreshCatalogSnapshot.refreshSnapshot()
            return (.make(snapshot: snapshot), .make(snapshot: snapshot), nil)
        } catch {
            let message = "Catalog refresh failed before rows could be built."
            return (.failed(message: message), .placeholder, .failed(message))
        }
    }
}
