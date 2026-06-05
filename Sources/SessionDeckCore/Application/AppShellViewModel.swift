public enum AppShellRefreshState: Equatable, Sendable {
    case idle
    case refreshing
    case failed(String)
}

public struct AppShellReadingSurfaceState: Equatable, Sendable {
    public let catalogTitle: String
    public let detailTitle: String
    public let detailDisplayMode: AppShellSelectedTranscriptDisplayMode
    public let minimumCatalogPaneWidth: Double
    public let minimumTranscriptPaneWidth: Double
    public let preservesSidebarContext: Bool

    public init(
        catalogTitle: String,
        detailTitle: String,
        detailDisplayMode: AppShellSelectedTranscriptDisplayMode,
        minimumCatalogPaneWidth: Double = 360,
        minimumTranscriptPaneWidth: Double = 420,
        preservesSidebarContext: Bool = true
    ) {
        self.catalogTitle = catalogTitle
        self.detailTitle = detailTitle
        self.detailDisplayMode = detailDisplayMode
        self.minimumCatalogPaneWidth = minimumCatalogPaneWidth
        self.minimumTranscriptPaneWidth = minimumTranscriptPaneWidth
        self.preservesSidebarContext = preservesSidebarContext
    }

    public static func make(
        catalogTitle: String,
        detailState: AppShellSelectedTranscriptDetailState
    ) -> AppShellReadingSurfaceState {
        AppShellReadingSurfaceState(
            catalogTitle: catalogTitle,
            detailTitle: detailState.title,
            detailDisplayMode: detailState.displayMode
        )
    }
}

public struct AppShellViewModel: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let statusMessage: String
    public let configuredSourceCount: Int
    public let sourceDiscoverySummary: AppShellSourceDiscoverySummary
    public let catalogSummary: AppShellCatalogSummary
    public let catalogQueryControls: AppShellCatalogQueryControls
    public let navigationSummary: AppShellNavigationSummary
    public let selectedNavigationNodeID: String
    public let selectedNavigationTitle: String
    public let readingSurface: AppShellReadingSurfaceState
    public let selectedTranscriptDetail: AppShellSelectedTranscriptDetailState
    public let refreshState: AppShellRefreshState
    public let safetyPolicy: LaunchSafetyPolicy

    public init(
        title: String,
        subtitle: String,
        statusMessage: String,
        configuredSourceCount: Int,
        sourceDiscoverySummary: AppShellSourceDiscoverySummary = .placeholder,
        catalogSummary: AppShellCatalogSummary = .placeholder,
        catalogQueryControls: AppShellCatalogQueryControls = .placeholder,
        navigationSummary: AppShellNavigationSummary = .placeholder,
        selectedNavigationNodeID: String = "all-chats",
        selectedNavigationTitle: String = "All Chats",
        selectedTranscriptDetail: AppShellSelectedTranscriptDetailState = .noSelection,
        readingSurface: AppShellReadingSurfaceState? = nil,
        refreshState: AppShellRefreshState = .idle,
        safetyPolicy: LaunchSafetyPolicy
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusMessage = statusMessage
        self.configuredSourceCount = configuredSourceCount
        self.sourceDiscoverySummary = sourceDiscoverySummary
        self.catalogSummary = catalogSummary
        self.catalogQueryControls = catalogQueryControls
        self.navigationSummary = navigationSummary
        self.selectedNavigationNodeID = selectedNavigationNodeID
        self.selectedNavigationTitle = selectedNavigationTitle
        self.selectedTranscriptDetail = selectedTranscriptDetail
        self.readingSurface = readingSurface ?? AppShellReadingSurfaceState.make(
            catalogTitle: selectedNavigationTitle,
            detailState: selectedTranscriptDetail
        )
        self.refreshState = refreshState
        self.safetyPolicy = safetyPolicy
    }
}
