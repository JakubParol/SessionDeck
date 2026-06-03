public enum SessionDeckCompositionRoot {
    public static func makeApplicationComposition(
        homeDirectoryProvider: any HomeDirectoryProviding = EnvironmentHomeDirectoryProvider()
    ) -> SessionDeckApplicationComposition {
        let appShellUseCase = AppShellUseCase(
            launchConfigurationProvider: PlaceholderLaunchConfigurationProvider()
        )
        let discoverSessionSources = DiscoverSessionSourcesUseCase(
            sourceDiscovery: DefaultCodexSourceDiscoveryAdapter(homeDirectoryProvider: homeDirectoryProvider)
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
            listSessions: listSessions,
            loadTranscriptPreview: loadTranscriptPreview
        )
    }

    public static func makeAppShellViewModel() -> AppShellViewModel {
        makeApplicationComposition().appShellViewModel
    }
}
