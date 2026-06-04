import Foundation
import Testing
@testable import SessionDeckCore

@Test("app shell catalog query controls filter rows through application state")
func appShellCatalogQueryControlsFilterRowsThroughApplicationState() throws {
    let sourceID = SessionSourceID(rawValue: "codex-query")
    let useCase = catalogQueryUseCase(
        sourceID: sourceID,
        sessions: [
            catalogQuerySession(
                id: "sessiondeck-naomi",
                sourceID: sourceID,
                sourceDisplayName: "Codex Query",
                profileName: "Naomi",
                title: "Sprint Planning",
                previewText: "Search controls acceptance notes",
                projectName: "SessionDeck",
                cwdPath: "/tmp/SessionDeck",
                lastActivity: 300,
                parseStatus: .complete
            ),
            catalogQuerySession(
                id: "sessiondeck-diagnostic",
                sourceID: sourceID,
                sourceDisplayName: "Codex Query",
                profileName: "Naomi",
                title: "Diagnostic Followup",
                previewText: "Search controls acceptance notes",
                projectName: "SessionDeck",
                cwdPath: "/tmp/SessionDeck",
                lastActivity: 400,
                parseStatus: .malformed(reason: "Fixture malformed line.")
            ),
            catalogQuerySession(
                id: "other-project",
                sourceID: sourceID,
                sourceDisplayName: "Codex Query",
                profileName: "James",
                title: "Sprint Planning",
                previewText: "Search controls acceptance notes",
                projectName: "Other",
                cwdPath: "/tmp/Other",
                lastActivity: 500,
                parseStatus: .complete
            ),
        ]
    )
    let initial = useCase.makeViewModel()
    let projectID = try #require(
        initial.catalogQueryControls.options.projectOptions.first { $0.title == "SessionDeck" }?.id
    )
    let sourceIDOption = try #require(
        initial.catalogQueryControls.options.sourceOptions.first { $0.title == "Codex Query" }?.id
    )
    let profileID = try #require(
        initial.catalogQueryControls.options.profileOptions.first { $0.title == "Naomi" }?.id
    )
    let completeID = try #require(
        initial.catalogQueryControls.options.parseStatusOptions.first { $0.title == "Healthy" }?.id
    )

    let filtered = useCase.makeViewModel(
        catalogQuery: AppShellCatalogQueryState(
            searchText: "sprint",
            selectedProjectOptionID: projectID,
            selectedSourceOptionID: sourceIDOption,
            selectedProfileOptionID: profileID,
            selectedParseStatusOptionIDs: [completeID]
        )
    )

    #expect(filtered.catalogSummary.rows.map(\.id.rawValue) == ["sessiondeck-naomi"])
    #expect(filtered.catalogSummary.totalCount == 1)
    #expect(filtered.catalogSummary.unfilteredTotalCount == 3)
    #expect(filtered.catalogQueryControls.activeFilterLabels == [
        "Search: sprint",
        "SessionDeck",
        "Codex Query",
        "Naomi",
        "Healthy",
    ])
}

@Test("app shell catalog query exposes no-result and clear behavior")
func appShellCatalogQueryExposesNoResultAndClearBehavior() {
    let sourceID = SessionSourceID(rawValue: "codex-query-clear")
    let useCase = catalogQueryUseCase(
        sourceID: sourceID,
        sessions: [
            catalogQuerySession(
                id: "first",
                sourceID: sourceID,
                title: "First catalog row",
                lastActivity: 200
            ),
            catalogQuerySession(
                id: "second",
                sourceID: sourceID,
                title: "Second catalog row",
                lastActivity: 100
            ),
        ]
    )

    let noResult = useCase.makeViewModel(
        catalogQuery: AppShellCatalogQueryState(searchText: "not-present")
    )
    let restored = useCase.makeViewModel(
        catalogQuery: noResult.catalogQueryControls.queryState.cleared()
    )

    #expect(noResult.catalogSummary.rows.isEmpty)
    #expect(noResult.catalogSummary.isFiltered)
    #expect(noResult.catalogSummary.unfilteredTotalCount == 2)
    #expect(noResult.catalogSummary.statusMessage == "No catalog rows match active filters.")
    #expect(noResult.catalogQueryControls.hasActiveFilters)
    #expect(restored.catalogQueryControls.queryState == .empty)
    #expect(restored.catalogSummary.rows.map(\.id.rawValue) == ["first", "second"])
}

private func catalogQueryUseCase(
    sourceID: SessionSourceID,
    sessions: [SessionSummary]
) -> AppShellUseCase {
    AppShellUseCase(
        launchConfigurationProvider: CatalogQueryLaunchConfigurationProvider(),
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(
                sources: [catalogQuerySource(id: sourceID)]
            ),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
                sourceID: CatalogSourceExtractionResult(sourceID: sourceID, sessions: sessions),
            ]),
            clock: FixedCatalogRefreshClock(now: Date(timeIntervalSince1970: 1_770_200_200))
        )
    )
}

private func catalogQuerySource(id: SessionSourceID) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: "Codex Query",
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 2)
    )
}

private func catalogQuerySession(
    id: String,
    sourceID: SessionSourceID,
    sourceDisplayName: String = "Codex Query",
    profileName: String? = nil,
    title: String,
    previewText: String? = nil,
    projectName: String? = "SessionDeck",
    cwdPath: String? = "/tmp/SessionDeck",
    lastActivity: Int64,
    parseStatus: CatalogParseStatus = .complete
) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: id),
        identity: CatalogSessionIdentity(rawValue: id),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: sourceDisplayName,
            profileName: profileName
        ),
        title: title,
        previewText: previewText,
        projectHint: projectName.map {
            CatalogProjectHint(cwdPath: cwdPath, displayName: $0)
        } ?? .unavailable,
        sessionPath: "/tmp/sessiondeck/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: lastActivity),
        fileSize: CatalogFileSize(byteCount: 512),
        metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: profileName),
        health: CatalogEntryHealth(parseStatus: parseStatus)
    )
}

private struct CatalogQueryLaunchConfigurationProvider: LaunchConfigurationProviding {
    func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "Fake SessionDeck",
            subtitle: "Injected application state",
            statusMessage: "Loaded from a fake provider.",
            configuredSourceCount: 0,
            safetyPolicy: .placeholderSafe
        )
    }
}
