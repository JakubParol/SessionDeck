import Foundation

public struct CodexCatalogScanLimits: Equatable, Sendable {
    public let maximumBytes: Int
    public let maximumLines: Int

    public init(maximumBytes: Int = 64 * 1024, maximumLines: Int = 128) {
        self.maximumBytes = maximumBytes
        self.maximumLines = maximumLines
    }
}

public struct CodexSessionCatalogAdapter: SessionCatalogPort, Sendable {
    private let sourceDiscovery: any SourceDiscoveryPort
    private let candidateFileEnumeration: any CandidateSessionFileEnumerationPort
    private let scanLimits: CodexCatalogScanLimits

    public init(
        sourceDiscovery: any SourceDiscoveryPort,
        candidateFileEnumeration: any CandidateSessionFileEnumerationPort,
        scanLimits: CodexCatalogScanLimits = CodexCatalogScanLimits()
    ) {
        self.sourceDiscovery = sourceDiscovery
        self.candidateFileEnumeration = candidateFileEnumeration
        self.scanLimits = scanLimits
    }

    public func listSessions(sourceID: SessionSourceID? = nil) throws -> [SessionSummary] {
        let sourceLabelsByID = try Dictionary(
            uniqueKeysWithValues: sourceDiscovery.discoverSources().map { source in
                (
                    source.id,
                    CatalogSourceLabel(
                        sourceID: source.id.rawValue,
                        displayName: source.displayName,
                        profileName: nil
                    )
                )
            }
        )
        return try candidateFileEnumeration.enumerateCandidateFiles(sourceID: sourceID).map { candidate in
            try summary(for: candidate, sourceLabelsByID: sourceLabelsByID)
        }
    }

    private func summary(
        for candidate: CandidateSessionFile,
        sourceLabelsByID: [SessionSourceID: CatalogSourceLabel]
    ) throws -> SessionSummary {
        let scanResult = CodexCatalogScanner(scanLimits: scanLimits).scan(candidate: candidate)
        let sessionID = scanResult.metadata.id ?? fallbackSessionID(for: candidate)
        let sourceLabel = sourceLabelsByID[candidate.sourceID]
            ?? CatalogSourceLabel(sourceID: candidate.sourceID.rawValue, displayName: candidate.sourceID.rawValue, profileName: nil)
        return SessionSummary(
            id: SessionID(rawValue: sessionID),
            sourceID: candidate.sourceID,
            sourceLabel: sourceLabel,
            title: scanResult.metadata.title,
            projectHint: projectHint(for: scanResult.metadata),
            sessionPath: candidate.absolutePath,
            activity: CatalogActivityTimestamps(
                createdAtEpochSeconds: scanResult.createdAtEpochSeconds,
                lastActivityEpochSeconds: scanResult.lastActivityEpochSeconds ?? candidate.modifiedAt.map(epochSeconds)
            ),
            fileSize: CatalogFileSize(byteCount: candidate.byteSize),
            metadata: CatalogSessionMetadata(
                modelName: scanResult.metadata.modelName,
                agentProfileName: scanResult.metadata.source
            ),
            health: CatalogEntryHealth(parseStatus: scanResult.parseStatus, diagnostics: scanResult.diagnostics)
        )
    }

    private func projectHint(for metadata: CodexCatalogMetadata) -> CatalogProjectHint {
        guard let project = metadata.project, project.isEmpty == false else {
            return .unavailable
        }
        return CatalogProjectHint(cwdPath: metadata.cwd, displayName: project)
    }

    private func fallbackSessionID(for candidate: CandidateSessionFile) -> String {
        URL(fileURLWithPath: candidate.absolutePath).deletingPathExtension().lastPathComponent
    }

    private func epochSeconds(from date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970)
    }
}
