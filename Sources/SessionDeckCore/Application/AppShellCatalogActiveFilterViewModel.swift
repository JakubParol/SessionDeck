import Foundation

public enum AppShellCatalogActiveFilterKind: Equatable, Sendable {
    case searchText
    case project
    case source
    case profile
    case parseStatus
}

public struct AppShellCatalogActiveFilter: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let kind: AppShellCatalogActiveFilterKind
    public let optionID: String?

    public init(
        id: String,
        title: String,
        kind: AppShellCatalogActiveFilterKind,
        optionID: String?
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.optionID = optionID
    }

    static func make(
        state: AppShellCatalogQueryState,
        options: AppShellCatalogFilterOptions
    ) -> [AppShellCatalogActiveFilter] {
        var filters: [AppShellCatalogActiveFilter] = []
        let trimmedSearch = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty == false {
            filters.append(
                AppShellCatalogActiveFilter(
                    id: "search",
                    title: "Search: \(trimmedSearch)",
                    kind: .searchText,
                    optionID: nil
                )
            )
        }

        filters.append(contentsOf: [
            filter(id: state.selectedProjectOptionID, kind: .project, options: options.projectOptions),
            filter(id: state.selectedSourceOptionID, kind: .source, options: options.sourceOptions),
            filter(id: state.selectedProfileOptionID, kind: .profile, options: options.profileOptions),
        ].compactMap { $0 })

        filters.append(
            contentsOf: options.parseStatusOptions
                .filter { state.selectedParseStatusOptionIDs.contains($0.id) }
                .map {
                    AppShellCatalogActiveFilter(
                        id: $0.id,
                        title: $0.title,
                        kind: .parseStatus,
                        optionID: $0.id
                    )
                }
        )

        return filters
    }

    private static func filter(
        id: String?,
        kind: AppShellCatalogActiveFilterKind,
        options: [AppShellCatalogFilterOption]
    ) -> AppShellCatalogActiveFilter? {
        guard let id, let option = options.first(where: { $0.id == id }) else {
            return nil
        }

        return AppShellCatalogActiveFilter(id: id, title: option.title, kind: kind, optionID: id)
    }
}

public extension AppShellCatalogQueryState {
    func clearing(activeFilter: AppShellCatalogActiveFilter) -> AppShellCatalogQueryState {
        switch activeFilter.kind {
        case .searchText:
            return replacing(searchText: "")
        case .project:
            return replacing(projectOptionID: nil)
        case .source:
            return replacing(sourceOptionID: nil)
        case .profile:
            return replacing(profileOptionID: nil)
        case .parseStatus:
            guard let optionID = activeFilter.optionID else {
                return self
            }
            return replacing(parseStatusOptionIDs: selectedParseStatusOptionIDs.subtracting([optionID]))
        }
    }

    func replacing(searchText: String) -> AppShellCatalogQueryState {
        AppShellCatalogQueryState(
            searchText: searchText,
            selectedProjectOptionID: selectedProjectOptionID,
            selectedSourceOptionID: selectedSourceOptionID,
            selectedProfileOptionID: selectedProfileOptionID,
            selectedParseStatusOptionIDs: selectedParseStatusOptionIDs
        )
    }

    func replacing(projectOptionID: String?) -> AppShellCatalogQueryState {
        AppShellCatalogQueryState(
            searchText: searchText,
            selectedProjectOptionID: projectOptionID,
            selectedSourceOptionID: selectedSourceOptionID,
            selectedProfileOptionID: selectedProfileOptionID,
            selectedParseStatusOptionIDs: selectedParseStatusOptionIDs
        )
    }

    func replacing(sourceOptionID: String?) -> AppShellCatalogQueryState {
        AppShellCatalogQueryState(
            searchText: searchText,
            selectedProjectOptionID: selectedProjectOptionID,
            selectedSourceOptionID: sourceOptionID,
            selectedProfileOptionID: selectedProfileOptionID,
            selectedParseStatusOptionIDs: selectedParseStatusOptionIDs
        )
    }

    func replacing(profileOptionID: String?) -> AppShellCatalogQueryState {
        AppShellCatalogQueryState(
            searchText: searchText,
            selectedProjectOptionID: selectedProjectOptionID,
            selectedSourceOptionID: selectedSourceOptionID,
            selectedProfileOptionID: profileOptionID,
            selectedParseStatusOptionIDs: selectedParseStatusOptionIDs
        )
    }

    func replacing(parseStatusOptionIDs: Set<String>) -> AppShellCatalogQueryState {
        AppShellCatalogQueryState(
            searchText: searchText,
            selectedProjectOptionID: selectedProjectOptionID,
            selectedSourceOptionID: selectedSourceOptionID,
            selectedProfileOptionID: selectedProfileOptionID,
            selectedParseStatusOptionIDs: parseStatusOptionIDs
        )
    }
}
