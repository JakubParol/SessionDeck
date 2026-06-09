import Foundation

public struct CodexCatalogScanLimits: Equatable, Sendable {
    public let maximumBytes: Int
    public let maximumLines: Int

    public init(maximumBytes: Int = 256 * 1024, maximumLines: Int = 128) {
        self.maximumBytes = maximumBytes
        self.maximumLines = maximumLines
    }
}

public struct CodexSessionCatalogAdapter: CatalogMetadataExtractionPort, SessionCatalogPort, Sendable {
    private let sourceDiscovery: any SourceDiscoveryPort
    private let candidateFileEnumeration: any CandidateSessionFileEnumerationPort
    private let scanLimits: CodexCatalogScanLimits
    private let scanCache: CodexCatalogScanCache

    public init(
        sourceDiscovery: any SourceDiscoveryPort,
        candidateFileEnumeration: any CandidateSessionFileEnumerationPort,
        scanLimits: CodexCatalogScanLimits = CodexCatalogScanLimits()
    ) {
        self.sourceDiscovery = sourceDiscovery
        self.candidateFileEnumeration = candidateFileEnumeration
        self.scanLimits = scanLimits
        self.scanCache = CodexCatalogScanCache()
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

    public func extractSessions(source: SessionSourceSummary) throws -> CatalogSourceExtractionResult {
        CatalogSourceExtractionResult(
            sourceID: source.id,
            sessions: try listSessions(sourceID: source.id)
        )
    }

    private func summary(
        for candidate: CandidateSessionFile,
        sourceLabelsByID: [SessionSourceID: CatalogSourceLabel]
    ) throws -> SessionSummary {
        let scanResult = scanCache.scanResult(
            for: candidate,
            scanLimits: scanLimits
        ) {
            CodexCatalogScanner(scanLimits: scanLimits).scan(candidate: candidate)
        }
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
                agentProfileName: scanResult.metadata.source,
                parentThreadID: parsedSessionID(from: scanResult.metadata.parentThreadID),
                forkedFromID: parsedSessionID(from: scanResult.metadata.forkedFromID),
                threadSource: trimmed(scanResult.metadata.threadSource),
                agentNickname: trimmed(scanResult.metadata.agentNickname),
                agentRole: trimmed(scanResult.metadata.agentRole),
                agentPath: trimmed(scanResult.metadata.agentPath)
            ),
            health: CatalogEntryHealth(parseStatus: scanResult.parseStatus, diagnostics: scanResult.diagnostics)
        )
    }

    private func projectHint(for metadata: CodexCatalogMetadata) -> CatalogProjectHint {
        if let project = trimmed(metadata.project), project.isEmpty == false {
            return CatalogProjectHint(cwdPath: metadata.cwd, displayName: project)
        }

        guard let cwd = trimmed(metadata.cwd),
              cwd.isEmpty == false,
              let projectName = projectName(from: cwd)
        else {
            return .unavailable
        }

        return CatalogProjectHint(cwdPath: cwd, displayName: projectName)
    }

    private func projectName(from cwd: String) -> String? {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? nil : name
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fallbackSessionID(for candidate: CandidateSessionFile) -> String {
        URL(fileURLWithPath: candidate.absolutePath).deletingPathExtension().lastPathComponent
    }

    private func parsedSessionID(from value: String?) -> SessionID? {
        trimmed(value).map(SessionID.init(rawValue:))
    }

    private func epochSeconds(from date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970)
    }
}

private final class CodexCatalogScanCache: @unchecked Sendable {
    private var scanResultsByKey: [CodexCatalogScanCacheKey: CodexCatalogScanResult] = [:]
    private let lock = NSLock()

    func scanResult(
        for candidate: CandidateSessionFile,
        scanLimits: CodexCatalogScanLimits,
        load: () -> CodexCatalogScanResult
    ) -> CodexCatalogScanResult {
        let key = CodexCatalogScanCacheKey(candidate: candidate, scanLimits: scanLimits)

        lock.lock()
        if let cached = scanResultsByKey[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let loaded = load()

        lock.lock()
        scanResultsByKey[key] = loaded
        lock.unlock()

        return loaded
    }
}

private struct CodexCatalogScanCacheKey: Hashable, Sendable {
    let sourceID: SessionSourceID
    let relativePath: String
    let absolutePath: String
    let byteSize: Int64
    let modifiedAt: Date?
    let maximumBytes: Int
    let maximumLines: Int
    let diagnosticCode: CandidateSessionFileDiagnosticCode?
    let diagnosticMessage: String?

    init(candidate: CandidateSessionFile, scanLimits: CodexCatalogScanLimits) {
        self.sourceID = candidate.sourceID
        self.relativePath = candidate.relativePath
        self.absolutePath = candidate.absolutePath
        self.byteSize = candidate.byteSize
        self.modifiedAt = candidate.modifiedAt
        self.maximumBytes = scanLimits.maximumBytes
        self.maximumLines = scanLimits.maximumLines
        self.diagnosticCode = candidate.diagnostic?.code
        self.diagnosticMessage = candidate.diagnostic?.message
    }
}
