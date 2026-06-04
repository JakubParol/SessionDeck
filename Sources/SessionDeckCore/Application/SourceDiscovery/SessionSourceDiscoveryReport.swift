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

public struct SourceHealthSummary: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let displayName: String
    public let severity: SourceDiagnosticSeverity
    public let diagnosticCode: SessionSourceDiagnosticCode?
    public let message: String
    public let allowsDiscoveryToContinue: Bool

    public init(
        sourceID: SessionSourceID,
        displayName: String,
        severity: SourceDiagnosticSeverity,
        diagnosticCode: SessionSourceDiagnosticCode?,
        message: String,
        allowsDiscoveryToContinue: Bool
    ) {
        self.sourceID = sourceID
        self.displayName = displayName
        self.severity = severity
        self.diagnosticCode = diagnosticCode
        self.message = message
        self.allowsDiscoveryToContinue = allowsDiscoveryToContinue
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

    public var healthSummaries: [SourceHealthSummary] {
        sources.map { source in
            if let diagnostic = source.diagnostic {
                return SourceHealthSummary(
                    sourceID: source.id,
                    displayName: source.displayName,
                    severity: diagnostic.severity,
                    diagnosticCode: diagnostic.code,
                    message: diagnostic.message,
                    allowsDiscoveryToContinue: diagnostic.allowsDiscoveryToContinue
                )
            }

            return SourceHealthSummary(
                sourceID: source.id,
                displayName: source.displayName,
                severity: .info,
                diagnosticCode: nil,
                message: "Source is available with \(source.counts.transcriptFileCount) candidate transcript files.",
                allowsDiscoveryToContinue: true
            )
        }
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
