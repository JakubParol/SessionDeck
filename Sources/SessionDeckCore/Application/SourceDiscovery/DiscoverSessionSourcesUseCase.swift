public struct DiscoverSessionSourcesUseCase: Sendable {
    private let sourceDiscovery: any SourceDiscoveryPort
    private let candidateFileEnumeration: (any CandidateSessionFileEnumerationPort)?

    public init(
        sourceDiscovery: any SourceDiscoveryPort,
        candidateFileEnumeration: (any CandidateSessionFileEnumerationPort)? = nil
    ) {
        self.sourceDiscovery = sourceDiscovery
        self.candidateFileEnumeration = candidateFileEnumeration
    }

    public func discoverSources() throws -> [SessionSourceSummary] {
        try sourceDiscovery.discoverSources()
    }

    public func discoveryReport() throws -> SessionSourceDiscoveryReport {
        let sources = try discoverSources()
        let candidateFiles = try candidateFileEnumeration?.enumerateCandidateFiles(sourceID: nil) ?? []
        return SessionSourceDiscoveryReport(sources: sources, candidateFiles: candidateFiles)
    }
}
