public struct DiscoverSessionSourcesUseCase: Sendable {
    private let sourceDiscovery: any SourceDiscoveryPort

    public init(sourceDiscovery: any SourceDiscoveryPort) {
        self.sourceDiscovery = sourceDiscovery
    }

    public func discoverSources() throws -> [SessionSourceSummary] {
        try sourceDiscovery.discoverSources()
    }

    public func discoveryReport() throws -> SessionSourceDiscoveryReport {
        SessionSourceDiscoveryReport(sources: try discoverSources())
    }
}
