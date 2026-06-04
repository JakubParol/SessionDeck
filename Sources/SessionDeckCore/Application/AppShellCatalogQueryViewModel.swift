import Foundation

public struct AppShellCatalogQueryState: Equatable, Sendable {
    public static let empty = AppShellCatalogQueryState()

    public let searchText: String
    public let selectedProjectOptionID: String?
    public let selectedSourceOptionID: String?
    public let selectedProfileOptionID: String?
    public let selectedParseStatusOptionIDs: Set<String>

    public init(
        searchText: String = "",
        selectedProjectOptionID: String? = nil,
        selectedSourceOptionID: String? = nil,
        selectedProfileOptionID: String? = nil,
        selectedParseStatusOptionIDs: Set<String> = []
    ) {
        self.searchText = searchText
        self.selectedProjectOptionID = selectedProjectOptionID
        self.selectedSourceOptionID = selectedSourceOptionID
        self.selectedProfileOptionID = selectedProfileOptionID
        self.selectedParseStatusOptionIDs = selectedParseStatusOptionIDs
    }

    public var hasActiveFilters: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || selectedProjectOptionID != nil
            || selectedSourceOptionID != nil
            || selectedProfileOptionID != nil
            || selectedParseStatusOptionIDs.isEmpty == false
    }

    public func cleared() -> AppShellCatalogQueryState {
        .empty
    }

    func validated(against controls: AppShellCatalogFilterOptions) -> AppShellCatalogQueryState {
        AppShellCatalogQueryState(
            searchText: searchText,
            selectedProjectOptionID: controls.projectOptions.containsID(selectedProjectOptionID),
            selectedSourceOptionID: controls.sourceOptions.containsID(selectedSourceOptionID),
            selectedProfileOptionID: controls.profileOptions.containsID(selectedProfileOptionID),
            selectedParseStatusOptionIDs: selectedParseStatusOptionIDs.intersection(
                Set(controls.parseStatusOptions.map(\.id))
            )
        )
    }
}

public struct AppShellCatalogFilterOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let count: Int

    public init(id: String, title: String, count: Int) {
        self.id = id
        self.title = title
        self.count = count
    }

    public var menuTitle: String {
        "\(title) (\(count))"
    }
}

public struct AppShellCatalogFilterOptions: Equatable, Sendable {
    public static let empty = AppShellCatalogFilterOptions(
        projectOptions: [],
        sourceOptions: [],
        profileOptions: [],
        parseStatusOptions: []
    )

    public let projectOptions: [AppShellCatalogFilterOption]
    public let sourceOptions: [AppShellCatalogFilterOption]
    public let profileOptions: [AppShellCatalogFilterOption]
    public let parseStatusOptions: [AppShellCatalogFilterOption]

    public init(
        projectOptions: [AppShellCatalogFilterOption],
        sourceOptions: [AppShellCatalogFilterOption],
        profileOptions: [AppShellCatalogFilterOption],
        parseStatusOptions: [AppShellCatalogFilterOption]
    ) {
        self.projectOptions = projectOptions
        self.sourceOptions = sourceOptions
        self.profileOptions = profileOptions
        self.parseStatusOptions = parseStatusOptions
    }
}

public struct AppShellCatalogQueryControls: Equatable, Sendable {
    public static let placeholder = AppShellCatalogQueryControls(
        queryState: .empty,
        options: .empty,
        request: CatalogQueryRequest(),
        activeFilters: [],
        activeFilterLabels: []
    )

    public let queryState: AppShellCatalogQueryState
    public let options: AppShellCatalogFilterOptions
    public let request: CatalogQueryRequest
    public let activeFilters: [AppShellCatalogActiveFilter]
    public let activeFilterLabels: [String]

    public init(
        queryState: AppShellCatalogQueryState,
        options: AppShellCatalogFilterOptions,
        request: CatalogQueryRequest,
        activeFilters: [AppShellCatalogActiveFilter],
        activeFilterLabels: [String]
    ) {
        self.queryState = queryState
        self.options = options
        self.request = request
        self.activeFilters = activeFilters
        self.activeFilterLabels = activeFilterLabels
    }

    public var hasActiveFilters: Bool {
        queryState.hasActiveFilters
    }

    public static func make(
        sessions: [SessionSummary],
        queryState: AppShellCatalogQueryState
    ) -> AppShellCatalogQueryControls {
        let catalogOptions = CatalogQueryEvaluation.filterOptions(for: sessions)
        let options = AppShellCatalogFilterOptions(catalogOptions: catalogOptions)
        let validatedState = queryState.validated(against: options)
        let request = CatalogQueryRequest(state: validatedState, catalogOptions: catalogOptions)
        let activeFilters = AppShellCatalogActiveFilter.make(state: validatedState, options: options)

        return AppShellCatalogQueryControls(
            queryState: validatedState,
            options: options,
            request: request,
            activeFilters: activeFilters,
            activeFilterLabels: activeFilters.map(\.title)
        )
    }
}
