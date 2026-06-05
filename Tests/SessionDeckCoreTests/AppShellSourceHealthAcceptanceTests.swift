import Foundation
import Testing
@testable import SessionDeckCore

@Test("source health diagnostics stay visible while healthy catalog sessions remain navigable")
func sourceHealthDiagnosticsStayVisibleWhileHealthySessionsRemainNavigable() {
    let healthySourceID = SessionSourceID(rawValue: "codex-healthy")
    let missingSourceID = SessionSourceID(rawValue: "codex-missing")
    let session = healthySession(sourceID: healthySourceID)
    let useCase = AppShellUseCase(
        launchConfigurationProvider: AcceptanceLaunchConfigurationProvider(),
        discoverSessionSources: DiscoverSessionSourcesUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(sources: [
                source(
                    id: healthySourceID,
                    displayName: "Codex healthy",
                    location: "/tmp/sessiondeck/healthy/.codex/sessions",
                    availability: .available,
                    counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
                ),
                source(
                    id: missingSourceID,
                    displayName: "Codex missing",
                    location: "/tmp/sessiondeck/missing/.codex/sessions",
                    availability: .missing,
                    diagnostic: SessionSourceDiagnostic(
                        code: .codexSessionsRootMissing,
                        message: "Configured Codex sessions root was not found."
                    )
                ),
            ])
        ),
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(sources: [
                source(
                    id: healthySourceID,
                    displayName: "Codex healthy",
                    location: "/tmp/sessiondeck/healthy/.codex/sessions",
                    availability: .available,
                    counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
                ),
            ]),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
                healthySourceID: CatalogSourceExtractionResult(sourceID: healthySourceID, sessions: [session]),
            ]),
            clock: FixedCatalogRefreshClock(now: Date(timeIntervalSince1970: 1_770_200_000))
        )
    )

    let viewModel = useCase.makeViewModel()

    #expect(viewModel.sourceDiscoverySummary.sourceHealthRows.map(\.statusLabel) == [
        "Available",
        "Missing path",
    ])
    #expect(viewModel.sourceDiscoverySummary.sourceHealthRows.map(\.location).allSatisfy {
        $0.hasPrefix("/tmp/sessiondeck")
    })
    #expect(viewModel.catalogSummary.rows.map(\.id) == [session.id])
    #expect(viewModel.navigationSummary.allChatsNode.catalogScope == .sessionIDs([session.id]))
    #expect(viewModel.navigationSummary.problemSessionsNode.children.isEmpty)
}

private struct AcceptanceLaunchConfigurationProvider: LaunchConfigurationProviding {
    func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "SessionDeck",
            subtitle: "Acceptance fixture",
            statusMessage: "Loaded from synthetic fixtures.",
            configuredSourceCount: 0,
            safetyPolicy: .placeholderSafe
        )
    }
}

private func source(
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

private func healthySession(sourceID: SessionSourceID) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: "healthy-session"),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex healthy",
            profileName: nil
        ),
        title: "Healthy source session",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck/healthy/rollout.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: 1_770_200_000),
        fileSize: CatalogFileSize(byteCount: 256),
        metadata: CatalogSessionMetadata(modelName: "gpt-5", agentProfileName: nil),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
