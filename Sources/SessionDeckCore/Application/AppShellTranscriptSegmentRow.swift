public enum AppShellTranscriptRoleStyle: Equatable, Sendable {
    case userTurn
    case assistantTurn
    case supporting
}

public struct AppShellTranscriptSegmentRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let roleLabel: String
    public let timestampLabel: String?
    public let text: String
    public let severity: AppShellCatalogRowSeverity
    public let roleStyle: AppShellTranscriptRoleStyle

    public init(
        id: String,
        roleLabel: String,
        timestampLabel: String?,
        text: String,
        severity: AppShellCatalogRowSeverity,
        roleStyle: AppShellTranscriptRoleStyle
    ) {
        self.id = id
        self.roleLabel = roleLabel
        self.timestampLabel = timestampLabel
        self.text = text
        self.severity = severity
        self.roleStyle = roleStyle
    }

    public static func make(segment: TranscriptSegment) -> AppShellTranscriptSegmentRow {
        AppShellTranscriptSegmentRow(
            id: segment.id,
            roleLabel: roleLabel(for: segment.role),
            timestampLabel: segment.timestampDescription,
            text: textLabel(for: segment.text),
            severity: severity(for: segment.role),
            roleStyle: roleStyle(for: segment.role)
        )
    }

    private static func textLabel(for text: String) -> String {
        text.allSatisfy(\.isWhitespace) ? "Empty transcript segment." : text
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
