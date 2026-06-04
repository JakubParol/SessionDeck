public struct SessionDeckApplicationComposition: Sendable {
    public let appShellViewModel: AppShellViewModel
    public let discoverSessionSources: DiscoverSessionSourcesUseCase
    public let enumerateCandidateSessionFiles: EnumerateCandidateSessionFilesUseCase
    public let listSessions: ListSessionsUseCase
    public let loadTranscriptPreview: LoadTranscriptPreviewUseCase

    public init(
        appShellViewModel: AppShellViewModel,
        discoverSessionSources: DiscoverSessionSourcesUseCase,
        enumerateCandidateSessionFiles: EnumerateCandidateSessionFilesUseCase,
        listSessions: ListSessionsUseCase,
        loadTranscriptPreview: LoadTranscriptPreviewUseCase
    ) {
        self.appShellViewModel = appShellViewModel
        self.discoverSessionSources = discoverSessionSources
        self.enumerateCandidateSessionFiles = enumerateCandidateSessionFiles
        self.listSessions = listSessions
        self.loadTranscriptPreview = loadTranscriptPreview
    }
}
