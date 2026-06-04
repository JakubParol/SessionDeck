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

            if let segment = supportedSegment(from: event, file: file, source: source, orderIndex: segments.count) {
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
        orderIndex: Int
    ) -> TranscriptSegment? {
        if event.isToolCall {
            return toolCallSegment(from: event, file: file, source: source, orderIndex: orderIndex)
        }

        if event.isToolOutput {
            return toolOutputSegment(from: event, file: file, source: source, orderIndex: orderIndex)
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

        return TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: .toolCall(name: toolName, callID: event.callID),
            text: event.toolCallText ?? "Tool call: \(toolName)",
            order: TranscriptSegmentOrder(index: orderIndex),
            source: source,
            timestampDescription: event.timestamp,
            metadata: metadata
        )
    }

    private func toolOutputSegment(
        from event: CodexTranscriptJSONEvent,
        file: CodexTranscriptFile,
        source: TranscriptSegmentSourceReference,
        orderIndex: Int
    ) -> TranscriptSegment {
        var metadata = baseMetadata(from: event, source: source)
        metadata["payload_type"] = event.payloadType ?? "function_call_output"
        if let callID = event.callID {
            metadata["call_id"] = callID
        }
        if let status = event.status {
            metadata["status"] = status
        }

        return TranscriptSegment(
            id: "\(file.sessionID.rawValue)-line-\(source.lineNumber ?? 0)",
            kind: .toolOutput(callID: event.callID),
            text: event.toolOutputText ?? "Tool output payload unavailable.",
            order: TranscriptSegmentOrder(index: orderIndex),
            source: source,
            timestampDescription: event.timestamp,
            metadata: metadata
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

private struct CodexTranscriptJSONEvent {
    let type: String
    let timestamp: String?
    let payload: [String: Any]

    init?(line: String) {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else {
            return nil
        }

        self.type = type
        self.timestamp = object["timestamp"] as? String
        self.payload = object["payload"] as? [String: Any] ?? [:]
    }

    var supportedMessageRole: String? {
        let role = payload["role"] as? String
        guard role == "user" || role == "assistant" else {
            return nil
        }

        if let payloadType = payload["type"] as? String, payloadType != "message" {
            return nil
        }

        switch type {
        case "event_msg", "response_item":
            return role
        default:
            return nil
        }
    }

    var payloadType: String? {
        payload["type"] as? String
    }

    var isToolCall: Bool {
        payloadType == "function_call" || payloadType == "tool_call" || type == "tool_call"
    }

    var isToolOutput: Bool {
        payloadType == "function_call_output"
            || payloadType == "tool_output"
            || type == "tool_output"
            || type == "tool_result"
    }

    var toolName: String? {
        payloadString("name") ?? payloadString("tool_name")
    }

    var callID: String? {
        payloadString("call_id") ?? payloadString("id")
    }

    var status: String? {
        payloadString("status")
    }

    var toolCallText: String? {
        payloadString("arguments") ?? payloadString("input") ?? payloadString("command")
    }

    var toolOutputText: String? {
        payloadString("output")
            ?? payloadString("error")
            ?? payloadString("result")
            ?? payloadSummary("error")
            ?? payloadSummary("output")
            ?? payloadSummary("result")
    }

    func payloadSummary(_ key: String) -> String? {
        guard let object = payload[key] as? [String: Any] else {
            return nil
        }

        if let code = object["code"] as? String,
           let message = object["message"] as? String {
            return "\(code): \(message)"
        }

        if let message = object["message"] as? String {
            return message
        }

        let pairs = object.keys.sorted().compactMap { key -> String? in
            guard let value = object[key] else {
                return nil
            }

            return "\(key)=\(String(describing: value))"
        }

        return pairs.isEmpty ? nil : pairs.joined(separator: ", ")
    }

    var messageText: String? {
        if let content = payload["content"] as? String {
            return content
        }

        guard let contentItems = payload["content"] as? [[String: Any]] else {
            return nil
        }

        let texts = contentItems.compactMap { item -> String? in
            guard let text = item["text"] as? String else {
                return nil
            }

            switch item["type"] as? String {
            case "input_text", "output_text", nil:
                return text
            default:
                return nil
            }
        }

        guard texts.isEmpty == false else {
            return nil
        }

        return texts.joined(separator: "\n")
    }

    var messageContentType: String {
        if payload["content"] is String {
            return "string"
        }

        return "content_array"
    }

    func payloadString(_ key: String) -> String? {
        payload[key] as? String
    }
}
