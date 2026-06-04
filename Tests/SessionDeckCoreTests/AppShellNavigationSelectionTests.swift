import Foundation
import Testing
@testable import SessionDeckCore

@Test("app shell view model scopes catalog rows to the selected navigation node")
func appShellViewModelScopesCatalogRowsToSelectedNavigationNode() {
    let sourceID = SessionSourceID(rawValue: "codex-selection")
    let useCase = selectionUseCase(
        sourceID: sourceID,
        sessions: [
            selectionSession(
                id: "project-session",
                sourceID: sourceID,
                title: "Project Session",
                projectHint: CatalogProjectHint(
                    cwdPath: "/tmp/SessionDeck",
                    displayName: "SessionDeck"
                )
            ),
            selectionSession(
                id: "loose-chat",
                sourceID: sourceID,
                title: "Loose Chat",
                projectHint: .unavailable
            ),
        ]
    )

    let viewModel = useCase.makeViewModel(selectedNavigationNodeID: "non-project-chats")

    #expect(viewModel.selectedNavigationNodeID == "non-project-chats")
    #expect(viewModel.selectedNavigationTitle == "Non-project Chats")
    #expect(viewModel.catalogSummary.rows.map(\.id.rawValue) == ["loose-chat"])
    #expect(viewModel.catalogSummary.totalCount == 1)
}

@Test("app shell view model keeps empty top-level navigation sections selectable")
func appShellViewModelKeepsEmptyTopLevelNavigationSectionsSelectable() {
    let sourceID = SessionSourceID(rawValue: "codex-empty-selection")
    let useCase = selectionUseCase(sourceID: sourceID, sessions: [])

    let viewModel = useCase.makeViewModel(selectedNavigationNodeID: "diagnostics")

    #expect(viewModel.selectedNavigationNodeID == "diagnostics")
    #expect(viewModel.selectedNavigationTitle == "Diagnostics")
    #expect(viewModel.catalogSummary.rows.isEmpty)
    #expect(viewModel.navigationSummary.sectionNodes.map(\.id).contains("diagnostics"))
}

@Test("app shell view model falls back to all chats when a preserved navigation selection disappears")
func appShellViewModelFallsBackToAllChatsWhenPreservedSelectionDisappears() {
    let sourceID = SessionSourceID(rawValue: "codex-selection-fallback")
    let useCase = selectionUseCase(
        sourceID: sourceID,
        sessions: [
            selectionSession(
                id: "only-session",
                sourceID: sourceID,
                title: "Only Session",
                projectHint: CatalogProjectHint(
                    cwdPath: "/tmp/SessionDeck",
                    displayName: "SessionDeck"
                )
            ),
        ]
    )

    let viewModel = useCase.refreshViewModel(selectedNavigationNodeID: "projects.no-longer-present")

    #expect(viewModel.selectedNavigationNodeID == "all-chats")
    #expect(viewModel.selectedNavigationTitle == "All Chats")
    #expect(viewModel.catalogSummary.rows.map(\.id.rawValue) == ["only-session"])
}

private func selectionUseCase(
    sourceID: SessionSourceID,
    sessions: [SessionSummary]
) -> AppShellUseCase {
    AppShellUseCase(
        launchConfigurationProvider: SelectionLaunchConfigurationProvider(),
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(
                sources: [selectionSource(id: sourceID)]
            ),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
                sourceID: CatalogSourceExtractionResult(sourceID: sourceID, sessions: sessions),
            ]),
            clock: FixedCatalogRefreshClock(now: Date(timeIntervalSince1970: 1_770_100_100))
        )
    )
}

private func selectionSession(
    id: String,
    sourceID: SessionSourceID,
    title: String,
    projectHint: CatalogProjectHint
) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: id),
        identity: CatalogSessionIdentity(rawValue: id),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex selection",
            profileName: nil
        ),
        title: title,
        projectHint: projectHint,
        sessionPath: "/tmp/sessiondeck/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: 1_770_100_100),
        fileSize: CatalogFileSize(byteCount: 512),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}

private func selectionSource(id: SessionSourceID) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: "Codex selection",
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
    )
}

private struct SelectionLaunchConfigurationProvider: LaunchConfigurationProviding {
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
