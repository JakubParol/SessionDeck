import Foundation
import Testing
@testable import SessionDeckCore

@Test("diagnostics summary stays healthy and quiet when no diagnostics are active")
func diagnosticsSummaryStaysHealthyWhenNoDiagnosticsAreActive() {
    let summary = AppShellDiagnosticsSummary.make(
        sourceDiscoverySummary: .placeholder,
        monitoringHealthSummary: .notStarted,
        selectedTranscriptDetail: .noSelection
    )

    #expect(summary.severity == .healthy)
    #expect(summary.statusMessage == "No diagnostics need attention.")
    #expect(summary.rows.map(\.title) == ["Healthy"])
}

@Test("diagnostics summary maps a missing source path to warning guidance")
func diagnosticsSummaryMapsMissingSourcePathToWarningGuidance() {
    let sourceID = SessionSourceID(rawValue: "codex-missing")
    let sourceSummary = AppShellSourceDiscoverySummary.make(
        report: SessionSourceDiscoveryReport(sources: [
            diagnosticsSource(
                id: sourceID,
                displayName: "Codex missing",
                location: "/tmp/sessiondeck/missing/.codex/sessions",
                availability: .missing,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootMissing,
                    message: "Configured Codex sessions root was not found."
                )
            ),
        ])
    )

    let summary = AppShellDiagnosticsSummary.make(
        sourceDiscoverySummary: sourceSummary,
        monitoringHealthSummary: .notStarted,
        selectedTranscriptDetail: .noSelection
    )

    #expect(summary.severity == .warning)
    #expect(summary.rows.map(\.category) == [.source])
    #expect(summary.rows.first?.diagnosticCode == "codex.sessions_root_missing")
    #expect(summary.rows.first?.recoveryGuidance.contains("will not create folders") == true)
}

@Test("diagnostics summary elevates blocking watcher and reconciliation failures")
func diagnosticsSummaryElevatesBlockingMonitoringFailures() {
    let sourceID = SessionSourceID(rawValue: "codex-live")
    let monitoringSummary = AppShellMonitoringHealthSummary.make(states: [
        .degraded(LiveMonitoringFailure(
            sourceID: sourceID,
            reason: .reconciliationFailed,
            message: "synthetic reconciliation failure"
        )),
    ])

    let summary = AppShellDiagnosticsSummary.make(
        sourceDiscoverySummary: .placeholder,
        monitoringHealthSummary: monitoringSummary,
        selectedTranscriptDetail: .noSelection
    )

    #expect(summary.severity == .error)
    #expect(summary.statusMessage == "1 blocking diagnostic needs attention.")
    #expect(summary.rows.map(\.category) == [.reconciliation])
    #expect(summary.rows.first?.diagnosticCode == "live_monitoring.reconciliation_failed")
    #expect(summary.rows.first?.recoveryGuidance.contains("manual refresh") == true)
}

@Test("diagnostics summary keeps mixed parse warning watcher failure and refresh failure distinct")
func diagnosticsSummaryKeepsMixedDiagnosticsDistinct() {
    let sourceID = SessionSourceID(rawValue: "codex-live")
    let sourceSummary = AppShellSourceDiscoverySummary.make(
        report: SessionSourceDiscoveryReport(sources: [
            diagnosticsSource(
                id: sourceID,
                displayName: "Codex live",
                location: "/tmp/sessiondeck/live/.codex/sessions",
                availability: .available,
                counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
            ),
        ], candidateFiles: [
            CandidateSessionFile(
                sourceID: sourceID,
                relativePath: "2026/06/06/rollout-warning.jsonl",
                absolutePath: "/tmp/sessiondeck/live/.codex/sessions/2026/06/06/rollout-warning.jsonl",
                byteSize: 42,
                modifiedAt: nil,
                confidence: .high,
                reason: "codex.sessions.date-bucket-jsonl",
                diagnostic: CandidateSessionFileDiagnostic(
                    code: .codexCandidateFileUnreadable,
                    message: "Candidate transcript file could not be read by the current process."
                )
            ),
        ])
    )
    let monitoringSummary = AppShellMonitoringHealthSummary.make(states: [
        .degraded(LiveMonitoringFailure(
            sourceID: sourceID,
            reason: .watcherSetupFailed,
            message: "synthetic watcher setup failure"
        )),
    ])
    let selectedDetail = AppShellSelectedTranscriptDetailState(
        title: "Live session",
        statusMessage: "Refresh failed: synthetic refresh failure Last readable content is still shown.",
        displayMode: .error,
        refreshStatus: .failed(message: "synthetic refresh failure"),
        metadataRows: [],
        rows: [],
        diagnosticMessages: ["Refresh error: synthetic refresh failure"],
        diagnosticRows: [
            AppShellSelectedTranscriptDiagnosticRow(
                id: "refresh-error",
                message: "Refresh error: synthetic refresh failure",
                severity: .error,
                diagnosticCode: "live_refresh.failed"
            ),
        ],
        severity: .error,
        isLoading: false
    )

    let summary = AppShellDiagnosticsSummary.make(
        sourceDiscoverySummary: sourceSummary,
        monitoringHealthSummary: monitoringSummary,
        selectedTranscriptDetail: selectedDetail
    )

    #expect(summary.severity == .error)
    #expect(summary.rows.map(\.category) == [.refresh, .liveMonitoring, .source])
    #expect(summary.rows.map(\.severity) == [.error, .warning, .warning])
    #expect(summary.rows.map(\.diagnosticCode) == [
        "live_refresh.failed",
        "live_monitoring.watcher_setup_failed",
        "codex.candidate_file_unreadable",
    ])
}

@Test("diagnostics summary view has no mutation upload or telemetry affordance")
func diagnosticsSummaryViewHasNoMutationUploadOrTelemetryAffordance() throws {
    let source = try String(
        contentsOf: diagnosticsRepositoryRoot()
            .appending(path: "Sources/SessionDeckApp/Presentation/AppShellDiagnosticsSummaryView.swift"),
        encoding: .utf8
    )

    #expect(source.contains("ForEach(summary.rows)"))
    #expect(source.contains("Text(row.recoveryGuidance)"))
    #expect(!source.contains("Button("))
    #expect(!source.contains("FileManager.default"))
    #expect(!source.contains("URLSession"))
    #expect(!source.localizedCaseInsensitiveContains("telemetry"))
    #expect(!source.localizedCaseInsensitiveContains("jira"))
}

private func diagnosticsSource(
    id: SessionSourceID,
    displayName: String,
    location: String,
    availability: SourceAvailability,
    diagnostic: SessionSourceDiagnostic? = nil,
    counts: SessionSourceCounts = .empty
) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: displayName,
        kind: .codex,
        locationDescription: location,
        isEnabled: true,
        availability: availability,
        diagnostic: diagnostic,
        counts: counts
    )
}

private func diagnosticsRepositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
