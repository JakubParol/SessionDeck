import Foundation
import Testing
@testable import SessionDeckCore

@Test("catalog summary distinguishes empty catalog from source failure")
func catalogSummaryDistinguishesEmptyCatalogFromSourceFailure() {
    let sourceID = SessionSourceID(rawValue: "codex-empty")
    let source = catalogViewModelSource(id: sourceID)
    let emptySummary = AppShellCatalogSummary.make(
        snapshot: CatalogSnapshot(
            refreshedAt: Date(timeIntervalSince1970: 1_770_200_000),
            sources: [source],
            sessions: []
        )
    )
    let failedSummary = AppShellCatalogSummary.make(
        snapshot: CatalogSnapshot(
            refreshedAt: Date(timeIntervalSince1970: 1_770_200_001),
            sources: [source],
            sessions: [],
            refreshErrors: [
                CatalogSnapshotRefreshError(
                    sourceID: sourceID,
                    displayName: "Codex empty",
                    message: "Catalog extraction failed."
                )
            ]
        )
    )

    #expect(emptySummary.rows.isEmpty)
    #expect(emptySummary.sourceFailureCount == 0)
    #expect(emptySummary.statusMessage == "No catalog entries yet.")
    #expect(failedSummary.rows.isEmpty)
    #expect(failedSummary.sourceFailureCount == 1)
    #expect(failedSummary.statusMessage == "Catalog refresh failed for 1 source.")
}

@Test("catalog summary maps snapshot diagnostics onto visible rows")
func catalogSummaryMapsSnapshotDiagnosticsOntoRows() {
    let sourceID = SessionSourceID(rawValue: "codex-duplicates")
    let sessionID = SessionID(rawValue: "duplicate-session")
    let identity = CatalogSessionIdentity(rawValue: "shared-identity")
    let session = catalogViewModelSession(
        id: sessionID,
        identity: identity,
        sourceID: sourceID,
        title: "Shared Session"
    )
    let summary = AppShellCatalogSummary.make(
        snapshot: CatalogSnapshot(
            refreshedAt: Date(timeIntervalSince1970: 1_770_200_002),
            sources: [catalogViewModelSource(id: sourceID)],
            sessions: [session],
            diagnostics: [
                CatalogSnapshotDiagnostic(
                    code: .duplicateSessionIdentity,
                    severity: .warning,
                    identity: identity,
                    sessionIDs: [sessionID],
                    message: "Duplicate session identity shared-identity appears in 1 catalog entry."
                )
            ]
        )
    )

    #expect(summary.totalCount == 1)
    #expect(summary.diagnosticCount == 1)
    #expect(summary.rows.first?.statusLabel == "Catalog diagnostics")
    #expect(summary.rows.first?.diagnosticSummary == "Duplicate session identity shared-identity appears in 1 catalog entry.")
    #expect(summary.rows.first?.severity == .warning)
}

private func catalogViewModelSource(id: SessionSourceID) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: "Codex empty",
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
    )
}

private func catalogViewModelSession(
    id: SessionID,
    identity: CatalogSessionIdentity,
    sourceID: SessionSourceID,
    title: String
) -> SessionSummary {
    SessionSummary(
        id: id,
        identity: identity,
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex duplicates",
            profileName: nil
        ),
        title: title,
        projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck/duplicate.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: 1_770_200_003),
        fileSize: CatalogFileSize(byteCount: 512),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
