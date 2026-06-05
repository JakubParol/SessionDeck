import Foundation
import Testing
@testable import SessionDeckCore

@Test("source discovery report includes candidate file diagnostics in health summaries")
func sourceDiscoveryReportIncludesCandidateFileDiagnosticsInHealthSummaries() {
    let sourceID = SessionSourceID(rawValue: "codex-primary")
    let source = sourceSummary(
        id: sourceID,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 2)
    )
    let candidate = CandidateSessionFile(
        sourceID: sourceID,
        relativePath: "2026/06/04/rollout-2026-06-04T10-01-00-unreadable.jsonl",
        absolutePath: "/tmp/source/.codex/sessions/2026/06/04/rollout-2026-06-04T10-01-00-unreadable.jsonl",
        byteSize: 128,
        modifiedAt: nil,
        confidence: .high,
        reason: "codex.sessions.date-bucket-jsonl",
        diagnostic: CandidateSessionFileDiagnostic(
            code: .codexCandidateFileUnreadable,
            message: "Candidate transcript file could not be read by the current process."
        )
    )
    let report = SessionSourceDiscoveryReport(sources: [source], candidateFiles: [candidate])

    #expect(report.candidateDiagnostics.map(\.sourceID) == [sourceID])
    #expect(report.candidateDiagnostics.map(\.candidate.relativePath) == [candidate.relativePath])
    #expect(report.healthSummaries.map(\.state) == [.parseWarning])
    #expect(report.healthSummaries.map(\.candidateDiagnosticCode) == [.codexCandidateFileUnreadable])
    #expect(report.healthSummaries.map(\.severity) == [.warning])
}

@Test("source discovery report exposes presentation-facing health summaries")
func sourceDiscoveryReportExposesPresentationFacingHealthSummaries() {
    let healthySource = sourceSummary(
        id: SessionSourceID(rawValue: "codex-healthy"),
        displayName: "Codex healthy",
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 2)
    )
    let missingSource = sourceSummary(
        id: SessionSourceID(rawValue: "codex-missing"),
        displayName: "Codex missing",
        availability: .missing,
        diagnostic: SessionSourceDiagnostic(
            code: .codexSessionsRootMissing,
            message: "Configured Codex sessions root was not found."
        )
    )
    let report = SessionSourceDiscoveryReport(sources: [healthySource, missingSource])

    #expect(report.healthSummaries == [
        SourceHealthSummary(
            sourceID: healthySource.id,
            displayName: "Codex healthy",
            state: .available,
            severity: .info,
            diagnosticCode: nil,
            message: "Source is available with 2 candidate transcript files.",
            allowsDiscoveryToContinue: true
        ),
        SourceHealthSummary(
            sourceID: missingSource.id,
            displayName: "Codex missing",
            state: .missingPath,
            severity: .warning,
            diagnosticCode: .codexSessionsRootMissing,
            message: "Configured Codex sessions root was not found.",
            allowsDiscoveryToContinue: true
        ),
    ])
}

@Test("source discovery report normalizes health states for source diagnostics")
func sourceDiscoveryReportNormalizesHealthStates() {
    let availableID = SessionSourceID(rawValue: "available")
    let missingID = SessionSourceID(rawValue: "missing")
    let permissionID = SessionSourceID(rawValue: "permission-denied")
    let emptyID = SessionSourceID(rawValue: "empty")
    let staleID = SessionSourceID(rawValue: "stale")
    let parseWarningID = SessionSourceID(rawValue: "parse-warning")

    let report = SessionSourceDiscoveryReport(
        sources: [
            sourceSummary(
                id: availableID,
                availability: .available,
                counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
            ),
            sourceSummary(
                id: missingID,
                availability: .missing,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootMissing,
                    message: "Configured Codex sessions root was not found."
                )
            ),
            sourceSummary(
                id: permissionID,
                availability: .inaccessible,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootPermissionDenied,
                    severity: .error,
                    allowsDiscoveryToContinue: false,
                    message: "Configured Codex sessions root exists but the current process does not have read permission."
                )
            ),
            sourceSummary(
                id: emptyID,
                availability: .available,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootEmpty,
                    severity: .info,
                    message: "Configured Codex sessions root is readable but contains no candidate session files yet."
                )
            ),
            sourceSummary(
                id: staleID,
                availability: .available,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootStale,
                    severity: .warning,
                    message: "Configured Codex sessions root has not changed recently."
                )
            ),
            sourceSummary(
                id: parseWarningID,
                availability: .available,
                counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
            ),
        ],
        candidateFiles: [
            CandidateSessionFile(
                sourceID: parseWarningID,
                relativePath: "2026/06/05/rollout-2026-06-05T07-00-00-warning.jsonl",
                absolutePath: "/tmp/sessiondeck/parse-warning.jsonl",
                byteSize: 1,
                modifiedAt: nil,
                confidence: .high,
                reason: "codex.sessions.date-bucket-jsonl",
                diagnostic: CandidateSessionFileDiagnostic(
                    code: .codexCandidateFileUnreadable,
                    message: "Candidate transcript file could not be read by the current process."
                )
            ),
        ]
    )

    #expect(report.healthSummaries.map(\.state) == [
        .available,
        .missingPath,
        .permissionDenied,
        .empty,
        .stale,
        .parseWarning,
    ])
    #expect(report.canContinueDiscovery == false)
}

private func sourceSummary(
    id: SessionSourceID,
    displayName: String? = nil,
    availability: SourceAvailability,
    diagnostic: SessionSourceDiagnostic? = nil,
    counts: SessionSourceCounts = .empty
) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: displayName ?? id.rawValue,
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/\(id.rawValue)",
        isEnabled: true,
        availability: availability,
        diagnostic: diagnostic,
        counts: counts
    )
}
