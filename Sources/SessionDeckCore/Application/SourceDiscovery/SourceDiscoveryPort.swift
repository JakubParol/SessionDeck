public protocol SourceDiscoveryPort: Sendable {
    func discoverSources() throws -> [SessionSourceSummary]
}
