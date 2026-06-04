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

public struct CandidateSessionFileDiagnosticRecord: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let candidate: CandidateSessionFile
    public let diagnostic: CandidateSessionFileDiagnostic

    public init(
        sourceID: SessionSourceID,
        candidate: CandidateSessionFile,
        diagnostic: CandidateSessionFileDiagnostic
    ) {
        self.sourceID = sourceID
        self.candidate = candidate
        self.diagnostic = diagnostic
    }
}

public struct SourceHealthSummary: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let displayName: String
    public let severity: SourceDiagnosticSeverity
    public let diagnosticCode: SessionSourceDiagnosticCode?
    public let candidateDiagnosticCode: CandidateSessionFileDiagnosticCode?
    public let message: String
    public let allowsDiscoveryToContinue: Bool

    public init(
        sourceID: SessionSourceID,
        displayName: String,
        severity: SourceDiagnosticSeverity,
        diagnosticCode: SessionSourceDiagnosticCode?,
        candidateDiagnosticCode: CandidateSessionFileDiagnosticCode? = nil,
        message: String,
        allowsDiscoveryToContinue: Bool
    ) {
        self.sourceID = sourceID
        self.displayName = displayName
        self.severity = severity
        self.diagnosticCode = diagnosticCode
        self.candidateDiagnosticCode = candidateDiagnosticCode
        self.message = message
        self.allowsDiscoveryToContinue = allowsDiscoveryToContinue
    }
}

public struct SessionSourceDiscoveryReport: Equatable, Sendable {
    public let sources: [SessionSourceSummary]
    public let diagnostics: [SessionSourceDiagnosticRecord]
    public let candidateDiagnostics: [CandidateSessionFileDiagnosticRecord]

    public var availableSources: [SessionSourceSummary] {
        sources.filter { $0.availability == .available }
    }

    public var candidateFileCount: Int {
        sources.reduce(0) { partialResult, source in
            partialResult + source.counts.transcriptFileCount
        }
    }

    public var canContinueDiscovery: Bool {
        diagnostics.allSatisfy { $0.diagnostic.allowsDiscoveryToContinue }
            && candidateDiagnostics.allSatisfy { $0.diagnostic.allowsDiscoveryToContinue }
    }

    public var healthSummaries: [SourceHealthSummary] {
        let candidateDiagnosticsBySourceID = Dictionary(grouping: candidateDiagnostics, by: \.sourceID)

        return sources.map { source in
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

            if let candidateDiagnostic = candidateDiagnosticsBySourceID[source.id]?.first {
                return SourceHealthSummary(
                    sourceID: source.id,
                    displayName: source.displayName,
                    severity: candidateDiagnostic.diagnostic.severity,
                    diagnosticCode: nil,
                    candidateDiagnosticCode: candidateDiagnostic.diagnostic.code,
                    message: candidateDiagnostic.diagnostic.message,
                    allowsDiscoveryToContinue: candidateDiagnostic.diagnostic.allowsDiscoveryToContinue
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

    public init(sources: [SessionSourceSummary], candidateFiles: [CandidateSessionFile] = []) {
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
        self.candidateDiagnostics = candidateFiles.compactMap { candidate in
            guard let diagnostic = candidate.diagnostic else {
                return nil
            }

            return CandidateSessionFileDiagnosticRecord(
                sourceID: candidate.sourceID,
                candidate: candidate,
                diagnostic: diagnostic
            )
        }
    }
}
