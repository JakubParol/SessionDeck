extension AppShellDiagnosticsSummary {
    public static func make(
        sourceDiscoverySummary: AppShellSourceDiscoverySummary,
        monitoringHealthSummary: AppShellMonitoringHealthSummary,
        selectedTranscriptDetail: AppShellSelectedTranscriptDetailState
    ) -> AppShellDiagnosticsSummary {
        make(rows: sourceRows(sourceDiscoverySummary)
            + monitoringRows(monitoringHealthSummary)
            + transcriptRows(selectedTranscriptDetail))
    }

    private static func sourceRows(
        _ summary: AppShellSourceDiscoverySummary
    ) -> [AppShellDiagnosticSummaryRow] {
        summary.sourceHealthRows
            .filter { $0.severity != .healthy }
            .map { row in
                AppShellDiagnosticSummaryRow(
                    id: "source.\(row.id)",
                    category: .source,
                    severity: diagnosticSeverity(row.severity, isBlocking: row.isBlocking),
                    title: "\(row.statusLabel): \(row.title)",
                    detail: row.detail,
                    recoveryGuidance: sourceRecoveryGuidance(row),
                    diagnosticCode: row.diagnosticCode,
                    scope: AppShellDiagnosticScope(
                        sourceID: SessionSourceID(rawValue: row.id),
                        label: row.location
                    )
                )
            }
    }

    private static func monitoringRows(
        _ summary: AppShellMonitoringHealthSummary
    ) -> [AppShellDiagnosticSummaryRow] {
        summary.rows
            .filter { row in
                row.severity != .healthy && row.id != "live-monitoring.not-started"
            }
            .map { row in
                let category = monitoringCategory(row)
                return AppShellDiagnosticSummaryRow(
                    id: "monitoring.\(row.id)",
                    category: category,
                    severity: diagnosticSeverity(row.severity),
                    title: row.title,
                    detail: row.detail,
                    recoveryGuidance: monitoringRecoveryGuidance(row, category: category),
                    diagnosticCode: row.diagnosticCode,
                    scope: AppShellDiagnosticScope(
                        sourceID: row.sourceID,
                        label: row.sourceID?.rawValue
                    )
                )
            }
    }

    private static func transcriptRows(
        _ detail: AppShellSelectedTranscriptDetailState
    ) -> [AppShellDiagnosticSummaryRow] {
        let diagnosticRows = detail.diagnosticRows
            .filter { $0.severity != .info }
            .map { row in
                AppShellDiagnosticSummaryRow(
                    id: "transcript.\(row.id)",
                    category: transcriptCategory(row),
                    severity: diagnosticSeverity(row.severity),
                    title: transcriptTitle(row),
                    detail: row.message,
                    recoveryGuidance: transcriptRecoveryGuidance(row),
                    diagnosticCode: row.diagnosticCode,
                    scope: AppShellDiagnosticScope(label: detail.title)
                )
            }

        guard diagnosticRows.isEmpty,
              detail.displayMode == .warning || detail.displayMode == .error
        else {
            return diagnosticRows
        }

        return [
            AppShellDiagnosticSummaryRow(
                id: "transcript.\(detail.title).state",
                category: .sessionParse,
                severity: diagnosticSeverity(detail.severity),
                title: detail.title,
                detail: detail.statusMessage,
                recoveryGuidance: "Open another session or refresh the catalog; SessionDeck will not modify transcript files.",
                diagnosticCode: nil,
                scope: AppShellDiagnosticScope(label: detail.title)
            ),
        ]
    }

    private static func diagnosticSeverity(
        _ severity: AppShellSourceHealthSeverity,
        isBlocking: Bool
    ) -> AppShellDiagnosticSeverity {
        if isBlocking {
            return .error
        }
        switch severity {
        case .healthy:
            return .healthy
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func diagnosticSeverity(
        _ severity: AppShellMonitoringHealthSeverity
    ) -> AppShellDiagnosticSeverity {
        switch severity {
        case .healthy:
            return .healthy
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func diagnosticSeverity(
        _ severity: AppShellCatalogRowSeverity
    ) -> AppShellDiagnosticSeverity {
        switch severity {
        case .healthy:
            return .healthy
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func sourceRecoveryGuidance(_ row: AppShellSourceHealthRow) -> String {
        if row.statusLabel == "Missing path" {
            return "Check the configured local path or remove the source; SessionDeck will not create folders or repair files."
        }
        if row.statusLabel == "Permission denied" || row.statusLabel == "Unreadable" {
            return "Review local folder permissions, then refresh; SessionDeck will not change permissions automatically."
        }
        if row.statusLabel == "Parse warning" {
            return "Open the affected session for context; readable sessions stay available while malformed entries are skipped."
        }
        return "Review the local source configuration and refresh when ready; no source files are modified."
    }

    private static func monitoringCategory(
        _ row: AppShellMonitoringHealthRow
    ) -> AppShellDiagnosticCategory {
        if row.title.contains("Reconciliation") {
            return .reconciliation
        }
        return .liveMonitoring
    }

    private static func monitoringRecoveryGuidance(
        _ row: AppShellMonitoringHealthRow,
        category: AppShellDiagnosticCategory
    ) -> String {
        if category == .reconciliation {
            return "Use manual refresh while reconciliation recovers, and check local source availability if the warning persists."
        }
        if row.title.contains("permission") || row.title.contains("Permission") {
            return "Review local folder permissions, then refresh; SessionDeck will not change permissions automatically."
        }
        return "Use manual refresh while watcher health is degraded; SessionDeck does not run repair commands."
    }

    private static func transcriptCategory(
        _ row: AppShellSelectedTranscriptDiagnosticRow
    ) -> AppShellDiagnosticCategory {
        row.message.hasPrefix("Refresh error") ? .refresh : .sessionParse
    }

    private static func transcriptTitle(
        _ row: AppShellSelectedTranscriptDiagnosticRow
    ) -> String {
        row.message.hasPrefix("Refresh error") ? "Refresh failed" : "Transcript diagnostic"
    }

    private static func transcriptRecoveryGuidance(
        _ row: AppShellSelectedTranscriptDiagnosticRow
    ) -> String {
        if row.message.hasPrefix("Refresh error") {
            return "Keep reading the last loaded content or refresh again; SessionDeck will not rewrite the transcript."
        }
        return "Review the diagnostic line in context; SessionDeck preserves readable transcript segments and does not edit source files."
    }
}
