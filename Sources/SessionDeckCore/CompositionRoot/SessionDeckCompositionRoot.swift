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
        let appShellUseCase = AppShellUseCase(
            launchConfigurationProvider: PlaceholderLaunchConfigurationProvider(),
            discoverSessionSources: discoverSessionSources
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
        let loadTranscriptPreview = LoadTranscriptPreviewUseCase(
            transcriptLoading: PlaceholderTranscriptLoadingAdapter()
        )

        return SessionDeckApplicationComposition(
            appShellUseCase: appShellUseCase,
            appShellViewModel: appShellUseCase.makeViewModel(),
            discoverSessionSources: discoverSessionSources,
            enumerateCandidateSessionFiles: enumerateCandidateSessionFiles,
            listSessions: listSessions,
            refreshCatalogSnapshot: refreshCatalogSnapshot,
            loadTranscriptPreview: loadTranscriptPreview
        )
    }

    public static func makeAppShellViewModel() -> AppShellViewModel {
        makeApplicationComposition().appShellViewModel
    }
}
