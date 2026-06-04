public enum SessionDeckCompositionRoot {
    public static func makeApplicationComposition(
        homeDirectoryProvider: any HomeDirectoryProviding = EnvironmentHomeDirectoryProvider(),
        sourceDefinitions: [LocalSessionSourceDefinition]? = nil
    ) -> SessionDeckApplicationComposition {
        let appShellUseCase = AppShellUseCase(
            launchConfigurationProvider: PlaceholderLaunchConfigurationProvider()
        )
        let sourceDiscoveryAdapter = DefaultCodexSourceDiscoveryAdapter(
            homeDirectoryProvider: homeDirectoryProvider,
            sourceDefinitions: sourceDefinitions
        )
        let discoverSessionSources = DiscoverSessionSourcesUseCase(
            sourceDiscovery: sourceDiscoveryAdapter
        )
        let enumerateCandidateSessionFiles = EnumerateCandidateSessionFilesUseCase(
            candidateFileEnumeration: sourceDiscoveryAdapter
        )
        let listSessions = ListSessionsUseCase(
            sessionCatalog: PlaceholderSessionCatalogAdapter()
        )
        let loadTranscriptPreview = LoadTranscriptPreviewUseCase(
            transcriptLoading: PlaceholderTranscriptLoadingAdapter()
        )

        return SessionDeckApplicationComposition(
            appShellViewModel: appShellUseCase.makeViewModel(),
            discoverSessionSources: discoverSessionSources,
            enumerateCandidateSessionFiles: enumerateCandidateSessionFiles,
            listSessions: listSessions,
            loadTranscriptPreview: loadTranscriptPreview
        )
    }

    public static func makeAppShellViewModel() -> AppShellViewModel {
        makeApplicationComposition().appShellViewModel
    }
}
