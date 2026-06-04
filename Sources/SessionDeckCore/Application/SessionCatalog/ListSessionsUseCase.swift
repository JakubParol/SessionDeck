public struct ListSessionsUseCase: Sendable {
    private let sessionCatalog: any SessionCatalogPort

    public init(sessionCatalog: any SessionCatalogPort) {
        self.sessionCatalog = sessionCatalog
    }

    public func listSessions(sourceID: SessionSourceID? = nil) throws -> [SessionSummary] {
        SessionCatalogOrdering.sort(try sessionCatalog.listSessions(sourceID: sourceID))
    }

    public func listSessions(scope: CatalogSessionScope) throws -> [SessionSummary] {
        let candidates: [SessionSummary]
        switch scope {
        case .all:
            candidates = try sessionCatalog.listSessions(sourceID: nil)
        case .sessionIDs:
            candidates = try sessionCatalog.listSessions(sourceID: nil)
        case let .source(sourceMetadata):
            candidates = try sessionCatalog.listSessions(sourceID: sourceMetadata.sourceID)
        case let .profile(profileMetadata):
            candidates = try sessionCatalog.listSessions(sourceID: profileMetadata.sourceID)
        }

        return SessionCatalogOrdering.sort(
            SourceProfileNavigationPolicy.filter(sessions: candidates, scope: scope)
        )
    }
}
