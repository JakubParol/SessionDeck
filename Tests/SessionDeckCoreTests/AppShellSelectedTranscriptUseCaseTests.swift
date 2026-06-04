import Foundation
import Testing
@testable import SessionDeckCore

@Test("app shell use case loads transcript detail for the selected catalog row")
func appShellUseCaseLoadsSelectedTranscriptDetail() throws {
    let session = selectedCatalogSession()
    let useCase = AppShellUseCase(
        launchConfigurationProvider: selectedTranscriptLaunchConfigurationProvider(),
        refreshCatalogSnapshot: selectedTranscriptCatalogSnapshot(sessions: [session]),
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: FakeSelectedTranscriptLoadingPort(
                results: [
                    session.id: TranscriptDecodeResult(
                        sessionID: session.id,
                        title: "Selected transcript",
                        segments: [
                            TranscriptSegment(
                                id: "user",
                                kind: .userMessage,
                                text: "Open this session.",
                                order: TranscriptSegmentOrder(index: 0),
                                source: TranscriptSegmentSourceReference(
                                    sourceID: session.sourceID,
                                    relativePath: "selected.jsonl",
                                    lineNumber: 1
                                ),
                                timestampDescription: nil
                            ),
                        ],
                        diagnostics: [],
                        isPartial: false
                    )
                ]
            )
        )
    )

    let viewModel = useCase.makeViewModel(selectedSessionID: session.id)

    #expect(viewModel.selectedTranscriptDetail.title == "Selected transcript")
    #expect(viewModel.selectedTranscriptDetail.statusMessage == "Loaded 1 transcript segment(s).")
    #expect(viewModel.selectedTranscriptDetail.rows.map(\.text) == ["Open this session."])
}

@Test("app shell use case renders unavailable detail state for missing selected rows")
func appShellUseCaseRendersUnavailableDetailForMissingSelection() {
    let useCase = AppShellUseCase(
        launchConfigurationProvider: selectedTranscriptLaunchConfigurationProvider(),
        refreshCatalogSnapshot: selectedTranscriptCatalogSnapshot(sessions: [])
    )

    let viewModel = useCase.makeViewModel(selectedSessionID: SessionID(rawValue: "missing-session"))

    #expect(viewModel.selectedTranscriptDetail.title == "Transcript unavailable")
    #expect(viewModel.selectedTranscriptDetail.statusMessage == "The selected session cannot be loaded yet.")
    #expect(viewModel.selectedTranscriptDetail.severity == .warning)
}

@Test("app shell use case keeps selected session identifiable when transcript loading fails")
func appShellUseCaseKeepsSelectedSessionIdentifiableWhenTranscriptLoadingFails() {
    let session = selectedCatalogSession()
    let useCase = AppShellUseCase(
        launchConfigurationProvider: selectedTranscriptLaunchConfigurationProvider(),
        refreshCatalogSnapshot: selectedTranscriptCatalogSnapshot(sessions: [session]),
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: FakeSelectedTranscriptLoadingPort(
                errorsBySessionID: [
                    session.id: SelectedTranscriptLoadingError.transcriptUnreadable(session.id)
                ]
            )
        )
    )

    let viewModel = useCase.makeViewModel(selectedSessionID: session.id)

    #expect(viewModel.selectedTranscriptDetail.title == "Selected fixture")
    #expect(viewModel.selectedTranscriptDetail.statusMessage == "The selected transcript file cannot be read.")
    #expect(viewModel.selectedTranscriptDetail.severity == .error)
    #expect(viewModel.selectedTranscriptDetail.metadataRows.map(\.title).contains("Path"))
    #expect(viewModel.selectedTranscriptDetail.metadataRows.map(\.value).contains(
        "/tmp/sessiondeck-fixture/.codex/sessions/selected.jsonl"
    ))
}

private func selectedTranscriptLaunchConfigurationProvider() -> LaunchConfigurationProviding {
    SelectedTranscriptLaunchConfigurationProvider()
}

private func selectedTranscriptCatalogSnapshot(
    sessions: [SessionSummary]
) -> RefreshCatalogSnapshotUseCase {
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    return RefreshCatalogSnapshotUseCase(
        sourceDiscovery: FakeSourceDiscoveryPort(
            sources: [
                SessionSourceSummary(
                    id: sourceID,
                    displayName: "Codex fixture",
                    kind: .codex,
                    locationDescription: "/tmp/sessiondeck-fixture/.codex/sessions",
                    isEnabled: true,
                    availability: .available,
                    counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: sessions.count)
                )
            ]
        ),
        metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
            sourceID: CatalogSourceExtractionResult(sourceID: sourceID, sessions: sessions)
        ]),
        clock: FixedCatalogRefreshClock(now: Date(timeIntervalSince1970: 1_770_100_000))
    )
}

private func selectedCatalogSession() -> SessionSummary {
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    return SessionSummary(
        id: SessionID(rawValue: "selected-session"),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex fixture",
            profileName: "Fixture"
        ),
        title: "Selected fixture",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck-fixture/.codex/sessions/selected.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}

private struct SelectedTranscriptLaunchConfigurationProvider: LaunchConfigurationProviding {
    func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "SessionDeck",
            subtitle: "Selected transcript fixture",
            statusMessage: "Loaded from fakes.",
            configuredSourceCount: 1,
            safetyPolicy: .placeholderSafe
        )
    }
}
