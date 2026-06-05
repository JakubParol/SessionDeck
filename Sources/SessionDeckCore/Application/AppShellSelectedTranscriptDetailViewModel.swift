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

public enum AppShellSelectedTranscriptDisplayMode: Equatable, Sendable {
    case noSelection
    case loading
    case loaded
    case warning
    case error
}

public enum AppShellSelectedTranscriptRefreshStatus: Equatable, Sendable {
    case idle
    case refreshing
    case refreshed
    case failed(message: String)
}

public struct AppShellSelectedTranscriptDetailState: Equatable, Sendable {
    public let title: String
    public let statusMessage: String
    public let displayMode: AppShellSelectedTranscriptDisplayMode
    public let refreshStatus: AppShellSelectedTranscriptRefreshStatus
    public let metadataRows: [AppShellSelectedTranscriptMetadataRow]
    public let rows: [AppShellTranscriptSegmentRow]
    public let diagnosticMessages: [String]
    public let severity: AppShellCatalogRowSeverity
    public let isLoading: Bool

    public init(
        title: String,
        statusMessage: String,
        displayMode: AppShellSelectedTranscriptDisplayMode,
        refreshStatus: AppShellSelectedTranscriptRefreshStatus = .idle,
        metadataRows: [AppShellSelectedTranscriptMetadataRow],
        rows: [AppShellTranscriptSegmentRow],
        diagnosticMessages: [String],
        severity: AppShellCatalogRowSeverity,
        isLoading: Bool
    ) {
        self.title = title
        self.statusMessage = statusMessage
        self.displayMode = displayMode
        self.refreshStatus = refreshStatus
        self.metadataRows = metadataRows
        self.rows = rows
        self.diagnosticMessages = diagnosticMessages
        self.severity = severity
        self.isLoading = isLoading
    }

    public static let noSelection = AppShellSelectedTranscriptDetailState(
        title: "No session selected",
        statusMessage: "Select a catalog row to load transcript detail.",
        displayMode: .noSelection,
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
            displayMode: .loading,
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
            displayMode: displayMode(for: severity),
            metadataRows: metadataRows(for: readModel),
            rows: readModel.segments.map(AppShellTranscriptSegmentRow.make(segment:)),
            diagnosticMessages: readModel.diagnostics.map(diagnosticMessage(for:)),
            severity: severity,
            isLoading: false
        )
    }

    public static func liveRefresh(
        _ refreshState: SelectedSessionLiveRefreshState
    ) -> AppShellSelectedTranscriptDetailState {
        switch refreshState {
        case .idle:
            return noSelection
        case let .ignored(previous):
            return previous.map(loaded) ?? noSelection
        case let .refreshing(previous):
            guard let previous else {
                return loading(sessionTitle: "Selected transcript")
                    .withRefreshStatus(.refreshing)
            }
            return loaded(previous).withRefreshStatus(
                .refreshing,
                statusMessage: "Refreshing selected transcript..."
            )
        case let .loaded(readModel):
            return loaded(readModel).withRefreshStatus(
                .refreshed,
                statusMessage: "Selected transcript refreshed with latest readable content."
            )
        case let .failed(previous, message):
            guard let previous else {
                return AppShellSelectedTranscriptDetailState(
                    title: "Transcript unavailable",
                    statusMessage: "Refresh failed: \(message)",
                    displayMode: .error,
                    refreshStatus: .failed(message: message),
                    metadataRows: [],
                    rows: [],
                    diagnosticMessages: ["Error: \(message)"],
                    severity: .error,
                    isLoading: false
                )
            }
            return loaded(previous).withRefreshStatus(
                .failed(message: message),
                statusMessage: "Refresh failed: \(message) Last readable content is still shown.",
                displayMode: .error,
                severity: .error,
                diagnosticMessages: loaded(previous).diagnosticMessages + ["Error: \(message)"]
            )
        }
    }

    public static func failed(_ error: Error) -> AppShellSelectedTranscriptDetailState {
        let failure = failureDescription(for: error)
        return AppShellSelectedTranscriptDetailState(
            title: "Transcript unavailable",
            statusMessage: failure.message,
            displayMode: displayMode(for: failure.severity),
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
            displayMode: displayMode(for: failure.severity),
            metadataRows: metadataRows(for: session),
            rows: [],
            diagnosticMessages: [],
            severity: failure.severity,
            isLoading: false
        )
    }

    private func withRefreshStatus(
        _ refreshStatus: AppShellSelectedTranscriptRefreshStatus,
        statusMessage: String? = nil,
        displayMode: AppShellSelectedTranscriptDisplayMode? = nil,
        severity: AppShellCatalogRowSeverity? = nil,
        diagnosticMessages: [String]? = nil
    ) -> AppShellSelectedTranscriptDetailState {
        AppShellSelectedTranscriptDetailState(
            title: title,
            statusMessage: statusMessage ?? self.statusMessage,
            displayMode: displayMode ?? self.displayMode,
            refreshStatus: refreshStatus,
            metadataRows: metadataRows,
            rows: rows,
            diagnosticMessages: diagnosticMessages ?? self.diagnosticMessages,
            severity: severity ?? self.severity,
            isLoading: isLoading
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

    private static func displayMode(
        for severity: AppShellCatalogRowSeverity
    ) -> AppShellSelectedTranscriptDisplayMode {
        switch severity {
        case .healthy, .info:
            return .loaded
        case .warning:
            return .warning
        case .error:
            return .error
        }
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

    private static func diagnosticMessage(for diagnostic: TranscriptDecodeDiagnostic) -> String {
        let prefix = diagnosticSeverityLabel(for: diagnostic.severity)
        guard let lineNumber = diagnostic.source?.lineNumber else {
            return "\(prefix): \(diagnostic.message)"
        }

        return "\(prefix) line \(lineNumber): \(diagnostic.message)"
    }

    private static func diagnosticSeverityLabel(
        for severity: TranscriptDecodeDiagnosticSeverity
    ) -> String {
        switch severity {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
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
