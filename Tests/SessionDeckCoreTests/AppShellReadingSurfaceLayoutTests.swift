import Foundation
import Testing
@testable import SessionDeckCore

@Test("app shell use case exposes selected transcript master-detail layout state")
func appShellUseCaseExposesSelectedTranscriptMasterDetailLayoutState() {
    let sourceID = SessionSourceID(rawValue: "codex-catalog")
    let session = SessionSummary(
        id: SessionID(rawValue: "selected-layout-session"),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex catalog",
            profileName: "naomi"
        ),
        title: "Selected layout fixture",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck/selected-layout.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 1_024),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
    let useCase = AppShellUseCase(
        launchConfigurationProvider: ReadingSurfaceLaunchConfigurationProvider(),
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(
                sources: [catalogSource(id: sourceID, displayName: "Codex catalog")]
            ),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
                sourceID: CatalogSourceExtractionResult(sourceID: sourceID, sessions: [session])
            ])
        ),
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: FakeSelectedTranscriptLoadingPort(results: [
                session.id: TranscriptDecodeResult(
                    sessionID: session.id,
                    title: "Selected layout transcript",
                    segments: [
                        TranscriptSegment(
                            id: "assistant",
                            kind: .assistantMessage,
                            text: "Readable detail content.",
                            order: TranscriptSegmentOrder(index: 0),
                            source: TranscriptSegmentSourceReference(
                                sourceID: sourceID,
                                relativePath: "selected-layout.jsonl",
                                lineNumber: 1
                            ),
                            timestampDescription: nil
                        ),
                    ],
                    diagnostics: [],
                    isPartial: false
                )
            ])
        )
    )

    let viewModel = useCase.makeViewModel(selectedSessionID: session.id)

    #expect(viewModel.readingSurface.catalogTitle == "All Chats")
    #expect(viewModel.readingSurface.detailTitle == "Selected layout transcript")
    #expect(viewModel.readingSurface.detailDisplayMode == .loaded)
    #expect(viewModel.readingSurface.minimumCatalogPaneWidth == 360)
    #expect(viewModel.readingSurface.minimumTranscriptPaneWidth == 420)
    #expect(viewModel.readingSurface.preservesSidebarContext)
}

private struct ReadingSurfaceLaunchConfigurationProvider: LaunchConfigurationProviding {
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

private func catalogSource(id: SessionSourceID, displayName: String) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: displayName,
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
    )
}
