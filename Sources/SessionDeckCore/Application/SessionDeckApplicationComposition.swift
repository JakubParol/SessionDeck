public struct SessionDeckApplicationComposition: Sendable {
    public let appShellViewModel: AppShellViewModel
    public let discoverSessionSources: DiscoverSessionSourcesUseCase
    public let listSessions: ListSessionsUseCase
    public let loadTranscriptPreview: LoadTranscriptPreviewUseCase

    public init(
        appShellViewModel: AppShellViewModel,
        discoverSessionSources: DiscoverSessionSourcesUseCase,
        listSessions: ListSessionsUseCase,
        loadTranscriptPreview: LoadTranscriptPreviewUseCase
    ) {
        self.appShellViewModel = appShellViewModel
        self.discoverSessionSources = discoverSessionSources
        self.listSessions = listSessions
        self.loadTranscriptPreview = loadTranscriptPreview
    }
}
