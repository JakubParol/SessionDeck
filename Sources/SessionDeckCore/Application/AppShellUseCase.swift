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

    public func makeViewModel(selectedNavigationNodeID: String? = nil) -> AppShellViewModel {
        makeViewModel(refreshState: .idle, selectedNavigationNodeID: selectedNavigationNodeID)
    }

    public func refreshingViewModel(selectedNavigationNodeID: String? = nil) -> AppShellViewModel {
        makeViewModel(refreshState: .refreshing, selectedNavigationNodeID: selectedNavigationNodeID)
    }

    public func refreshViewModel(selectedNavigationNodeID: String? = nil) -> AppShellViewModel {
        makeViewModel(refreshState: .idle, selectedNavigationNodeID: selectedNavigationNodeID)
    }

    private func makeViewModel(
        refreshState: AppShellRefreshState,
        selectedNavigationNodeID: String?
    ) -> AppShellViewModel {
        let configuration = launchConfigurationProvider.loadConfiguration()
        let discoveryResult = sourceDiscoverySummary()
        let catalogResult = catalogAndNavigationSummary(selectedNavigationNodeID: selectedNavigationNodeID)

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
            selectedNavigationNodeID: catalogResult.selectedNode.id,
            selectedNavigationTitle: catalogResult.selectedNode.title,
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

    private func catalogAndNavigationSummary(selectedNavigationNodeID: String?) -> (
        summary: AppShellCatalogSummary,
        navigation: AppShellNavigationSummary,
        selectedNode: AppShellNavigationNode,
        refreshState: AppShellRefreshState?
    ) {
        guard let refreshCatalogSnapshot else {
            let navigation = AppShellNavigationSummary.placeholder
            return (.placeholder, navigation, navigation.allChatsNode, nil)
        }

        do {
            let snapshot = try refreshCatalogSnapshot.refreshSnapshot()
            let navigation = AppShellNavigationSummary.make(snapshot: snapshot)
            let selectedNode = selectedNode(
                in: navigation,
                matching: selectedNavigationNodeID
            )
            return (.make(snapshot: snapshot, scope: selectedNode.catalogScope), navigation, selectedNode, nil)
        } catch {
            let message = "Catalog refresh failed before rows could be built."
            let navigation = AppShellNavigationSummary.placeholder
            return (.failed(message: message), navigation, navigation.allChatsNode, .failed(message))
        }
    }

    private func selectedNode(
        in navigation: AppShellNavigationSummary,
        matching selectedNavigationNodeID: String?
    ) -> AppShellNavigationNode {
        guard let selectedNavigationNodeID,
              let selectedNode = navigation.node(id: selectedNavigationNodeID)
        else {
            return navigation.allChatsNode
        }

        return selectedNode
    }
}
