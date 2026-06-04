public struct ListSessionsUseCase: Sendable {
    private let sessionCatalog: any SessionCatalogPort

    public init(sessionCatalog: any SessionCatalogPort) {
        self.sessionCatalog = sessionCatalog
    }

    public func listSessions(sourceID: SessionSourceID? = nil) throws -> [SessionSummary] {
        SessionCatalogOrdering.sort(try sessionCatalog.listSessions(sourceID: sourceID))
    }

    public func listSessions(scope: CatalogSessionScope) throws -> [SessionSummary] {
        let sessions: [SessionSummary]
        switch scope {
        case .all:
            sessions = try sessionCatalog.listSessions(sourceID: nil)
        case let .sessionIDs(sessionIDs):
            let selectedIDs = Set(sessionIDs)
            sessions = try sessionCatalog.listSessions(sourceID: nil).filter { selectedIDs.contains($0.id) }
        case let .source(sourceMetadata):
            sessions = try sessionCatalog.listSessions(sourceID: sourceMetadata.sourceID)
                .filter { SourceProfileNavigationPolicy.session($0, matches: sourceMetadata) }
        case let .profile(profileMetadata):
            sessions = try sessionCatalog.listSessions(sourceID: profileMetadata.sourceID)
                .filter { SourceProfileNavigationPolicy.session($0, matches: profileMetadata) }
        }

        return SessionCatalogOrdering.sort(sessions)
    }
}
