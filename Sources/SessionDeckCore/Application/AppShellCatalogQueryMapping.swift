extension AppShellCatalogFilterOptions {
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

extension CatalogQueryRequest {
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

extension CatalogProjectFilter {
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

extension CatalogSourceFilter {
    var optionID: String {
        "source:\(stableID)"
    }
}

extension CatalogProfileFilter {
    var optionID: String {
        "profile:\(stableID)"
    }
}

extension CatalogParseStatusFilter {
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

extension [AppShellCatalogFilterOption] {
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
