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
        let scanResult = scan(candidate: candidate)
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
            health: CatalogEntryHealth(parseStatus: scanResult.parseStatus)
        )
    }

    private func scan(candidate: CandidateSessionFile) -> CodexCatalogScanResult {
        if let diagnostic = candidate.diagnostic {
            return CodexCatalogScanResult(
                metadata: CodexCatalogMetadata(),
                createdAtEpochSeconds: candidate.modifiedAt.map(epochSeconds),
                lastActivityEpochSeconds: candidate.modifiedAt.map(epochSeconds),
                parseStatus: .unreadable(reason: diagnostic.message)
            )
        }

        guard let boundedRead = boundedData(at: candidate.absolutePath, fileByteSize: candidate.byteSize) else {
            return CodexCatalogScanResult(
                metadata: CodexCatalogMetadata(),
                createdAtEpochSeconds: candidate.modifiedAt.map(epochSeconds),
                lastActivityEpochSeconds: candidate.modifiedAt.map(epochSeconds),
                parseStatus: .unreadable(reason: "Candidate transcript file could not be read.")
            )
        }

        let content = String(decoding: boundedRead.data, as: UTF8.self)
        let lines = Array(content.split(separator: "\n", omittingEmptySubsequences: true).prefix(scanLimits.maximumLines))
        var metadata = CodexCatalogMetadata()
        var createdAtEpochSeconds: Int64?
        var lastActivityEpochSeconds: Int64?
        var encounteredMalformedLine = false

        for (index, line) in lines.enumerated() {
            guard let event = decodeEvent(line: String(line)) else {
                if !isFinalByteLimitFragment(index: index, lineCount: lines.count, content: content, read: boundedRead) {
                    encounteredMalformedLine = true
                }
                continue
            }

            if let timestamp = event.timestampEpochSeconds {
                createdAtEpochSeconds = createdAtEpochSeconds ?? timestamp
                lastActivityEpochSeconds = timestamp
            }

            if event.type == "session_meta" {
                metadata.apply(payload: event.payload)
            }
        }

        return CodexCatalogScanResult(
            metadata: metadata,
            createdAtEpochSeconds: createdAtEpochSeconds,
            lastActivityEpochSeconds: lastActivityEpochSeconds,
            parseStatus: parseStatus(metadata: metadata, encounteredMalformedLine: encounteredMalformedLine)
        )
    }

    private func boundedData(at path: String, fileByteSize: Int64) -> CodexCatalogBoundedRead? {
        guard scanLimits.maximumBytes > 0,
              let fileHandle = FileHandle(forReadingAtPath: path)
        else {
            return nil
        }
        defer {
            try? fileHandle.close()
        }
        guard let data = try? fileHandle.read(upToCount: scanLimits.maximumBytes) else {
            return nil
        }
        return CodexCatalogBoundedRead(data: data, reachedByteLimit: fileByteSize > Int64(scanLimits.maximumBytes))
    }

    private func isFinalByteLimitFragment(
        index: Int,
        lineCount: Int,
        content: String,
        read: CodexCatalogBoundedRead
    ) -> Bool {
        read.reachedByteLimit && index == lineCount - 1 && !content.hasSuffix("\n")
    }

    private func decodeEvent(line: String) -> CodexCatalogEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let timestamp = (object["timestamp"] as? String).flatMap(epochSeconds)
        return CodexCatalogEvent(
            type: object["type"] as? String,
            timestampEpochSeconds: timestamp,
            payload: object["payload"] as? [String: Any]
        )
    }

    private func parseStatus(metadata: CodexCatalogMetadata, encounteredMalformedLine: Bool) -> CatalogParseStatus {
        if encounteredMalformedLine {
            return .malformed(reason: "Encountered malformed JSONL while scanning bounded catalog metadata.")
        }
        if metadata.id == nil || metadata.title == nil || metadata.project == nil || metadata.cwd == nil {
            return .missingMetadata
        }
        return .complete
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

    private func epochSeconds(from timestamp: String) -> Int64? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestamp) {
            return epochSeconds(from: date)
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: timestamp).map(epochSeconds)
    }
}

private struct CodexCatalogScanResult {
    let metadata: CodexCatalogMetadata
    let createdAtEpochSeconds: Int64?
    let lastActivityEpochSeconds: Int64?
    let parseStatus: CatalogParseStatus
}

private struct CodexCatalogBoundedRead {
    let data: Data
    let reachedByteLimit: Bool
}

private struct CodexCatalogEvent {
    let type: String?
    let timestampEpochSeconds: Int64?
    let payload: [String: Any]?
}

private struct CodexCatalogMetadata {
    var id: String?
    var title: String?
    var project: String?
    var cwd: String?
    var source: String?
    var modelName: String?

    mutating func apply(payload: [String: Any]?) {
        guard let payload else {
            return
        }

        id = payload["id"] as? String ?? id
        title = payload["title"] as? String ?? title
        project = payload["project"] as? String ?? project
        cwd = payload["cwd"] as? String ?? cwd
        source = payload["source"] as? String ?? source
        modelName = payload["model"] as? String ?? payload["model_name"] as? String ?? modelName
    }
}
