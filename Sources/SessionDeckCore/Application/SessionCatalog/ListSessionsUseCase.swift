public struct ListSessionsUseCase: Sendable {
    private let sessionCatalog: any SessionCatalogPort

    public init(sessionCatalog: any SessionCatalogPort) {
        self.sessionCatalog = sessionCatalog
    }

    public func listSessions(sourceID: SessionSourceID? = nil) throws -> [SessionSummary] {
        SessionCatalogOrdering.sort(try sessionCatalog.listSessions(sourceID: sourceID))
    }
}
