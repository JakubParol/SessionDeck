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

    public static func failed(
        _ error: Error,
        session: SessionSummary
    ) -> AppShellSelectedTranscriptDetailState {
        let failure = failureDescription(for: error)
        return AppShellSelectedTranscriptDetailState(
            title: titleLabel(for: session.title ?? ""),
            statusMessage: failure.message,
            metadataRows: metadataRows(for: session),
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

    private static func sourceLabel(for readModel: SelectedTranscriptReadModel) -> String {
        sourceLabel(sourceLabel: readModel.sourceLabel, metadata: readModel.metadata)
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
