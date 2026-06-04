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
    #expect(
        failedSummary.emptyState == AppShellCatalogEmptyState(
            title: "Catalog source or index failed",
            detail: "Diagnostics stayed local; no catalog rows were hidden by filters."
        )
    )
}

@Test("catalog summary exposes explicit result state and diagnostic summary")
func catalogSummaryExposesExplicitResultStateAndDiagnosticSummary() {
    let sourceID = SessionSourceID(rawValue: "codex-result-state")
    let source = catalogViewModelSource(id: sourceID)
    let session = catalogViewModelSession(
        id: SessionID(rawValue: "healthy-session"),
        identity: CatalogSessionIdentity(rawValue: "healthy-session"),
        sourceID: sourceID,
        title: "Healthy Session"
    )
    let healthySnapshot = CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_200_005),
        sources: [source],
        sessions: [session]
    )
    let noMatchSummary = AppShellCatalogSummary.make(
        snapshot: healthySnapshot,
        scope: .all,
        queryRequest: CatalogQueryRequest(searchText: "not-present"),
        isFiltered: true
    )
    let mixedWarningSummary = AppShellCatalogSummary.make(
        snapshot: CatalogSnapshot(
            refreshedAt: Date(timeIntervalSince1970: 1_770_200_006),
            sources: [source],
            sessions: [session],
            sourceWarnings: [
                CatalogSnapshotSourceWarning(
                    sourceID: sourceID,
                    displayName: "Codex result state",
                    message: "Source metadata is incomplete."
                )
            ],
            refreshErrors: [
                CatalogSnapshotRefreshError(
                    sourceID: sourceID,
                    displayName: "Codex result state",
                    message: "Catalog extraction failed."
                )
            ]
        )
    )

    #expect(AppShellCatalogSummary.make(snapshot: healthySnapshot).resultState == .matches)
    #expect(noMatchSummary.resultState == .noMatches)
    #expect(noMatchSummary.diagnosticSummary == .none)
    #expect(
        noMatchSummary.emptyState == AppShellCatalogEmptyState(
            title: "No matching catalog rows",
            detail: "Active criteria hide 1 row."
        )
    )
    #expect(mixedWarningSummary.resultState == .warning)
    #expect(mixedWarningSummary.rows.map(\.id.rawValue) == ["healthy-session"])
    #expect(
        mixedWarningSummary.diagnosticSummary == AppShellCatalogDiagnosticSummary(
            entryDiagnosticCount: 0,
            sourceWarningCount: 1,
            sourceFailureCount: 1,
            primaryMessage: "Catalog loaded with source diagnostics."
        )
    )
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

@Test("catalog summary scopes rows from source profile navigation selections")
func catalogSummaryScopesRowsFromSourceProfileNavigationSelections() throws {
    let snapshot = SourceProfileNavigationFixtureCatalog.snapshot()
    let navigationSummary = AppShellNavigationSummary.make(snapshot: snapshot)
    let cliSourceNode = try #require(
        navigationSummary.sourcesNode.children.first { $0.id == "sources.source.codex-cli" }
    )
    let viewerProfileNode = try #require(
        navigationSummary.sourcesNode.children
            .flatMap(\.children)
            .first { $0.id == "sources.source.codex-app.profile.viewer" }
    )
    let unknownSourceNode = try #require(
        navigationSummary.sourcesNode.children.first { $0.id == "sources.unknown-source" }
    )

    let allSummary = AppShellCatalogSummary.make(snapshot: snapshot, scope: .all)
    let cliSummary = AppShellCatalogSummary.make(snapshot: snapshot, scope: cliSourceNode.catalogScope)
    let viewerSummary = AppShellCatalogSummary.make(snapshot: snapshot, scope: viewerProfileNode.catalogScope)
    let unknownSummary = AppShellCatalogSummary.make(snapshot: snapshot, scope: unknownSourceNode.catalogScope)

    #expect(allSummary.rows.map(\.id.rawValue) == [
        "cli-sessiondeck-default",
        "cli-cracker-default",
        "app-sessiondeck-viewer",
        "automation-sessiondeck",
        "unknown-non-project",
    ])
    #expect(cliSummary.rows.map(\.id.rawValue) == [
        "cli-sessiondeck-default",
        "cli-cracker-default",
    ])
    #expect(viewerSummary.rows.map(\.id.rawValue) == ["app-sessiondeck-viewer"])
    #expect(unknownSummary.rows.map(\.id.rawValue) == ["unknown-non-project"])
}

@Test("scoped catalog summary excludes source diagnostics outside the selected scope")
func scopedCatalogSummaryExcludesSourceDiagnosticsOutsideSelectedScope() {
    let selectedSourceID = SessionSourceID(rawValue: "selected-source")
    let unrelatedSourceID = SessionSourceID(rawValue: "unrelated-source")
    let selectedSession = catalogViewModelSession(
        id: SessionID(rawValue: "selected-session"),
        identity: CatalogSessionIdentity(rawValue: "selected-session"),
        sourceID: selectedSourceID,
        title: "Selected Session"
    )
    let selectedScope = SourceProfileSourceNavigationMetadata(
        stableID: "source.selected-source",
        sourceID: selectedSourceID,
        displayName: "Selected Source",
        isFallback: false
    )
    let snapshot = CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_200_004),
        sources: [
            catalogViewModelSource(id: selectedSourceID),
            catalogViewModelSource(id: unrelatedSourceID),
        ],
        sessions: [selectedSession],
        sourceWarnings: [
            CatalogSnapshotSourceWarning(
                sourceID: unrelatedSourceID,
                displayName: "Unrelated Source",
                message: "Unrelated source warning."
            )
        ],
        refreshErrors: [
            CatalogSnapshotRefreshError(
                sourceID: unrelatedSourceID,
                displayName: "Unrelated Source",
                message: "Unrelated source failed."
            )
        ]
    )

    let selectedSummary = AppShellCatalogSummary.make(snapshot: snapshot, scope: .source(selectedScope))
    let allSummary = AppShellCatalogSummary.make(snapshot: snapshot, scope: .all)

    #expect(selectedSummary.rows.map(\.id.rawValue) == ["selected-session"])
    #expect(selectedSummary.sourceWarningCount == 0)
    #expect(selectedSummary.sourceFailureCount == 0)
    #expect(selectedSummary.statusMessage == "Catalog shows 1 entry healthy.")
    #expect(allSummary.sourceWarningCount == 1)
    #expect(allSummary.sourceFailureCount == 1)
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
