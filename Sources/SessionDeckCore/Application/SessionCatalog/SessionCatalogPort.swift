public protocol SessionCatalogPort: Sendable {
    func listSessions(sourceID: SessionSourceID?) throws -> [SessionSummary]
}
