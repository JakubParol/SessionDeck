import Foundation

public struct CatalogQueryRequest: Equatable, Sendable {
    public let searchText: String
    public let project: CatalogProjectFilter?
    public let sourceID: SessionSourceID?
    public let profile: CatalogProfileFilter?
    public let parseStatuses: Set<CatalogParseStatusFilter>
    public let sort: CatalogQuerySort

    public init(
        searchText: String = "",
        project: CatalogProjectFilter? = nil,
        sourceID: SessionSourceID? = nil,
        profile: CatalogProfileFilter? = nil,
        parseStatuses: Set<CatalogParseStatusFilter> = [],
        sort: CatalogQuerySort = .lastActivityDescending
    ) {
        self.searchText = searchText
        self.project = project
        self.sourceID = sourceID
        self.profile = profile
        self.parseStatuses = parseStatuses
        self.sort = sort
    }
}

public enum CatalogProjectFilter: Equatable, Hashable, Sendable {
    case project(id: String)
    case nonProject
    case unknownProject
}

public struct CatalogProfileFilter: Equatable, Hashable, Sendable {
    public let stableID: String
    public let sourceID: SessionSourceID?

    public init(stableID: String, sourceID: SessionSourceID?) {
        self.stableID = stableID
        self.sourceID = sourceID
    }
}

public enum CatalogParseStatusFilter: Equatable, Hashable, Sendable {
    case complete
    case missingMetadata
    case malformed
    case unreadable
}

public enum CatalogQuerySort: Equatable, Sendable {
    case lastActivityDescending
}

public struct QueryCatalogUseCase: Sendable {
    private let sessionCatalog: any SessionCatalogPort

    public init(sessionCatalog: any SessionCatalogPort) {
        self.sessionCatalog = sessionCatalog
    }

    public func query(_ request: CatalogQueryRequest = CatalogQueryRequest()) throws -> [SessionSummary] {
        let candidates = try sessionCatalog.listSessions(sourceID: request.sourceID)

        return SessionCatalogOrdering.sort(
            candidates.filter { session in
                matchesSearch(session, searchText: request.searchText)
                    && matchesProject(session, filter: request.project)
                    && matchesProfile(session, filter: request.profile)
                    && matchesParseStatus(session, filters: request.parseStatuses)
            }
        )
    }

    private func matchesSearch(_ session: SessionSummary, searchText: String) -> Bool {
        let needle = searchText.trimmedForCatalogQuery.lowercased()
        guard needle.isEmpty == false else {
            return true
        }

        return searchableMetadata(for: session).contains { value in
            value.lowercased().contains(needle)
        }
    }

    private func searchableMetadata(for session: SessionSummary) -> [String] {
        [
            session.title,
            session.fallbackTitle,
            session.previewText,
            session.sessionPath,
            session.sourceLabel.sourceID,
            session.sourceLabel.displayName,
            session.sourceLabel.profileName,
            session.projectHint.cwdPath,
            session.projectHint.displayName,
            session.metadata.modelName,
            session.metadata.agentProfileName,
        ].compactMap { value in
            let trimmed = value?.trimmedForCatalogQuery
            return trimmed?.isEmpty == false ? trimmed : nil
        }
    }

    private func matchesProject(_ session: SessionSummary, filter: CatalogProjectFilter?) -> Bool {
        guard let filter else {
            return true
        }

        let group = ProjectGroupingPolicy.resolve(session: session)
        switch filter {
        case let .project(id):
            return group.kind == .project && group.id == id
        case .nonProject:
            return group.kind == .nonProject
        case .unknownProject:
            return group.kind == .unknownProject
        }
    }

    private func matchesProfile(_ session: SessionSummary, filter: CatalogProfileFilter?) -> Bool {
        guard let filter else {
            return true
        }

        let profileMetadata = SourceProfileNavigationPolicy.profileMetadata(for: session)
        return profileMetadata.stableID == filter.stableID
            && profileMetadata.sourceID == filter.sourceID
    }

    private func matchesParseStatus(
        _ session: SessionSummary,
        filters: Set<CatalogParseStatusFilter>
    ) -> Bool {
        guard filters.isEmpty == false else {
            return true
        }

        return filters.contains(CatalogParseStatusFilter(parseStatus: session.health.parseStatus))
    }
}

private extension CatalogParseStatusFilter {
    init(parseStatus: CatalogParseStatus) {
        switch parseStatus {
        case .complete:
            self = .complete
        case .missingMetadata:
            self = .missingMetadata
        case .malformed:
            self = .malformed
        case .unreadable:
            self = .unreadable
        }
    }
}

private extension String {
    var trimmedForCatalogQuery: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
