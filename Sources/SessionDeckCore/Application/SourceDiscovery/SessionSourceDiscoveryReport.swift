public struct SessionSourceDiagnosticRecord: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let displayName: String
    public let diagnostic: SessionSourceDiagnostic

    public init(sourceID: SessionSourceID, displayName: String, diagnostic: SessionSourceDiagnostic) {
        self.sourceID = sourceID
        self.displayName = displayName
        self.diagnostic = diagnostic
    }
}

public struct SessionSourceDiscoveryReport: Equatable, Sendable {
    public let sources: [SessionSourceSummary]
    public let diagnostics: [SessionSourceDiagnosticRecord]

    public var availableSources: [SessionSourceSummary] {
        sources.filter { $0.availability == .available }
    }

    public var canContinueDiscovery: Bool {
        diagnostics.allSatisfy { $0.diagnostic.allowsDiscoveryToContinue }
    }

    public init(sources: [SessionSourceSummary]) {
        self.sources = sources
        self.diagnostics = sources.compactMap { source in
            guard let diagnostic = source.diagnostic else {
                return nil
            }

            return SessionSourceDiagnosticRecord(
                sourceID: source.id,
                displayName: source.displayName,
                diagnostic: diagnostic
            )
        }
    }
}
