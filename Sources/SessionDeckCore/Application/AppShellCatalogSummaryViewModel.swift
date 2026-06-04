import Foundation

public struct AppShellCatalogSummary: Equatable, Sendable {
    public static let placeholder = AppShellCatalogSummary(
        rows: [],
        totalCount: 0,
        healthyCount: 0,
        diagnosticCount: 0,
        sourceWarningCount: 0,
        sourceFailureCount: 0,
        resultState: .notRun,
        diagnosticSummary: AppShellCatalogDiagnosticSummary.none,
        statusMessage: "Catalog has not run yet."
    )

    public let rows: [AppShellCatalogRow]
    public let totalCount: Int
    public let healthyCount: Int
    public let diagnosticCount: Int
    public let sourceWarningCount: Int
    public let sourceFailureCount: Int
    public let unfilteredTotalCount: Int
    public let isFiltered: Bool
    public let resultState: AppShellCatalogResultState
    public let diagnosticSummary: AppShellCatalogDiagnosticSummary
    public let emptyState: AppShellCatalogEmptyState?
    public let statusMessage: String

    public init(
        rows: [AppShellCatalogRow],
        totalCount: Int,
        healthyCount: Int,
        diagnosticCount: Int,
        sourceWarningCount: Int,
        sourceFailureCount: Int,
        unfilteredTotalCount: Int? = nil,
        isFiltered: Bool = false,
        resultState: AppShellCatalogResultState? = nil,
        diagnosticSummary: AppShellCatalogDiagnosticSummary? = nil,
        statusMessage: String
    ) {
        let resolvedUnfilteredTotalCount = unfilteredTotalCount ?? totalCount
        let resolvedResultState = resultState ?? Self.resultState(
            totalCount: totalCount,
            diagnosticCount: diagnosticCount,
            sourceWarningCount: sourceWarningCount,
            sourceFailureCount: sourceFailureCount,
            unfilteredTotalCount: resolvedUnfilteredTotalCount,
            isFiltered: isFiltered
        )
        let resolvedDiagnosticSummary = diagnosticSummary ?? Self.diagnosticSummary(
            entryDiagnosticCount: diagnosticCount,
            sourceWarningCount: sourceWarningCount,
            sourceFailureCount: sourceFailureCount,
            primaryMessage: statusMessage
        )

        self.rows = rows
        self.totalCount = totalCount
        self.healthyCount = healthyCount
        self.diagnosticCount = diagnosticCount
        self.sourceWarningCount = sourceWarningCount
        self.sourceFailureCount = sourceFailureCount
        self.unfilteredTotalCount = resolvedUnfilteredTotalCount
        self.isFiltered = isFiltered
        self.resultState = resolvedResultState
        self.diagnosticSummary = resolvedDiagnosticSummary
        self.emptyState = Self.emptyState(
            resultState: resolvedResultState,
            unfilteredTotalCount: resolvedUnfilteredTotalCount
        )
        self.statusMessage = statusMessage
    }

    public static func make(snapshot: CatalogSnapshot) -> AppShellCatalogSummary {
        AppShellCatalogSummary(
            rows: snapshot.sessions.map {
                AppShellCatalogRow.make(session: $0, snapshotDiagnostics: snapshot.diagnostics)
            },
            totalCount: snapshot.counts.totalEntries,
            healthyCount: snapshot.counts.healthyEntries,
            diagnosticCount: snapshot.counts.diagnosticEntries,
            sourceWarningCount: snapshot.sourceWarnings.count,
            sourceFailureCount: snapshot.refreshErrors.count,
            statusMessage: statusMessage(
                for: snapshot,
                isFiltered: false,
                unfilteredTotalCount: snapshot.sessions.count
            )
        )
    }

    public static func make(
        snapshot: CatalogSnapshot,
        scope: CatalogSessionScope,
        queryRequest: CatalogQueryRequest = CatalogQueryRequest(),
        isFiltered: Bool = false
    ) -> AppShellCatalogSummary {
        let scopedSessions = SourceProfileNavigationPolicy.filter(sessions: snapshot.sessions, scope: scope)
        let queriedSessions = CatalogQueryEvaluation.query(sessions: scopedSessions, request: queryRequest)
        let scopedSourceIDs = sourceIDs(for: scope, scopedSessions: scopedSessions)
        let scopedSnapshot = CatalogSnapshot(
            refreshedAt: snapshot.refreshedAt,
            sources: snapshot.sources,
            sessions: queriedSessions,
            diagnostics: snapshot.diagnostics,
            sourceWarnings: sourceWarnings(snapshot.sourceWarnings, scopedTo: scopedSourceIDs),
            refreshErrors: refreshErrors(snapshot.refreshErrors, scopedTo: scopedSourceIDs)
        )

        return make(snapshot: scopedSnapshot, isFiltered: isFiltered, unfilteredTotalCount: scopedSessions.count)
    }

    public static func failed(message: String) -> AppShellCatalogSummary {
        AppShellCatalogSummary(
            rows: [],
            totalCount: 0,
            healthyCount: 0,
            diagnosticCount: 0,
            sourceWarningCount: 0,
            sourceFailureCount: 1,
            statusMessage: message
        )
    }

