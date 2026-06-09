import Foundation

public enum SessionDeckCompositionRoot {
    public static func makeApplicationComposition(
        homeDirectoryProvider: any HomeDirectoryProviding = EnvironmentHomeDirectoryProvider(),
        sourceDefinitions: [LocalSessionSourceDefinition]? = nil
    ) -> SessionDeckApplicationComposition {
        let sourceDiscoveryAdapter = DefaultCodexSourceDiscoveryAdapter(
            homeDirectoryProvider: homeDirectoryProvider,
            sourceDefinitions: sourceDefinitions
        )
        let discoverSessionSources = DiscoverSessionSourcesUseCase(
            sourceDiscovery: sourceDiscoveryAdapter,
            candidateFileEnumeration: sourceDiscoveryAdapter
        )
        let enumerateCandidateSessionFiles = EnumerateCandidateSessionFilesUseCase(
            candidateFileEnumeration: sourceDiscoveryAdapter
        )
        let sessionCatalogAdapter = CodexSessionCatalogAdapter(
            sourceDiscovery: sourceDiscoveryAdapter,
            candidateFileEnumeration: sourceDiscoveryAdapter
        )
        let listSessions = ListSessionsUseCase(
            sessionCatalog: sessionCatalogAdapter
        )
        let refreshCatalogSnapshot = RefreshCatalogSnapshotUseCase(
            sourceDiscovery: sourceDiscoveryAdapter,
            metadataExtraction: sessionCatalogAdapter
        )
        let loadSelectedTranscript = LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: CodexSelectedTranscriptLoadingAdapter()
        )
        let loadTranscriptPreview = LoadTranscriptPreviewUseCase(
            transcriptLoading: PlaceholderTranscriptLoadingAdapter()
        )
        let loadTranscriptSegments = LoadTranscriptSegmentsUseCase(
            transcriptDecoding: PlaceholderTranscriptDecodingAdapter()
        )
        let sourceChangeObservation = LocalFileSourceObservationAdapter()
        let reconcileSessionSources = ReconcileSessionSourcesUseCase(
            candidateEnumeration: sourceDiscoveryAdapter
        )
        let refreshQueue = DispatchQueue(label: "SessionDeck.live-refresh-work")
        let liveRefreshPipeline = LiveRefreshPipelineCoordinator(
            sourceChangeObservation: sourceChangeObservation,
            reconciliation: reconcileSessionSources,
            timerScheduler: DispatchLiveRefreshTimerScheduler(),
            debounceInterval: 0.25,
            reconciliationInterval: 30
        ) { _ in
            refreshQueue.async {
                _ = try? refreshCatalogSnapshot.refreshSnapshot()
            }
        }
        let appShellUseCase = AppShellUseCase(
            launchConfigurationProvider: PlaceholderLaunchConfigurationProvider(),
            discoverSessionSources: discoverSessionSources,
            refreshCatalogSnapshot: refreshCatalogSnapshot,
            loadSelectedTranscript: loadSelectedTranscript,
            liveMonitoringStateProvider: { liveRefreshPipeline.monitoringStates }
        )

        return SessionDeckApplicationComposition(
            appShellUseCase: appShellUseCase,
            appShellViewModel: appShellUseCase.makeLaunchViewModel(),
            discoverSessionSources: discoverSessionSources,
            enumerateCandidateSessionFiles: enumerateCandidateSessionFiles,
            listSessions: listSessions,
            refreshCatalogSnapshot: refreshCatalogSnapshot,
            loadTranscriptPreview: loadTranscriptPreview,
            loadTranscriptSegments: loadTranscriptSegments,
            loadSelectedTranscript: loadSelectedTranscript,
            sourceChangeObservation: sourceChangeObservation,
            liveRefreshPipeline: liveRefreshPipeline
        )
    }

    public static func makeAppShellViewModel() -> AppShellViewModel {
        makeApplicationComposition().appShellViewModel
    }
}
