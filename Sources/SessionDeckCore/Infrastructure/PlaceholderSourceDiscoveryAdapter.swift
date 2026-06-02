public struct PlaceholderSourceDiscoveryAdapter: SourceDiscoveryPort, Sendable {
    public init() {}

    public func discoverSources() throws -> [SessionSourceSummary] {
        []
    }
}
