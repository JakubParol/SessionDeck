public enum AppShellTranscriptRoleStyle: Equatable, Sendable {
    case userTurn
    case assistantTurn
    case supporting
}

public struct AppShellTranscriptToolPresentation: Equatable, Sendable {
    public let displayLabel: String
    public let metadataSummary: String
    public let expandedText: String
    public let detailSummary: String
    public let diagnosticMessages: [String]
    public let isCollapsedByDefault: Bool

    public init(
        displayLabel: String,
        metadataSummary: String,
        expandedText: String,
        detailSummary: String = "",
        diagnosticMessages: [String] = [],
        isCollapsedByDefault: Bool
    ) {
        self.displayLabel = displayLabel
        self.metadataSummary = metadataSummary
        self.expandedText = expandedText
        self.detailSummary = detailSummary
        self.diagnosticMessages = diagnosticMessages
        self.isCollapsedByDefault = isCollapsedByDefault
    }
}

public struct AppShellTranscriptSegmentRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let roleLabel: String
    public let timestampLabel: String?
    public let text: String
    public let severity: AppShellCatalogRowSeverity
    public let roleStyle: AppShellTranscriptRoleStyle
    public let toolPresentation: AppShellTranscriptToolPresentation?

    public init(
        id: String,
        roleLabel: String,
        timestampLabel: String?,
        text: String,
        severity: AppShellCatalogRowSeverity,
        roleStyle: AppShellTranscriptRoleStyle,
        toolPresentation: AppShellTranscriptToolPresentation? = nil
    ) {
        self.id = id
        self.roleLabel = roleLabel
        self.timestampLabel = timestampLabel
        self.text = text
        self.severity = severity
        self.roleStyle = roleStyle
        self.toolPresentation = toolPresentation
    }

    public static func make(segment: TranscriptSegment) -> AppShellTranscriptSegmentRow {
        AppShellTranscriptSegmentRow(
            id: segment.id,
            roleLabel: roleLabel(for: segment.role),
            timestampLabel: segment.timestampDescription,
            text: textLabel(for: segment),
            severity: severity(for: segment.role),
            roleStyle: roleStyle(for: segment.role),
            toolPresentation: toolPresentation(for: segment)
        )
    }

    private static func textLabel(for segment: TranscriptSegment) -> String {
        if let toolPresentation = toolPresentation(for: segment) {
            switch segment.kind {
            case .toolCall:
                return "Tool call: \(toolPresentation.displayLabel)"
            case .toolOutput:
                if toolPresentation.displayLabel == "tool output" {
                    return "Tool output"
                }
                return "Tool output from \(toolPresentation.displayLabel)"
            case .assistantMessage, .error, .metadata, .unknown, .userMessage:
                break
            }
        }

        return textLabel(for: segment.text)
    }

    private static func textLabel(for text: String) -> String {
        text.allSatisfy(\.isWhitespace) ? "Empty transcript segment." : text
    }

    private static func toolPresentation(
        for segment: TranscriptSegment
    ) -> AppShellTranscriptToolPresentation? {
        guard segment.role == .tool else {
            return nil
        }

        let metadata = segment.toolMetadata
        let displayLabel = textLabel(for: metadata?.displayLabel ?? fallbackToolDisplayLabel(for: segment.kind))

        return AppShellTranscriptToolPresentation(
            displayLabel: displayLabel,
            metadataSummary: toolMetadataSummary(for: metadata),
            expandedText: textLabel(for: segment.text),
            detailSummary: toolDetailSummary(for: segment, metadata: metadata),
            diagnosticMessages: toolDiagnosticMessages(for: metadata),
            isCollapsedByDefault: true
        )
    }

    private static func fallbackToolDisplayLabel(for kind: TranscriptSegmentKind) -> String {
        switch kind {
        case let .toolCall(name, _):
            return name.isEmpty ? "Unknown tool" : name
        case .toolOutput:
            return "tool output"
        case .assistantMessage, .error, .metadata, .unknown, .userMessage:
            return "Unknown tool"
        }
    }

    private static func toolMetadataSummary(for metadata: TranscriptToolMetadata?) -> String {
        guard let metadata else {
            return "metadata unavailable"
        }

        var parts: [String] = []
        if let status = metadata.status, status.isEmpty == false {
            parts.append(status)
        } else {
            parts.append("status unknown")
        }

        if let characterCount = metadata.characterCount {
            parts.append("\(characterCount) \(characterCount == 1 ? "character" : "characters")")
        }

        if let lineCount = metadata.lineCount {
            parts.append("\(lineCount) \(lineCount == 1 ? "line" : "lines")")
        }

        if metadata.bodyAvailability != .available {
            parts.append(bodyAvailabilityLabel(for: metadata.bodyAvailability))
        }

        return parts.joined(separator: " - ")
    }

    private static func toolDetailSummary(
        for segment: TranscriptSegment,
        metadata: TranscriptToolMetadata?
    ) -> String {
        guard let metadata else {
            return "Tool metadata unavailable"
        }

        guard metadata.bodyAvailability != .omitted else {
            return "Tool output body unavailable"
        }

        guard let totalCharacterCount = metadata.characterCount else {
            return "Showing bounded output; total size unknown"
        }

        let displayedCharacterCount = min(segment.text.count, totalCharacterCount)
        return "Showing \(formattedCount(displayedCharacterCount)) of \(formattedCount(totalCharacterCount)) characters"
    }

    private static func toolDiagnosticMessages(for metadata: TranscriptToolMetadata?) -> [String] {
        guard let metadata else {
            return ["Tool metadata unavailable."]
        }

        var messages: [String] = []
        switch metadata.bodyAvailability {
        case .available:
            break
        case .omitted:
            messages.append("Tool output body unavailable.")
        case .malformed:
            messages.append("Tool output body malformed.")
        case .truncated:
            messages.append("Partial output shown: configured display bound reached.")
        }

        if metadata.characterCount == nil, metadata.byteCount == nil {
            messages.append("Output size metadata unavailable.")
        }

        return messages
    }

    private static func formattedCount(_ count: Int) -> String {
        let digits = String(count)
        var result = ""

        for (offset, character) in digits.reversed().enumerated() {
            if offset > 0, offset % 3 == 0 {
                result.append(",")
            }
            result.append(character)
        }

        return String(result.reversed())
    }

    private static func bodyAvailabilityLabel(
        for availability: TranscriptToolBodyAvailability
    ) -> String {
        switch availability {
        case .available:
            return "body available"
        case .omitted:
            return "body omitted"
        case .malformed:
            return "body malformed"
        case .truncated:
            return "body truncated"
        }
    }

    private static func roleLabel(for role: TranscriptSegmentRole) -> String {
        switch role {
        case .user:
            return "User"
        case .assistant:
            return "Assistant"
        case .tool:
            return "Tool"
        case .diagnostic:
            return "Diagnostic"
        case let .unknown(eventType):
            return "Unknown: \(eventType)"
        }
    }

    private static func severity(for role: TranscriptSegmentRole) -> AppShellCatalogRowSeverity {
        switch role {
        case .user, .assistant:
            return .healthy
        case .tool:
            return .info
        case .diagnostic, .unknown:
            return .warning
        }
    }

    private static func roleStyle(for role: TranscriptSegmentRole) -> AppShellTranscriptRoleStyle {
        switch role {
        case .user:
            return .userTurn
        case .assistant:
            return .assistantTurn
        case .tool, .diagnostic, .unknown:
            return .supporting
        }
    }
}
