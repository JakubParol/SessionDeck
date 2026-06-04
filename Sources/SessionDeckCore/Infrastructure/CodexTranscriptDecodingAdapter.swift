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
    private let filesBySessionID: [SessionID: CodexTranscriptFile]

    public init(files: [CodexTranscriptFile]) {
        self.filesBySessionID = Dictionary(uniqueKeysWithValues: files.map { ($0.sessionID, $0) })
    }

    public func loadTranscript(sessionID: SessionID) throws -> TranscriptDecodeResult {
        guard let file = filesBySessionID[sessionID] else {
            throw CodexTranscriptDecodingError.transcriptUnavailable(sessionID)
        }

        let text: String
        do {
            text = try String(contentsOf: file.fileURL, encoding: .utf8)
        } catch {
            throw CodexTranscriptDecodingError.unreadableTranscript(sessionID)
        }

        var title = file.fallbackTitle
        var segments: [TranscriptSegment] = []
        var diagnostics: [TranscriptDecodeDiagnostic] = []
        var toolNamesByCallID: [String: String] = [:]

        for (lineIndex, line) in transcriptLines(from: text).enumerated() {
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

        return TranscriptDecodeResult(
            sessionID: file.sessionID,
            title: title,
            segments: segments,
            diagnostics: diagnostics,
            isPartial: diagnostics.isEmpty == false
        )
    }

    private func transcriptLines(from text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
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
        let availability = body == nil ? TranscriptToolBodyAvailability.omitted : .available
        metadata["body_availability"] = metadataValue(for: availability)

        return TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: .toolOutput(callID: event.callID),
            text: body ?? "Tool output payload unavailable.",
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
