import Foundation

public enum AppShellCatalogRowSeverity: Equatable, Sendable {
    case healthy
    case info
    case warning
    case error
}

public struct AppShellCatalogRow: Equatable, Identifiable, Sendable {
    public let id: SessionID
    public let title: String
    public let sourceLabel: String
    public let projectHint: String
    public let lastActivityLabel: String
    public let sizeLabel: String
    public let statusLabel: String
    public let diagnosticSummary: String?
    public let severity: AppShellCatalogRowSeverity

    public init(
        id: SessionID,
        title: String,
        sourceLabel: String,
        projectHint: String,
        lastActivityLabel: String,
        sizeLabel: String,
        statusLabel: String,
        diagnosticSummary: String?,
        severity: AppShellCatalogRowSeverity
    ) {
        self.id = id
        self.title = title
        self.sourceLabel = sourceLabel
        self.projectHint = projectHint
        self.lastActivityLabel = lastActivityLabel
        self.sizeLabel = sizeLabel
        self.statusLabel = statusLabel
        self.diagnosticSummary = diagnosticSummary
        self.severity = severity
    }

    public static func make(
        session: SessionSummary,
        snapshotDiagnostics: [CatalogSnapshotDiagnostic]
    ) -> AppShellCatalogRow {
        let diagnostics = snapshotDiagnostics.filter { $0.sessionIDs.contains(session.id) }

        return AppShellCatalogRow(
            id: session.id,
            title: session.displayTitle,
            sourceLabel: sourceLabel(for: session),
            projectHint: session.projectDisplayName,
            lastActivityLabel: lastActivityLabel(for: session),
            sizeLabel: sizeLabel(for: session.fileSize.byteCount),
            statusLabel: statusLabel(for: session, snapshotDiagnostics: diagnostics),
            diagnosticSummary: diagnosticSummary(for: session, snapshotDiagnostics: diagnostics),
            severity: severity(for: session, snapshotDiagnostics: diagnostics)
        )
    }

    private static func sourceLabel(for session: SessionSummary) -> String {
        let profileName = session.sourceLabel.profileName ?? session.metadata.agentProfileName
        guard let profileName, profileName.isEmpty == false else {
            return session.sourceLabel.displayName
        }

        return "\(session.sourceLabel.displayName) / \(profileName)"
    }

    private static func lastActivityLabel(for session: SessionSummary) -> String {
        guard let epochSeconds = session.lastActivitySortKey else {
            return "Last activity unknown"
        }

        return "Last activity \(epochSeconds)"
    }

    private static func sizeLabel(for byteCount: Int64) -> String {
        if byteCount < 1_024 {
            return "\(byteCount) B"
        }
        if byteCount < 1_048_576 {
            return "\(byteCount / 1_024) KB"
        }

        return "\(byteCount / 1_048_576) MB"
    }

    private static func statusLabel(
        for session: SessionSummary,
        snapshotDiagnostics: [CatalogSnapshotDiagnostic]
    ) -> String {
        if snapshotDiagnostics.isEmpty == false {
            return "Catalog diagnostics"
        }

        switch session.health.parseStatus {
        case .complete where session.health.diagnostics.isEmpty:
            return "Healthy"
        case .complete:
            return "Diagnostics"
        case .missingMetadata:
            return "Missing metadata"
        case .malformed:
            return "Malformed"
        case .unreadable:
            return "Unreadable"
        }
    }

    private static func diagnosticSummary(
        for session: SessionSummary,
        snapshotDiagnostics: [CatalogSnapshotDiagnostic]
    ) -> String? {
        if let snapshotDiagnostic = snapshotDiagnostics.first {
            return snapshotDiagnostic.message
        }
        if let entryDiagnostic = session.health.diagnostics.first {
            return entryDiagnostic.message
        }

        switch session.health.parseStatus {
        case .complete:
            return nil
        case .missingMetadata:
            return "Catalog metadata is incomplete."
        case let .malformed(reason):
            return reason
        case let .unreadable(reason):
            return reason
        }
    }

    private static func severity(
        for session: SessionSummary,
        snapshotDiagnostics: [CatalogSnapshotDiagnostic]
    ) -> AppShellCatalogRowSeverity {
        if snapshotDiagnostics.contains(where: { $0.severity == .error }) {
            return .error
        }
        if snapshotDiagnostics.isEmpty == false {
            return .warning
        }
        if session.health.diagnostics.contains(where: { $0.severity == .error })
            || session.health.parseStatus.isUnreadable {
            return .error
        }
        if session.health.diagnostics.contains(where: { $0.severity == .warning })
            || session.health.parseStatus.isDiagnostic {
            return .warning
        }
        if session.health.diagnostics.isEmpty == false {
            return .info
        }

        return .healthy
    }
}

private extension CatalogParseStatus {
    var isDiagnostic: Bool {
        switch self {
        case .complete:
            return false
        case .missingMetadata, .malformed, .unreadable:
            return true
        }
    }

    var isUnreadable: Bool {
        switch self {
        case .unreadable:
            return true
        case .complete, .missingMetadata, .malformed:
            return false
        }
    }
}
