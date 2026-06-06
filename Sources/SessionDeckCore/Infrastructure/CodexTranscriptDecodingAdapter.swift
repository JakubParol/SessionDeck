import Foundation

public struct CodexTranscriptFile: Equatable, Sendable {
    public let sessionID: SessionID
    public let fileURL: URL
    public let source: TranscriptSegmentSourceReference
    public let fallbackTitle: String

    public init(
        sessionID: SessionID,
        fileURL: URL,
        source: TranscriptSegmentSourceReference,
        fallbackTitle: String
    ) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.source = source
        self.fallbackTitle = fallbackTitle
    }
}

public struct CodexTranscriptDecodingAdapter: TranscriptDecodingPort, Sendable {
    public static let defaultMaximumToolBodyCharacters = 240
    public static let defaultMaximumTranscriptBytes = 2 * 1024 * 1024

    private let filesBySessionID: [SessionID: CodexTranscriptFile]
    private let maximumToolBodyCharacters: Int
    private let maximumTranscriptBytes: Int

    public init(
        files: [CodexTranscriptFile],
        maximumToolBodyCharacters: Int = Self.defaultMaximumToolBodyCharacters,
        maximumTranscriptBytes: Int = Self.defaultMaximumTranscriptBytes
    ) {
        self.filesBySessionID = Dictionary(uniqueKeysWithValues: files.map { ($0.sessionID, $0) })
        self.maximumToolBodyCharacters = max(0, maximumToolBodyCharacters)
        self.maximumTranscriptBytes = max(0, maximumTranscriptBytes)
    }

    public func loadTranscript(sessionID: SessionID) throws -> TranscriptDecodeResult {
        guard let file = filesBySessionID[sessionID] else {
            throw CodexTranscriptDecodingError.transcriptUnavailable(sessionID)
        }

        guard let boundedRead = boundedTranscriptData(at: file.fileURL) else {
            throw CodexTranscriptDecodingError.unreadableTranscript(sessionID)
        }
        let text = String(decoding: boundedRead.data, as: UTF8.self)

        var title = file.fallbackTitle
        var segments: [TranscriptSegment] = []
        var diagnostics: [TranscriptDecodeDiagnostic] = []
        var toolNamesByCallID: [String: String] = [:]
        var recordedMissingSessionMetadata = false
        var recordedUnsupportedEventTypes: Set<String> = []

        for (lineIndex, line) in transcriptLines(from: text, isBoundedRead: boundedRead.reachedByteLimit).enumerated() {
            let lineNumber = lineIndex + 1
            let source = file.source.withLineNumber(lineNumber)
            guard let event = CodexTranscriptJSONEvent(line: line) else {
                segments.append(
                    malformedSegment(file: file, source: source, orderIndex: segments.count)
                )
                diagnostics.append(
                    TranscriptDecodeDiagnostic(
                        code: "codex.malformed_jsonl",
                        severity: .warning,
                        message: "A Codex transcript line could not be decoded as JSON.",
                        source: source,
                        allowsDecodingToContinue: true
                    )
                )
                continue
            }

            if event.type == "session_meta" {
                title = event.payloadString("title") ?? title
                if recordedMissingSessionMetadata == false,
                   missingSessionMetadataKeys(in: event).isEmpty == false {
                    recordedMissingSessionMetadata = true
                    diagnostics.append(
                        TranscriptDecodeDiagnostic(
                            code: "codex.missing_metadata",
                            severity: .warning,
                            message: "Session metadata is incomplete; SessionDeck is using safe fallback labels.",
                            source: source,
                            allowsDecodingToContinue: true
                        )
                    )
                }
                continue
            }

            if let segment = supportedSegment(
                from: event,
                file: file,
                source: source,
                orderIndex: segments.count,
                toolNamesByCallID: &toolNamesByCallID
            ) {
                segments.append(segment)
            } else if event.type != "turn_context" {
                if recordedUnsupportedEventTypes.insert(event.type).inserted {
                    segments.append(
                        unsupportedSegment(from: event, file: file, source: source, orderIndex: segments.count)
                    )
                    diagnostics.append(
                        TranscriptDecodeDiagnostic(
                            code: "codex.unsupported_event",
                            severity: .info,
                            message: "A Codex transcript event is not mapped to a readable segment yet.",
                            source: source,
                            allowsDecodingToContinue: true
                        )
                    )
                }
            }
        }

        if boundedRead.reachedByteLimit {
            diagnostics.append(
                TranscriptDecodeDiagnostic(
                    code: "codex.bounded_read_truncated",
                    severity: .warning,
                    message: "SessionDeck loaded a bounded preview of this large transcript to keep the app responsive.",
                    source: file.source,
                    allowsDecodingToContinue: true
                )
            )
        }

        return TranscriptDecodeResult(
            sessionID: file.sessionID,
            title: title,
            segments: segments,
            diagnostics: diagnostics,
            isPartial: diagnostics.isEmpty == false
        )
    }

    private func boundedTranscriptData(at url: URL) -> CodexTranscriptBoundedRead? {
        guard maximumTranscriptBytes > 0,
              let fileHandle = try? FileHandle(forReadingFrom: url)
        else {
            return nil
        }
        defer {
            try? fileHandle.close()
        }

        guard let data = try? fileHandle.read(upToCount: maximumTranscriptBytes) else {
            return nil
        }
        let fileByteSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? data.count
        return CodexTranscriptBoundedRead(
            data: data,
            reachedByteLimit: fileByteSize > maximumTranscriptBytes
        )
    }

    private func transcriptLines(from text: String, isBoundedRead: Bool) -> [String] {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if isBoundedRead, text.hasSuffix("\n") == false, lines.isEmpty == false {
            lines.removeLast()
        }
        return lines
    }

