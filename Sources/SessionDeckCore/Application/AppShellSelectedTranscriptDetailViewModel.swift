public struct AppShellTranscriptSegmentRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let roleLabel: String
    public let timestampLabel: String?
    public let text: String
    public let severity: AppShellCatalogRowSeverity

    public init(
        id: String,
        roleLabel: String,
        timestampLabel: String?,
        text: String,
        severity: AppShellCatalogRowSeverity
    ) {
        self.id = id
        self.roleLabel = roleLabel
        self.timestampLabel = timestampLabel
        self.text = text
        self.severity = severity
    }

    public static func make(segment: TranscriptSegment) -> AppShellTranscriptSegmentRow {
        AppShellTranscriptSegmentRow(
            id: segment.id,
            roleLabel: roleLabel(for: segment.role),
            timestampLabel: segment.timestampDescription,
            text: segment.text,
            severity: severity(for: segment.role)
        )
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
}

public struct AppShellSelectedTranscriptDetailState: Equatable, Sendable {
    public let title: String
    public let statusMessage: String
    public let rows: [AppShellTranscriptSegmentRow]
    public let diagnosticMessages: [String]
    public let severity: AppShellCatalogRowSeverity
    public let isLoading: Bool

    public init(
        title: String,
        statusMessage: String,
        rows: [AppShellTranscriptSegmentRow],
        diagnosticMessages: [String],
        severity: AppShellCatalogRowSeverity,
        isLoading: Bool
    ) {
        self.title = title
        self.statusMessage = statusMessage
        self.rows = rows
        self.diagnosticMessages = diagnosticMessages
        self.severity = severity
        self.isLoading = isLoading
    }

    public static let noSelection = AppShellSelectedTranscriptDetailState(
        title: "No session selected",
        statusMessage: "Select a catalog row to load transcript detail.",
        rows: [],
        diagnosticMessages: [],
        severity: .info,
        isLoading: false
    )

    public static func loading(sessionTitle: String) -> AppShellSelectedTranscriptDetailState {
        AppShellSelectedTranscriptDetailState(
            title: sessionTitle,
            statusMessage: "Loading selected transcript...",
            rows: [],
            diagnosticMessages: [],
            severity: .info,
            isLoading: true
        )
    }

    public static func loaded(_ readModel: SelectedTranscriptReadModel) -> AppShellSelectedTranscriptDetailState {
        let warningCount = readModel.diagnostics.filter { $0.severity == .warning }.count
        let errorCount = readModel.diagnostics.filter { $0.severity == .error }.count
        let severity = loadedSeverity(errorCount: errorCount, warningCount: warningCount)

        return AppShellSelectedTranscriptDetailState(
            title: readModel.title,
            statusMessage: loadedStatusMessage(
                segmentCount: readModel.segments.count,
                warningCount: warningCount,
                errorCount: errorCount,
                isPartial: readModel.isPartial
            ),
            rows: readModel.segments.map(AppShellTranscriptSegmentRow.make(segment:)),
            diagnosticMessages: readModel.diagnostics.map(\.message),
            severity: severity,
            isLoading: false
        )
    }

    public static func failed(_ error: Error) -> AppShellSelectedTranscriptDetailState {
        let failure = failureDescription(for: error)
        return AppShellSelectedTranscriptDetailState(
            title: "Transcript unavailable",
            statusMessage: failure.message,
            rows: [],
            diagnosticMessages: [],
            severity: failure.severity,
            isLoading: false
        )
    }

    private static func loadedSeverity(
        errorCount: Int,
        warningCount: Int
    ) -> AppShellCatalogRowSeverity {
        if errorCount > 0 {
            return .error
        }
        if warningCount > 0 {
            return .warning
        }

        return .healthy
    }

    private static func loadedStatusMessage(
        segmentCount: Int,
        warningCount: Int,
        errorCount: Int,
        isPartial: Bool
    ) -> String {
        if errorCount > 0 {
            return "Loaded \(segmentCount) transcript segment(s) with \(errorCount) error(s)."
        }
        if warningCount > 0 {
            return "Loaded \(segmentCount) transcript segment(s) with \(warningCount) warning(s)."
        }
        if isPartial {
            return "Loaded \(segmentCount) transcript segment(s) from a partial transcript."
        }

        return "Loaded \(segmentCount) transcript segment(s)."
    }

    private static func failureDescription(for error: Error) -> (
        message: String,
        severity: AppShellCatalogRowSeverity
    ) {
        guard let loadingError = error as? SelectedTranscriptLoadingError else {
            return ("The selected transcript could not be loaded.", .error)
        }

        switch loadingError {
        case .transcriptMissing:
            return ("The selected transcript file is missing.", .error)
        case .transcriptUnreadable:
            return ("The selected transcript file cannot be read.", .error)
        case .transcriptUnavailable:
            return ("The selected session cannot be loaded yet.", .warning)
        }
    }
}
