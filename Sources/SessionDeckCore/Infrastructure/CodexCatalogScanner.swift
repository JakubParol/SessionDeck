import Foundation

struct CodexCatalogScanner: Sendable {
    private let scanLimits: CodexCatalogScanLimits

    init(scanLimits: CodexCatalogScanLimits) {
        self.scanLimits = scanLimits
    }

    func scan(candidate: CandidateSessionFile) -> CodexCatalogScanResult {
        if let diagnostic = candidate.diagnostic {
            return unreadableResult(diagnostic: diagnostic, modifiedAt: candidate.modifiedAt)
        }

        guard let boundedRead = boundedData(at: candidate.absolutePath, fileByteSize: candidate.byteSize) else {
            return unreadableResult(
                reason: "Candidate transcript file could not be read.",
                modifiedAt: candidate.modifiedAt
            )
        }

        let content = String(decoding: boundedRead.data, as: UTF8.self)
        let lines = Array(content.split(separator: "\n", omittingEmptySubsequences: true).prefix(scanLimits.maximumLines))
        var metadata = CodexCatalogMetadata()
        var createdAtEpochSeconds: Int64?
        var lastActivityEpochSeconds: Int64?
        var encounteredMalformedLine = false
        var encounteredUnknownEventShape = false

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
            } else if !isKnownCodexEventType(event.type) {
                encounteredUnknownEventShape = true
            }
        }

        let parseStatus = parseStatus(metadata: metadata, encounteredMalformedLine: encounteredMalformedLine)
        return CodexCatalogScanResult(
            metadata: metadata,
            createdAtEpochSeconds: createdAtEpochSeconds,
            lastActivityEpochSeconds: lastActivityEpochSeconds,
            parseStatus: parseStatus,
            diagnostics: diagnostics(
                parseStatus: parseStatus,
                encounteredMalformedLine: encounteredMalformedLine,
                encounteredUnknownEventShape: encounteredUnknownEventShape,
                reachedByteLimit: boundedRead.reachedByteLimit
            )
        )
    }

    private func unreadableResult(reason: String, modifiedAt: Date?) -> CodexCatalogScanResult {
        CodexCatalogScanResult(
            metadata: CodexCatalogMetadata(),
            createdAtEpochSeconds: modifiedAt.map(epochSeconds),
            lastActivityEpochSeconds: modifiedAt.map(epochSeconds),
            parseStatus: .unreadable(reason: reason),
            diagnostics: [
                CatalogEntryDiagnostic(
                    code: .unreadableFile,
                    severity: .warning,
                    message: "Candidate transcript file could not be read for catalog metadata."
                ),
            ]
        )
    }

    private func unreadableResult(
        diagnostic: CandidateSessionFileDiagnostic,
        modifiedAt: Date?
    ) -> CodexCatalogScanResult {
        let code = catalogDiagnosticCode(for: diagnostic)
        return CodexCatalogScanResult(
            metadata: CodexCatalogMetadata(),
            createdAtEpochSeconds: modifiedAt.map(epochSeconds),
            lastActivityEpochSeconds: modifiedAt.map(epochSeconds),
            parseStatus: .unreadable(reason: "Candidate transcript file could not be read."),
            diagnostics: [
                CatalogEntryDiagnostic(
                    code: code,
                    severity: .warning,
                    message: catalogDiagnosticMessage(for: code)
                ),
            ]
        )
    }

    private func catalogDiagnosticCode(for diagnostic: CandidateSessionFileDiagnostic) -> CatalogEntryDiagnosticCode {
        if diagnostic.message.localizedCaseInsensitiveContains("permission") {
            return .permissionDenied
        }

        return .unreadableFile
    }

    private func catalogDiagnosticMessage(for code: CatalogEntryDiagnosticCode) -> String {
        switch code {
        case .permissionDenied:
            return "Candidate transcript file permission was denied during catalog metadata scanning."
        case .unreadableFile:
            return "Candidate transcript file could not be read for catalog metadata."
        default:
            return "Candidate transcript produced a catalog diagnostic."
        }
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

    private func isKnownCodexEventType(_ type: String?) -> Bool {
        guard let type else {
            return false
        }

        return [
            "session_meta",
            "turn_context",
            "event_msg",
            "response_item",
        ].contains(type)
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

    private func diagnostics(
        parseStatus: CatalogParseStatus,
        encounteredMalformedLine: Bool,
        encounteredUnknownEventShape: Bool,
        reachedByteLimit: Bool
    ) -> [CatalogEntryDiagnostic] {
        var diagnostics: [CatalogEntryDiagnostic] = []

        if encounteredMalformedLine {
            diagnostics.append(
                CatalogEntryDiagnostic(
                    code: .malformedJSONL,
                    severity: .warning,
                    message: "One or more transcript lines could not be parsed during bounded catalog metadata scanning."
                )
            )
        }

        if parseStatus == .missingMetadata {
            diagnostics.append(
                CatalogEntryDiagnostic(
                    code: .missingMetadata,
                    severity: .warning,
                    message: "Catalog metadata is incomplete; SessionDeck is using safe fallback labels."
                )
            )
        }

        if encounteredUnknownEventShape {
            diagnostics.append(
                CatalogEntryDiagnostic(
                    code: .unknownEventShape,
                    severity: .warning,
                    message: "A transcript event shape is not yet recognized; known catalog metadata was preserved."
                )
            )
        }

        if reachedByteLimit {
            diagnostics.append(
                CatalogEntryDiagnostic(
                    code: .boundedReadTruncated,
                    severity: .warning,
                    message: "Catalog metadata scan stopped at the configured byte limit."
                )
            )
        }

        return diagnostics
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

struct CodexCatalogScanResult {
    let metadata: CodexCatalogMetadata
    let createdAtEpochSeconds: Int64?
    let lastActivityEpochSeconds: Int64?
    let parseStatus: CatalogParseStatus
    let diagnostics: [CatalogEntryDiagnostic]
}

struct CodexCatalogMetadata {
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

private struct CodexCatalogBoundedRead {
    let data: Data
    let reachedByteLimit: Bool
}

private struct CodexCatalogEvent {
    let type: String?
    let timestampEpochSeconds: Int64?
    let payload: [String: Any]?
}
