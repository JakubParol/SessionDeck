import Foundation
import Testing
@testable import SessionDeckCore

@Test("application source discovery summary exposes source health rows for diagnostics UI")
func applicationSourceDiscoverySummaryExposesSourceHealthRows() {
    let availableID = SessionSourceID(rawValue: "available")
    let missingID = SessionSourceID(rawValue: "missing")
    let permissionID = SessionSourceID(rawValue: "permission-denied")
    let emptyID = SessionSourceID(rawValue: "empty")
    let staleID = SessionSourceID(rawValue: "stale")
    let warningID = SessionSourceID(rawValue: "parse-warning")

    let report = SessionSourceDiscoveryReport(
        sources: [
            sourceHealthFixture(
                id: availableID,
                displayName: "Codex available",
                location: "/tmp/sessiondeck/available/.codex/sessions",
                availability: .available,
                counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 2)
            ),
            sourceHealthFixture(
                id: missingID,
                displayName: "Codex missing",
                location: "/tmp/sessiondeck/missing/.codex/sessions",
                availability: .missing,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootMissing,
                    message: "Configured Codex sessions root was not found."
                )
            ),
            sourceHealthFixture(
                id: permissionID,
                displayName: "Codex permission",
                location: "/tmp/sessiondeck/permission/.codex/sessions",
                availability: .inaccessible,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootPermissionDenied,
                    severity: .error,
                    allowsDiscoveryToContinue: false,
                    message: "Configured Codex sessions root exists but the current process does not have read permission."
                )
            ),
            sourceHealthFixture(
                id: emptyID,
                displayName: "Codex empty",
                location: "/tmp/sessiondeck/empty/.codex/sessions",
                availability: .available,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootEmpty,
                    severity: .info,
                    message: "Configured Codex sessions root is readable but contains no candidate session files yet."
                )
            ),
            sourceHealthFixture(
                id: staleID,
                displayName: "Codex stale",
                location: "/tmp/sessiondeck/stale/.codex/sessions",
                availability: .available,
                diagnostic: SessionSourceDiagnostic(
                    code: .codexSessionsRootStale,
                    severity: .warning,
                    message: "Configured Codex sessions root has not changed recently."
                )
            ),
            sourceHealthFixture(
                id: warningID,
                displayName: "Codex warnings",
                location: "/tmp/sessiondeck/warnings/.codex/sessions",
                availability: .available,
                counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
            ),
        ],
        candidateFiles: [
            CandidateSessionFile(
                sourceID: warningID,
                relativePath: "2026/06/05/rollout-2026-06-05T07-00-00-warning.jsonl",
                absolutePath: "/tmp/sessiondeck/warnings/.codex/sessions/2026/06/05/rollout.jsonl",
                byteSize: 12,
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

    let summary = AppShellSourceDiscoverySummary.make(report: report)

    #expect(summary.sourceHealthRows.map(\.id) == [
        "available",
        "missing",
        "permission-denied",
        "empty",
        "stale",
        "parse-warning",
    ])
    #expect(summary.sourceHealthRows.map(\.statusLabel) == [
        "Available",
        "Missing path",
        "Permission denied",
        "Empty",
        "Stale",
        "Parse warning",
    ])
    #expect(summary.sourceHealthRows.map(\.severity) == [
        .healthy,
        .warning,
        .error,
        .info,
        .warning,
        .warning,
    ])
    #expect(summary.sourceHealthRows.first?.detail == "2 candidate transcripts in 1 bucket.")
    #expect(summary.sourceHealthRows[2].isBlocking)
    #expect(summary.sourceHealthRows.allSatisfy { $0.location.hasPrefix("/tmp/sessiondeck") })
}

private func sourceHealthFixture(
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
