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

    public func makeViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty
    ) -> AppShellViewModel {
        makeViewModel(
            refreshState: .idle,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery
        )
    }

    public func refreshingViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty
    ) -> AppShellViewModel {
        makeViewModel(
            refreshState: .refreshing,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery
        )
    }

    public func refreshViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty
    ) -> AppShellViewModel {
        makeViewModel(
            refreshState: .idle,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery
        )
    }

    private func makeViewModel(
        refreshState: AppShellRefreshState,
        selectedNavigationNodeID: String?,
        catalogQuery: AppShellCatalogQueryState
    ) -> AppShellViewModel {
        let configuration = launchConfigurationProvider.loadConfiguration()
        let discoveryResult = sourceDiscoverySummary()
        let catalogResult = catalogAndNavigationSummary(
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery
        )

        return AppShellViewModel(
            title: configuration.title,
            subtitle: configuration.subtitle,
            statusMessage: configuration.statusMessage,
            configuredSourceCount: discoverSessionSources == nil
                ? configuration.configuredSourceCount
                : discoveryResult.summary.configuredSourceCount,
            sourceDiscoverySummary: discoveryResult.summary,
            catalogSummary: catalogResult.summary,
            catalogQueryControls: catalogResult.queryControls,
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

    private func catalogAndNavigationSummary(
        selectedNavigationNodeID: String?,
        catalogQuery: AppShellCatalogQueryState
    ) -> (
        summary: AppShellCatalogSummary,
        queryControls: AppShellCatalogQueryControls,
        navigation: AppShellNavigationSummary,
        selectedNode: AppShellNavigationNode,
        refreshState: AppShellRefreshState?
    ) {
        guard let refreshCatalogSnapshot else {
            let navigation = AppShellNavigationSummary.placeholder
            return (.placeholder, .placeholder, navigation, navigation.allChatsNode, nil)
        }

        do {
            let snapshot = try refreshCatalogSnapshot.refreshSnapshot()
            let navigation = AppShellNavigationSummary.make(snapshot: snapshot)
            let selectedNode = selectedNode(
                in: navigation,
                matching: selectedNavigationNodeID
            )
            let scopedSessions = SourceProfileNavigationPolicy.filter(
                sessions: snapshot.sessions,
                scope: selectedNode.catalogScope
            )
            let queryControls = AppShellCatalogQueryControls.make(
                sessions: scopedSessions,
                queryState: catalogQuery
            )
            return (
                .make(
                    snapshot: snapshot,
                    scope: selectedNode.catalogScope,
                    queryRequest: queryControls.request,
                    isFiltered: queryControls.hasActiveFilters
                ),
                queryControls,
                navigation,
                selectedNode,
                nil
            )
        } catch {
            let message = "Catalog refresh failed before rows could be built."
            let navigation = AppShellNavigationSummary.placeholder
            return (.failed(message: message), .placeholder, navigation, navigation.allChatsNode, .failed(message))
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
