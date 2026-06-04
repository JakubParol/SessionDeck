public struct SessionDeckApplicationComposition: Sendable {
    public let appShellUseCase: AppShellUseCase
    public let appShellViewModel: AppShellViewModel
    public let discoverSessionSources: DiscoverSessionSourcesUseCase
    public let enumerateCandidateSessionFiles: EnumerateCandidateSessionFilesUseCase
    public let listSessions: ListSessionsUseCase
    public let refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase
    public let loadTranscriptPreview: LoadTranscriptPreviewUseCase
    public let loadTranscriptSegments: LoadTranscriptSegmentsUseCase
    public let loadSelectedTranscript: LoadSelectedTranscriptUseCase

    public init(
        appShellUseCase: AppShellUseCase,
        appShellViewModel: AppShellViewModel,
        discoverSessionSources: DiscoverSessionSourcesUseCase,
        enumerateCandidateSessionFiles: EnumerateCandidateSessionFilesUseCase,
        listSessions: ListSessionsUseCase,
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase,
        loadTranscriptPreview: LoadTranscriptPreviewUseCase,
        loadTranscriptSegments: LoadTranscriptSegmentsUseCase,
        loadSelectedTranscript: LoadSelectedTranscriptUseCase
    ) {
        self.appShellUseCase = appShellUseCase
        self.appShellViewModel = appShellViewModel
        self.discoverSessionSources = discoverSessionSources
        self.enumerateCandidateSessionFiles = enumerateCandidateSessionFiles
        self.listSessions = listSessions
        self.refreshCatalogSnapshot = refreshCatalogSnapshot
        self.loadTranscriptPreview = loadTranscriptPreview
        self.loadTranscriptSegments = loadTranscriptSegments
        self.loadSelectedTranscript = loadSelectedTranscript
    }
}
