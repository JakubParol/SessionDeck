import Foundation

public struct QueryCatalogUseCase: Sendable {
    private let sessionCatalog: any SessionCatalogPort

    public init(sessionCatalog: any SessionCatalogPort) {
        self.sessionCatalog = sessionCatalog
    }

    public func query(_ request: CatalogQueryRequest = CatalogQueryRequest()) throws -> [SessionSummary] {
        let candidates = try sessionCatalog.listSessions(sourceID: request.source?.sourceID ?? request.sourceID)

        return SessionCatalogOrdering.sort(
            candidates.filter { session in
                matchesSearch(session, searchText: request.searchText)
                    && matchesProject(session, filter: request.project)
                    && matchesSource(session, filter: request.source)
                    && matchesProfile(session, filter: request.profile)
                    && matchesParseStatus(session, filters: request.parseStatuses)
            }
        )
    }

    public func filterOptions() throws -> CatalogFilterOptions {
        let sessions = try sessionCatalog.listSessions(sourceID: nil)

        return CatalogFilterOptions(
            projectOptions: projectOptions(for: sessions),
            sourceOptions: sourceOptions(for: sessions),
            profileOptions: profileOptions(for: sessions),
            parseStatusOptions: parseStatusOptions(for: sessions)
        )
    }

    private func projectOptions(for sessions: [SessionSummary]) -> [CatalogProjectFilterOption] {
        ProjectGroupingPolicy.resolve(sessions: sessions).map { group in
            CatalogProjectFilterOption(
                filter: projectFilter(for: group),
                title: group.title,
                sessionCount: group.sessionIDs.count
            )
        }
    }

    private func projectFilter(for group: ProjectNavigationGroup) -> CatalogProjectFilter {
        switch group.kind {
        case .project:
            return .project(id: group.id)
        case .nonProject:
            return .nonProject
        case .unknownProject:
            return .unknownProject
        }
    }

    private func sourceOptions(for sessions: [SessionSummary]) -> [CatalogSourceFilterOption] {
        var optionsByStableID: [String: CatalogSourceFilterOption] = [:]

        for session in sessions {
            let metadata = SourceProfileNavigationPolicy.sourceMetadata(for: session)
            let existingCount = optionsByStableID[metadata.stableID]?.sessionCount ?? 0
            optionsByStableID[metadata.stableID] = CatalogSourceFilterOption(
                stableID: metadata.stableID,
                sourceID: metadata.sourceID,
                displayName: metadata.displayName,
                isFallback: metadata.isFallback,
                sessionCount: existingCount + 1
            )
        }

        return optionsByStableID.values.sorted { $0.stableID < $1.stableID }
    }

    private func profileOptions(for sessions: [SessionSummary]) -> [CatalogProfileFilterOption] {
        var optionsByStableID: [String: CatalogProfileFilterOption] = [:]

        for session in sessions {
            let metadata = SourceProfileNavigationPolicy.profileMetadata(for: session)
            let existingCount = optionsByStableID[metadata.stableID]?.sessionCount ?? 0
            optionsByStableID[metadata.stableID] = CatalogProfileFilterOption(
                filter: CatalogProfileFilter(
                    stableID: metadata.stableID,
                    sourceID: metadata.sourceID
                ),
                sourceStableID: metadata.sourceStableID,
                displayName: metadata.displayName,
                isFallback: metadata.isFallback,
                sessionCount: existingCount + 1
            )
        }

        return optionsByStableID.values.sorted { $0.filter.stableID < $1.filter.stableID }
    }

    private func parseStatusOptions(for sessions: [SessionSummary]) -> [CatalogParseStatusFilterOption] {
        let counts = Dictionary(
            grouping: sessions,
            by: { CatalogParseStatusFilter(parseStatus: $0.health.parseStatus) }
        ).mapValues(\.count)

        return CatalogParseStatusFilter.orderedCases.compactMap { filter in
            guard let count = counts[filter] else {
                return nil
            }

            return CatalogParseStatusFilterOption(filter: filter, sessionCount: count)
        }
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

    private func matchesSource(_ session: SessionSummary, filter: CatalogSourceFilter?) -> Bool {
        guard let filter else {
            return true
        }

        let sourceMetadata = SourceProfileNavigationPolicy.sourceMetadata(for: session)
        return sourceMetadata.stableID == filter.stableID
            && sourceMetadata.sourceID == filter.sourceID
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
    static let orderedCases: [CatalogParseStatusFilter] = [
        .complete,
        .missingMetadata,
        .malformed,
        .unreadable,
    ]

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