    private func missingSessionMetadataKeys(in event: CodexTranscriptJSONEvent) -> [String] {
        ["id", "title", "source", "cwd", "project"].filter { event.payload.keys.contains($0) == false }
    }

    private func supportedSegment(
        from event: CodexTranscriptJSONEvent,
        file: CodexTranscriptFile,
        source: TranscriptSegmentSourceReference,
        orderIndex: Int,
        toolNamesByCallID: inout [String: String]
    ) -> TranscriptSegment? {
        if event.isToolCall {
            let segment = toolCallSegment(from: event, file: file, source: source, orderIndex: orderIndex)
            if let callID = event.callID {
                toolNamesByCallID[callID] = event.toolName ?? "unknown_tool"
            }
            return segment
        }

        if event.isToolOutput {
            let displayLabel = event.callID.flatMap { toolNamesByCallID[$0] } ?? "tool output"
            return toolOutputSegment(
                from: event,
                file: file,
                source: source,
                orderIndex: orderIndex,
                displayLabel: displayLabel
            )
        }

        guard let role = event.supportedMessageRole,
              let text = event.messageText
        else {
            return nil
        }

        let kind: TranscriptSegmentKind = role == "user" ? .userMessage : .assistantMessage
        return TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: kind,
            text: text,
            order: TranscriptSegmentOrder(index: orderIndex),
            source: source,
            timestampDescription: event.timestamp,
            metadata: [
                "content_type": event.messageContentType,
                "event_type": event.type,
                "line_number": String(source.lineNumber ?? 0),
                "role": role,
            ]
        )
    }

    private func toolCallSegment(
        from event: CodexTranscriptJSONEvent,
        file: CodexTranscriptFile,
        source: TranscriptSegmentSourceReference,
        orderIndex: Int
    ) -> TranscriptSegment {
        let toolName = event.toolName ?? "unknown_tool"
        var metadata = baseMetadata(from: event, source: source)
        metadata["payload_type"] = event.payloadType ?? "function_call"
        metadata["tool_name"] = toolName
        if let callID = event.callID {
            metadata["call_id"] = callID
        }
        if let status = event.status {
            metadata["status"] = status
        }
        let body = event.toolCallText
        let availability = body == nil ? TranscriptToolBodyAvailability.omitted : .available
        metadata["body_availability"] = metadataValue(for: availability)

        return TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: .toolCall(name: toolName, callID: event.callID),
            text: body ?? "Tool call: \(toolName)",
            order: TranscriptSegmentOrder(index: orderIndex),
            source: source,
            timestampDescription: event.timestamp,
            metadata: metadata,
            toolMetadata: toolMetadata(
                displayLabel: toolName,
                status: event.status,
                bodyAvailability: availability,
                body: body
            )
        )
    }

    private func toolOutputSegment(
        from event: CodexTranscriptJSONEvent,
        file: CodexTranscriptFile,
        source: TranscriptSegmentSourceReference,
        orderIndex: Int,
        displayLabel: String
    ) -> TranscriptSegment {
        var metadata = baseMetadata(from: event, source: source)
        metadata["payload_type"] = event.payloadType ?? "function_call_output"
        if let callID = event.callID {
            metadata["call_id"] = callID
        }
        if let status = event.status {
            metadata["status"] = status
        }
        let body = event.toolOutputText
        let boundedBody = boundedToolBody(body, maximumCharacters: maximumToolBodyCharacters)
        let availability = boundedBody.availability
        metadata["body_availability"] = metadataValue(for: availability)

        return TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: .toolOutput(callID: event.callID),
            text: boundedBody.text ?? "Tool output payload unavailable.",
            order: TranscriptSegmentOrder(index: orderIndex),
            source: source,
            timestampDescription: event.timestamp,
            metadata: metadata,
            toolMetadata: toolMetadata(
                displayLabel: displayLabel,
                status: event.status,
                bodyAvailability: availability,
                body: body
            )
        )
    }

    private func malformedSegment(
        file: CodexTranscriptFile,
        source: TranscriptSegmentSourceReference,
        orderIndex: Int
    ) -> TranscriptSegment {
        TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: .error(code: "codex.malformed_jsonl"),
            text: "Malformed Codex JSONL line.",
            order: TranscriptSegmentOrder(index: orderIndex),
            source: source,
            timestampDescription: nil,
            metadata: [
                "event_type": "malformed_jsonl",
                "line_number": String(source.lineNumber ?? 0),
            ]
        )
    }

    private func unsupportedSegment(
        from event: CodexTranscriptJSONEvent,
        file: CodexTranscriptFile,
        source: TranscriptSegmentSourceReference,
        orderIndex: Int
    ) -> TranscriptSegment {
        TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: .unknown(eventType: event.type),
            text: "Unsupported Codex event: \(event.type)",
            order: TranscriptSegmentOrder(index: orderIndex),
            source: source,
            timestampDescription: event.timestamp,
            metadata: [
                "event_type": event.type,
                "line_number": String(source.lineNumber ?? 0),
            ]
        )
    }

    private func baseMetadata(
        from event: CodexTranscriptJSONEvent,
        source: TranscriptSegmentSourceReference
    ) -> [String: String] {
        [
            "event_type": event.type,
            "line_number": String(source.lineNumber ?? 0),
        ]
    }
}

public enum CodexTranscriptDecodingError: Error, Equatable, Sendable {
    case transcriptUnavailable(SessionID)
    case unreadableTranscript(SessionID)
}

private struct CodexTranscriptBoundedRead {
    let data: Data
    let reachedByteLimit: Bool
}
