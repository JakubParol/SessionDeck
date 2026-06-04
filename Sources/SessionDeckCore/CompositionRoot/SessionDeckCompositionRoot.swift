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
        let appShellUseCase = AppShellUseCase(
            launchConfigurationProvider: PlaceholderLaunchConfigurationProvider(),
            discoverSessionSources: discoverSessionSources,
            refreshCatalogSnapshot: refreshCatalogSnapshot
        )
        let loadTranscriptPreview = LoadTranscriptPreviewUseCase(
            transcriptLoading: PlaceholderTranscriptLoadingAdapter()
        )
        let loadTranscriptSegments = LoadTranscriptSegmentsUseCase(
            transcriptDecoding: PlaceholderTranscriptDecodingAdapter()
        )

        return SessionDeckApplicationComposition(
            appShellUseCase: appShellUseCase,
            appShellViewModel: appShellUseCase.makeViewModel(),
            discoverSessionSources: discoverSessionSources,
            enumerateCandidateSessionFiles: enumerateCandidateSessionFiles,
            listSessions: listSessions,
            refreshCatalogSnapshot: refreshCatalogSnapshot,
            loadTranscriptPreview: loadTranscriptPreview,
            loadTranscriptSegments: loadTranscriptSegments
        )
    }

    public static func makeAppShellViewModel() -> AppShellViewModel {
        makeApplicationComposition().appShellViewModel
    }
}
