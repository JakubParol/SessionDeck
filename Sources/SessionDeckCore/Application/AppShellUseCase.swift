public struct AppShellUseCase: Sendable {
    private let launchConfigurationProvider: any LaunchConfigurationProviding
    private let discoverSessionSources: DiscoverSessionSourcesUseCase?
    private let refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase?
    private let loadSelectedTranscript: LoadSelectedTranscriptUseCase?

    public init(
        launchConfigurationProvider: any LaunchConfigurationProviding,
        discoverSessionSources: DiscoverSessionSourcesUseCase? = nil,
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase? = nil,
        loadSelectedTranscript: LoadSelectedTranscriptUseCase? = nil
    ) {
        self.launchConfigurationProvider = launchConfigurationProvider
        self.discoverSessionSources = discoverSessionSources
        self.refreshCatalogSnapshot = refreshCatalogSnapshot
        self.loadSelectedTranscript = loadSelectedTranscript
    }

    public func makeViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty,
        selectedSessionID: SessionID? = nil
    ) -> AppShellViewModel {
        makeViewModel(
            refreshState: .idle,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery,
            selectedSessionID: selectedSessionID
        )
    }

    public func refreshingViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty,
        selectedSessionID: SessionID? = nil
    ) -> AppShellViewModel {
        makeViewModel(
            refreshState: .refreshing,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery,
            selectedSessionID: selectedSessionID
        )
    }

    public func refreshViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty,
        selectedSessionID: SessionID? = nil
    ) -> AppShellViewModel {
        makeViewModel(
            refreshState: .idle,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery,
            selectedSessionID: selectedSessionID
        )
    }

    private func makeViewModel(
        refreshState: AppShellRefreshState,
        selectedNavigationNodeID: String?,
        catalogQuery: AppShellCatalogQueryState,
        selectedSessionID: SessionID?
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
            selectedTranscriptDetail: selectedTranscriptDetail(
                selectedSessionID: selectedSessionID,
                sessions: catalogResult.scopedSessions
            ),
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
        scopedSessions: [SessionSummary],
        refreshState: AppShellRefreshState?
    ) {
        guard let refreshCatalogSnapshot else {
            let navigation = AppShellNavigationSummary.placeholder
            return (.placeholder, .placeholder, navigation, navigation.allChatsNode, [], nil)
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
                scopedSessions,
                nil
            )
        } catch {
            let message = "Catalog refresh failed before rows could be built."
            let navigation = AppShellNavigationSummary.placeholder
            return (.failed(message: message), .placeholder, navigation, navigation.allChatsNode, [], .failed(message))
        }
    }

    private func selectedTranscriptDetail(
        selectedSessionID: SessionID?,
        sessions: [SessionSummary]
    ) -> AppShellSelectedTranscriptDetailState {
        guard let selectedSessionID else {
            return .noSelection
        }
        guard let selectedSession = sessions.first(where: { $0.id == selectedSessionID }),
              let loadSelectedTranscript
        else {
            return .failed(SelectedTranscriptLoadingError.transcriptUnavailable(selectedSessionID))
        }

        do {
            return .loaded(try loadSelectedTranscript.loadTranscript(for: selectedSession))
        } catch {
            return .failed(error)
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
