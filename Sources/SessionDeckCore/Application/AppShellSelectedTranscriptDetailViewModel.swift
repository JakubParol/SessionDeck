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

public struct AppShellSelectedTranscriptMetadataRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    public let isFallback: Bool

    public init(
        id: String,
        title: String,
        value: String,
        isFallback: Bool
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.isFallback = isFallback
    }
}

public struct AppShellSelectedTranscriptDetailState: Equatable, Sendable {
    public let title: String
    public let statusMessage: String
    public let metadataRows: [AppShellSelectedTranscriptMetadataRow]
    public let rows: [AppShellTranscriptSegmentRow]
    public let diagnosticMessages: [String]
    public let severity: AppShellCatalogRowSeverity
    public let isLoading: Bool

    public init(
        title: String,
        statusMessage: String,
        metadataRows: [AppShellSelectedTranscriptMetadataRow],
        rows: [AppShellTranscriptSegmentRow],
        diagnosticMessages: [String],
        severity: AppShellCatalogRowSeverity,
        isLoading: Bool
    ) {
        self.title = title
        self.statusMessage = statusMessage
        self.metadataRows = metadataRows
        self.rows = rows
        self.diagnosticMessages = diagnosticMessages
        self.severity = severity
        self.isLoading = isLoading
    }

    public static let noSelection = AppShellSelectedTranscriptDetailState(
        title: "No session selected",
        statusMessage: "Select a catalog row to load transcript detail.",
        metadataRows: [],
        rows: [],
        diagnosticMessages: [],
        severity: .info,
        isLoading: false
    )

    public static func loading(sessionTitle: String) -> AppShellSelectedTranscriptDetailState {
        AppShellSelectedTranscriptDetailState(
            title: sessionTitle,
            statusMessage: "Loading selected transcript...",
            metadataRows: [],
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
            title: titleLabel(for: readModel.title),
            statusMessage: loadedStatusMessage(
                segmentCount: readModel.segments.count,
                warningCount: warningCount,
                errorCount: errorCount,
                isPartial: readModel.isPartial
            ),
            metadataRows: metadataRows(for: readModel),
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
            metadataRows: [],
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

    private static func metadataRows(
        for readModel: SelectedTranscriptReadModel
    ) -> [AppShellSelectedTranscriptMetadataRow] {
        [
            AppShellSelectedTranscriptMetadataRow(
                id: "title",
                title: "Title",
                value: titleLabel(for: readModel.title),
                isFallback: readModel.title.isEmpty
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "source",
                title: "Source",
                value: sourceLabel(for: readModel),
                isFallback: readModel.sourceLabel.displayName.isEmpty
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "project",
                title: "Project",
                value: projectLabel(for: readModel.projectHint),
                isFallback: readModel.projectHint.cwdPath == nil || readModel.projectHint.displayName.isEmpty
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "path",
                title: "Path",
                value: pathLabel(for: readModel.sessionPath),
                isFallback: readModel.sessionPath.isEmpty
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "created",
                title: "Created",
                value: timestampLabel(
                    for: readModel.activity.createdAtEpochSeconds,
                    fallback: "Created time unavailable"
                ),
                isFallback: readModel.activity.createdAtEpochSeconds == nil
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "last-activity",
                title: "Last Activity",
                value: timestampLabel(
                    for: readModel.activity.lastActivityEpochSeconds,
                    fallback: "Last activity unavailable"
                ),
                isFallback: readModel.activity.lastActivityEpochSeconds == nil
            ),
        ]
    }

    private static func titleLabel(for title: String) -> String {
        title.isEmpty ? "Untitled session" : title
    }

    private static func sourceLabel(for readModel: SelectedTranscriptReadModel) -> String {
        let sourceDisplayName = readModel.sourceLabel.displayName
        guard sourceDisplayName.isEmpty == false else {
            return "Unknown source"
        }

        let profileName = readModel.sourceLabel.profileName ?? readModel.metadata.agentProfileName
        guard let profileName, profileName.isEmpty == false else {
            return sourceDisplayName
        }

        return "\(sourceDisplayName) / \(profileName)"
    }

    private static func projectLabel(for projectHint: CatalogProjectHint) -> String {
        guard projectHint.displayName.isEmpty == false else {
            return "Project unavailable"
        }

        return projectHint.displayName
    }

    private static func pathLabel(for sessionPath: String) -> String {
        sessionPath.isEmpty ? "Path unavailable" : sessionPath
    }

    private static func timestampLabel(for epochSeconds: Int64?, fallback: String) -> String {
        guard let epochSeconds else {
            return fallback
        }

        return "\(epochSeconds)"
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
