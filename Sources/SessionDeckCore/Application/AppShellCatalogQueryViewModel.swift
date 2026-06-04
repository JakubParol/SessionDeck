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
        activeFilterLabels: []
    )

    public let queryState: AppShellCatalogQueryState
    public let options: AppShellCatalogFilterOptions
    public let request: CatalogQueryRequest
    public let activeFilterLabels: [String]

    public init(
        queryState: AppShellCatalogQueryState,
        options: AppShellCatalogFilterOptions,
        request: CatalogQueryRequest,
        activeFilterLabels: [String]
    ) {
        self.queryState = queryState
        self.options = options
        self.request = request
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

        return AppShellCatalogQueryControls(
            queryState: validatedState,
            options: options,
            request: request,
            activeFilterLabels: activeFilterLabels(state: validatedState, options: options)
        )
    }

    private static func activeFilterLabels(
        state: AppShellCatalogQueryState,
        options: AppShellCatalogFilterOptions
    ) -> [String] {
        var labels: [String] = []
        let trimmedSearch = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty == false {
            labels.append("Search: \(trimmedSearch)")
        }

        labels.append(contentsOf: [
            options.projectOptions.title(for: state.selectedProjectOptionID),
            options.sourceOptions.title(for: state.selectedSourceOptionID),
            options.profileOptions.title(for: state.selectedProfileOptionID),
        ].compactMap { $0 })

        labels.append(
            contentsOf: options.parseStatusOptions
                .filter { state.selectedParseStatusOptionIDs.contains($0.id) }
                .map(\.title)
        )

        return labels
    }
}

private extension AppShellCatalogFilterOptions {
    init(catalogOptions: CatalogFilterOptions) {
        self.init(
            projectOptions: catalogOptions.projectOptions.map {
                AppShellCatalogFilterOption(
                    id: $0.filter.optionID,
                    title: $0.title,
                    count: $0.sessionCount
                )
            },
            sourceOptions: catalogOptions.sourceOptions.map {
                AppShellCatalogFilterOption(
                    id: $0.filter.optionID,
                    title: $0.displayName,
                    count: $0.sessionCount
                )
            },
            profileOptions: catalogOptions.profileOptions.map {
                AppShellCatalogFilterOption(
                    id: $0.filter.optionID,
                    title: $0.displayName,
                    count: $0.sessionCount
                )
            },
            parseStatusOptions: catalogOptions.parseStatusOptions.map {
                AppShellCatalogFilterOption(
                    id: $0.filter.optionID,
                    title: $0.filter.title,
                    count: $0.sessionCount
                )
            }
        )
    }
}

private extension CatalogQueryRequest {
    init(state: AppShellCatalogQueryState, catalogOptions: CatalogFilterOptions) {
        self.init(
            searchText: state.searchText,
            project: catalogOptions.projectOptions.first {
                $0.filter.optionID == state.selectedProjectOptionID
            }?.filter,
            source: catalogOptions.sourceOptions.first {
                $0.filter.optionID == state.selectedSourceOptionID
            }?.filter,
            profile: catalogOptions.profileOptions.first {
                $0.filter.optionID == state.selectedProfileOptionID
            }?.filter,
            parseStatuses: Set(
                catalogOptions.parseStatusOptions
                    .map(\.filter)
                    .filter { state.selectedParseStatusOptionIDs.contains($0.optionID) }
            )
        )
    }
}

private extension CatalogProjectFilter {
    var optionID: String {
        switch self {
        case let .project(id):
            return "project:\(id)"
        case .nonProject:
            return "project:non-project"
        case .unknownProject:
            return "project:unknown-project"
        }
    }
}

private extension CatalogSourceFilter {
    var optionID: String {
        "source:\(stableID)"
    }
}

private extension CatalogProfileFilter {
    var optionID: String {
        "profile:\(stableID)"
    }
}

private extension CatalogParseStatusFilter {
    var optionID: String {
        switch self {
        case .complete:
            return "parse:complete"
        case .missingMetadata:
            return "parse:missing-metadata"
        case .malformed:
            return "parse:malformed"
        case .unreadable:
            return "parse:unreadable"
        }
    }

    var title: String {
        switch self {
        case .complete:
            return "Healthy"
        case .missingMetadata:
            return "Missing metadata"
        case .malformed:
            return "Malformed"
        case .unreadable:
            return "Unreadable"
        }
    }
}

private extension [AppShellCatalogFilterOption] {
    func containsID(_ id: String?) -> String? {
        guard let id, contains(where: { $0.id == id }) else {
            return nil
        }

        return id
    }

    func title(for id: String?) -> String? {
        guard let id else {
            return nil
        }

        return first { $0.id == id }?.title
    }
}