    private static func make(
        snapshot: CatalogSnapshot,
        isFiltered: Bool,
        unfilteredTotalCount: Int
    ) -> AppShellCatalogSummary {
        AppShellCatalogSummary(
            rows: snapshot.sessions.map {
                AppShellCatalogRow.make(session: $0, snapshotDiagnostics: snapshot.diagnostics)
            },
            totalCount: snapshot.counts.totalEntries,
            healthyCount: snapshot.counts.healthyEntries,
            diagnosticCount: snapshot.counts.diagnosticEntries,
            sourceWarningCount: snapshot.sourceWarnings.count,
            sourceFailureCount: snapshot.refreshErrors.count,
            unfilteredTotalCount: unfilteredTotalCount,
            isFiltered: isFiltered,
            statusMessage: statusMessage(
                for: snapshot,
                isFiltered: isFiltered,
                unfilteredTotalCount: unfilteredTotalCount
            )
        )
    }

    private static func statusMessage(
        for snapshot: CatalogSnapshot,
        isFiltered: Bool,
        unfilteredTotalCount: Int
    ) -> String {
        if isFiltered && snapshot.sessions.isEmpty && unfilteredTotalCount > 0 && snapshot.refreshErrors.isEmpty {
            return "No catalog rows match active filters."
        }
        if snapshot.sessions.isEmpty && snapshot.refreshErrors.isEmpty == false {
            return "Catalog refresh failed for \(sourceCountLabel(snapshot.refreshErrors.count))."
        }
        if snapshot.sessions.isEmpty {
            return "No catalog entries yet."
        }
        if snapshot.counts.diagnosticEntries > 0 {
            return "Catalog shows \(entryCountLabel(snapshot.counts.diagnosticEntries)) with diagnostics."
        }
        if snapshot.sourceWarnings.isEmpty == false || snapshot.refreshErrors.isEmpty == false {
            return "Catalog loaded with source diagnostics."
        }

        return "Catalog shows \(entryCountLabel(snapshot.counts.healthyEntries)) healthy."
    }

    private static func entryCountLabel(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }

    private static func sourceCountLabel(_ count: Int) -> String {
        count == 1 ? "1 source" : "\(count) sources"
    }

    private static func rowCountLabel(_ count: Int) -> String {
        count == 1 ? "1 row" : "\(count) rows"
    }

    private static func resultState(
        totalCount: Int,
        diagnosticCount: Int,
        sourceWarningCount: Int,
        sourceFailureCount: Int,
        unfilteredTotalCount: Int,
        isFiltered: Bool
    ) -> AppShellCatalogResultState {
        if sourceFailureCount > 0 && totalCount == 0 {
            return .failure
        }
        if isFiltered && totalCount == 0 && unfilteredTotalCount > 0 {
            return .noMatches
        }
        if totalCount == 0 {
            return .empty
        }
        if diagnosticCount > 0 || sourceWarningCount > 0 || sourceFailureCount > 0 {
            return .warning
        }

        return .matches
    }

    private static func diagnosticSummary(
        entryDiagnosticCount: Int,
        sourceWarningCount: Int,
        sourceFailureCount: Int,
        primaryMessage: String
    ) -> AppShellCatalogDiagnosticSummary {
        guard entryDiagnosticCount > 0 || sourceWarningCount > 0 || sourceFailureCount > 0 else {
            return .none
        }

        return AppShellCatalogDiagnosticSummary(
            entryDiagnosticCount: entryDiagnosticCount,
            sourceWarningCount: sourceWarningCount,
            sourceFailureCount: sourceFailureCount,
            primaryMessage: primaryMessage
        )
    }

    private static func emptyState(
        resultState: AppShellCatalogResultState,
        unfilteredTotalCount: Int
    ) -> AppShellCatalogEmptyState? {
        switch resultState {
        case .notRun:
            return AppShellCatalogEmptyState(
                title: "Catalog has not run yet",
                detail: "Refresh the configured local sources to build catalog rows."
            )
        case .empty:
            return AppShellCatalogEmptyState(
                title: "No catalog rows",
                detail: "No lightweight session metadata is available from configured sources yet."
            )
        case .noMatches:
            return AppShellCatalogEmptyState(
                title: "No matching catalog rows",
                detail: "Active criteria hide \(rowCountLabel(unfilteredTotalCount))."
            )
        case .failure:
            return AppShellCatalogEmptyState(
                title: "Catalog source or index failed",
                detail: "Diagnostics stayed local; no catalog rows were hidden by filters."
            )
        case .matches, .warning:
            return nil
        }
    }

    private static func sourceIDs(
        for scope: CatalogSessionScope,
        scopedSessions: [SessionSummary]
    ) -> Set<SessionSourceID>? {
        switch scope {
        case .all:
            return nil
        case let .source(sourceMetadata):
            return sourceMetadata.sourceID.map { [$0] } ?? Set(scopedSessions.map(\.sourceID))
        case let .profile(profileMetadata):
            return profileMetadata.sourceID.map { [$0] } ?? Set(scopedSessions.map(\.sourceID))
        case .sessionIDs:
            return Set(scopedSessions.map(\.sourceID))
        }
    }

    private static func sourceWarnings(
        _ warnings: [CatalogSnapshotSourceWarning],
        scopedTo sourceIDs: Set<SessionSourceID>?
    ) -> [CatalogSnapshotSourceWarning] {
        guard let sourceIDs else {
            return warnings
        }

        return warnings.filter { sourceIDs.contains($0.sourceID) }
    }

    private static func refreshErrors(
        _ errors: [CatalogSnapshotRefreshError],
        scopedTo sourceIDs: Set<SessionSourceID>?
    ) -> [CatalogSnapshotRefreshError] {
        guard let sourceIDs else {
            return errors
        }

        return errors.filter { sourceIDs.contains($0.sourceID) }
    }
}
