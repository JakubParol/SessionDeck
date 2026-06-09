import Foundation

public struct AppShellUseCase: Sendable {
    private let launchConfigurationProvider: any LaunchConfigurationProviding
    private let discoverSessionSources: DiscoverSessionSourcesUseCase?
    private let refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase?
    private let loadSelectedTranscript: LoadSelectedTranscriptUseCase?
    private let liveMonitoringStateProvider: @Sendable () -> [LiveMonitoringState]
    private let stateCache = AppShellRuntimeStateCache()

    public init(
        launchConfigurationProvider: any LaunchConfigurationProviding,
        discoverSessionSources: DiscoverSessionSourcesUseCase? = nil,
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase? = nil,
        loadSelectedTranscript: LoadSelectedTranscriptUseCase? = nil,
        liveMonitoringStateProvider: @escaping @Sendable () -> [LiveMonitoringState] = { [] }
    ) {
        self.launchConfigurationProvider = launchConfigurationProvider
        self.discoverSessionSources = discoverSessionSources
        self.refreshCatalogSnapshot = refreshCatalogSnapshot
        self.loadSelectedTranscript = loadSelectedTranscript
        self.liveMonitoringStateProvider = liveMonitoringStateProvider
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
            selectedSessionID: selectedSessionID,
            selectedTranscriptRefreshPhase: .none
        )
    }

    public func makeLaunchViewModel(
        refreshState: AppShellRefreshState = .idle
    ) -> AppShellViewModel {
        let configuration = launchConfigurationProvider.loadConfiguration()
        let monitoringHealthSummary = AppShellMonitoringHealthSummary.make(states: liveMonitoringStateProvider())
        return AppShellViewModel(
            title: configuration.title,
            subtitle: configuration.subtitle,
            statusMessage: configuration.statusMessage,
            configuredSourceCount: configuration.configuredSourceCount,
            sourceDiscoverySummary: .placeholder,
            monitoringHealthSummary: monitoringHealthSummary,
            diagnosticsSummary: AppShellDiagnosticsSummary.make(
                sourceDiscoverySummary: .placeholder,
                monitoringHealthSummary: monitoringHealthSummary,
                selectedTranscriptDetail: .noSelection
            ),
            catalogSummary: .placeholder,
            catalogQueryControls: .placeholder,
            navigationSummary: .placeholder,
            selectedNavigationNodeID: AppShellNavigationSummary.placeholder.allChatsNode.id,
            selectedNavigationTitle: AppShellNavigationSummary.placeholder.allChatsNode.title,
            selectedTranscriptDetail: .noSelection,
            refreshState: refreshState,
            safetyPolicy: configuration.safetyPolicy
        )
    }

    public func makeCachedViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty,
        selectedSessionID: SessionID? = nil
    ) -> AppShellViewModel {
        makeCachedViewModel(
            refreshState: .idle,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery,
            selectedSessionID: selectedSessionID,
            selectedTranscriptRefreshPhase: .none
        )
    }

    public func refreshingViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty,
        selectedSessionID: SessionID? = nil,
        previousSelectedTranscriptDetail: AppShellSelectedTranscriptDetailState? = nil
    ) -> AppShellViewModel {
        makeCachedViewModel(
            refreshState: .refreshing,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery,
            selectedSessionID: selectedSessionID,
            selectedTranscriptRefreshPhase: .refreshing(previousSelectedTranscriptDetail)
        )
    }

    public func refreshViewModel(
        selectedNavigationNodeID: String? = nil,
        catalogQuery: AppShellCatalogQueryState = .empty,
        selectedSessionID: SessionID? = nil,
        previousSelectedTranscriptDetail: AppShellSelectedTranscriptDetailState? = nil
    ) -> AppShellViewModel {
        makeViewModel(
            refreshState: .idle,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery,
            selectedSessionID: selectedSessionID,
            selectedTranscriptRefreshPhase: .completed(previousSelectedTranscriptDetail)
        )
    }

    private func makeViewModel(
        refreshState: AppShellRefreshState,
        selectedNavigationNodeID: String?,
        catalogQuery: AppShellCatalogQueryState,
        selectedSessionID: SessionID?,
        selectedTranscriptRefreshPhase: SelectedTranscriptRefreshPhase
    ) -> AppShellViewModel {
        let configuration = launchConfigurationProvider.loadConfiguration()
        let discoveryResult = sourceDiscoverySummary()
        let catalogResult = catalogAndNavigationSummary(
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery
        )
        let monitoringHealthSummary = AppShellMonitoringHealthSummary.make(states: liveMonitoringStateProvider())
        let selectedTranscriptDetail = selectedTranscriptDetail(
            selectedSessionID: selectedSessionID,
            sessions: catalogResult.scopedSessions,
            refreshPhase: selectedTranscriptRefreshPhase
        )

        return AppShellViewModel(
            title: configuration.title,
            subtitle: configuration.subtitle,
            statusMessage: configuration.statusMessage,
            configuredSourceCount: discoverSessionSources == nil
                ? configuration.configuredSourceCount
                : discoveryResult.summary.configuredSourceCount,
            sourceDiscoverySummary: discoveryResult.summary,
            monitoringHealthSummary: monitoringHealthSummary,
            diagnosticsSummary: AppShellDiagnosticsSummary.make(
                sourceDiscoverySummary: discoveryResult.summary,
                monitoringHealthSummary: monitoringHealthSummary,
                selectedTranscriptDetail: selectedTranscriptDetail
            ),
            catalogSummary: catalogResult.summary,
            catalogQueryControls: catalogResult.queryControls,
            navigationSummary: catalogResult.navigation,
            selectedNavigationNodeID: catalogResult.selectedNode.id,
            selectedNavigationTitle: catalogResult.selectedNode.title,
            selectedTranscriptDetail: selectedTranscriptDetail,
            refreshState: discoveryResult.refreshState ?? catalogResult.refreshState ?? refreshState,
            safetyPolicy: configuration.safetyPolicy
        )
    }

    private func makeCachedViewModel(
        refreshState: AppShellRefreshState,
        selectedNavigationNodeID: String?,
        catalogQuery: AppShellCatalogQueryState,
        selectedSessionID: SessionID?,
        selectedTranscriptRefreshPhase: SelectedTranscriptRefreshPhase
    ) -> AppShellViewModel {
        guard let snapshot = stateCache.snapshot else {
            return makeLaunchViewModel(refreshState: refreshState)
        }

        let configuration = launchConfigurationProvider.loadConfiguration()
        let sourceSummary = stateCache.sourceDiscoverySummary ?? .placeholder
        let catalogResult = catalogAndNavigationSummary(
            snapshot: snapshot,
            selectedNavigationNodeID: selectedNavigationNodeID,
            catalogQuery: catalogQuery
        )
        let monitoringHealthSummary = AppShellMonitoringHealthSummary.make(states: liveMonitoringStateProvider())
        let selectedTranscriptDetail = selectedTranscriptDetail(
            selectedSessionID: selectedSessionID,
            sessions: catalogResult.scopedSessions,
            refreshPhase: selectedTranscriptRefreshPhase
        )

        return AppShellViewModel(
            title: configuration.title,
            subtitle: configuration.subtitle,
            statusMessage: configuration.statusMessage,
            configuredSourceCount: sourceSummary.configuredSourceCount,
            sourceDiscoverySummary: sourceSummary,
            monitoringHealthSummary: monitoringHealthSummary,
            diagnosticsSummary: AppShellDiagnosticsSummary.make(
                sourceDiscoverySummary: sourceSummary,
                monitoringHealthSummary: monitoringHealthSummary,
                selectedTranscriptDetail: selectedTranscriptDetail
            ),
            catalogSummary: catalogResult.summary,
            catalogQueryControls: catalogResult.queryControls,
            navigationSummary: catalogResult.navigation,
            selectedNavigationNodeID: catalogResult.selectedNode.id,
            selectedNavigationTitle: catalogResult.selectedNode.title,
            selectedTranscriptDetail: selectedTranscriptDetail,
            refreshState: refreshState,
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
            let summary = AppShellSourceDiscoverySummary.make(report: try discoverSessionSources.discoveryReport())
            stateCache.store(sourceDiscoverySummary: summary)
            return (summary, nil)
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
            stateCache.store(snapshot: snapshot)
            let cachedResult = catalogAndNavigationSummary(
                snapshot: snapshot,
                selectedNavigationNodeID: selectedNavigationNodeID,
                catalogQuery: catalogQuery
            )
            return (
                cachedResult.summary,
                cachedResult.queryControls,
                cachedResult.navigation,
                cachedResult.selectedNode,
                cachedResult.scopedSessions,
                nil
            )
        } catch {
            let message = "Catalog refresh failed before rows could be built."
            let navigation = AppShellNavigationSummary.placeholder
            return (.failed(message: message), .placeholder, navigation, navigation.allChatsNode, [], .failed(message))
        }
    }

    private func catalogAndNavigationSummary(
        snapshot: CatalogSnapshot,
        selectedNavigationNodeID: String?,
        catalogQuery: AppShellCatalogQueryState
    ) -> (
        summary: AppShellCatalogSummary,
        queryControls: AppShellCatalogQueryControls,
        navigation: AppShellNavigationSummary,
        selectedNode: AppShellNavigationNode,
        scopedSessions: [SessionSummary]
    ) {
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
            scopedSessions
        )
    }

    private func selectedTranscriptDetail(
        selectedSessionID: SessionID?,
        sessions: [SessionSummary],
        refreshPhase: SelectedTranscriptRefreshPhase
    ) -> AppShellSelectedTranscriptDetailState {
        if case let .refreshing(previous) = refreshPhase,
           let previous {
            return previous.refreshingLiveRefresh()
        }

        guard let selectedSessionID else {
            return .noSelection
        }
        guard let selectedSession = sessions.first(where: { $0.id == selectedSessionID }),
              let loadSelectedTranscript
        else {
            if case let .completed(previous) = refreshPhase,
               let previous {
                return previous.failedLiveRefresh(
                    message: SelectedTranscriptLoadingError.transcriptUnavailable(selectedSessionID).localizedRefreshMessage
                )
            }
            return .failed(SelectedTranscriptLoadingError.transcriptUnavailable(selectedSessionID))
        }

        do {
            let readModel = try loadSelectedTranscript.loadTranscript(for: selectedSession)
            if case .completed(.some) = refreshPhase {
                return .liveRefresh(.loaded(readModel))
            }
            return .loaded(readModel)
        } catch {
            if case let .completed(previous) = refreshPhase,
               let previous {
                let failedState = AppShellSelectedTranscriptDetailState.failed(error, session: selectedSession)
                return previous.failedLiveRefresh(message: failedState.statusMessage)
            }
            return .failed(error, session: selectedSession)
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

private enum SelectedTranscriptRefreshPhase {
    case none
    case refreshing(AppShellSelectedTranscriptDetailState?)
    case completed(AppShellSelectedTranscriptDetailState?)
}

private final class AppShellRuntimeStateCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedSnapshot: CatalogSnapshot?
    private var cachedSourceDiscoverySummary: AppShellSourceDiscoverySummary?

    var snapshot: CatalogSnapshot? {
        lock.withLock { cachedSnapshot }
    }

    var sourceDiscoverySummary: AppShellSourceDiscoverySummary? {
        lock.withLock { cachedSourceDiscoverySummary }
    }

    func store(snapshot: CatalogSnapshot) {
        lock.withLock {
            cachedSnapshot = snapshot
        }
    }

    func store(sourceDiscoverySummary: AppShellSourceDiscoverySummary) {
        lock.withLock {
            cachedSourceDiscoverySummary = sourceDiscoverySummary
        }
    }
}

private extension SelectedTranscriptLoadingError {
    var localizedRefreshMessage: String {
        AppShellSelectedTranscriptDetailState.failed(self).statusMessage
    }
}
