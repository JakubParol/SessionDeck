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
            } else if event.type == "turn_context" {
                metadata.applyContext(payload: event.payload)
            } else if event.type == "response_item" {
                metadata.applyInferredRepoRoot(from: event.messageText)
            } else if !isKnownCodexEventType(event.type) {
                encounteredUnknownEventShape = true
            }
        }
        metadata.applyInferredRepoRoot(from: content)

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
        if metadata.id == nil || (metadata.cwd == nil && metadata.project == nil) {
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

    mutating func applyContext(payload: [String: Any]?) {
        guard let payload else {
            return
        }

        cwd = payload["cwd"] as? String ?? cwd
    }

    mutating func applyInferredRepoRoot(from text: String?) {
        guard let repoRoot = CodexCatalogRepoRootExtractor.repoRoot(from: text) else {
            return
        }

        cwd = repoRoot
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

private extension CodexCatalogEvent {
    var messageText: String? {
        guard let payload,
              payload["type"] as? String == "message"
        else {
            return nil
        }

        if let content = payload["content"] as? String {
            return content
        }

        guard let contentItems = payload["content"] as? [[String: Any]] else {
            return nil
        }

        let text = contentItems.compactMap { item in
            item["text"] as? String
        }.joined(separator: "\n")
        return text.isEmpty ? nil : text
    }
}

private enum CodexCatalogRepoRootExtractor {
    static func repoRoot(from text: String?) -> String? {
        guard let text, text.isEmpty == false else {
            return nil
        }

        if let explicitRepoRoot = text
            .split(whereSeparator: \.isNewline)
            .compactMap({ repoRootLinePath(from: String($0)) })
            .first {
            return explicitRepoRoot
        }

        return xmlWorkspaceRootPath(from: text)
    }

    private static func repoRootLinePath(from line: String) -> String? {
        let marker = "Repo root:"
        guard let markerRange = line.range(of: marker, options: [.caseInsensitive]) else {
            return nil
        }

        let candidate = String(line[markerRange.upperBound...])
        return sanitizedRepoPath(candidate)
    }

    private static func xmlWorkspaceRootPath(from text: String) -> String? {
        let pattern = #"<root>([^<]+)</root>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let pathRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return sanitizedRepoPath(String(text[pathRange]))
    }

    private static func sanitizedRepoPath(_ rawValue: String) -> String? {
        let candidate = rawValue.truncated(beforeAnyOf: ["\\n", "\n", "\r", "<"])
        let trimmed = candidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        guard trimmed.hasPrefix("/"),
              trimmed.contains("/Repos/"),
              URL(fileURLWithPath: trimmed).lastPathComponent.isEmpty == false
        else {
            return nil
        }

        return trimmed
    }
}

private extension String {
    func truncated(beforeAnyOf delimiters: [String]) -> String {
        let firstDelimiter = delimiters
            .compactMap { delimiter in
                range(of: delimiter)?.lowerBound
            }
            .min()

        guard let firstDelimiter else {
            return self
        }

        return String(self[..<firstDelimiter])
    }
}
