public struct PlaceholderSessionCatalogAdapter: SessionCatalogPort, Sendable {
    public init() {}

    public func listSessions(sourceID: SessionSourceID?) throws -> [SessionSummary] {
        []
    }
}
