import Foundation
import Testing
@testable import SessionDeckCore

@Test("monitoring diagnostics stay visible while catalog browsing remains available")
func monitoringDiagnosticsStayVisibleWhileCatalogBrowsingRemainsAvailable() {
    let sourceID = SessionSourceID(rawValue: "codex-live")
    let session = monitoringAcceptanceSession(sourceID: sourceID)
    let useCase = AppShellUseCase(
        launchConfigurationProvider: MonitoringAcceptanceLaunchConfigurationProvider(),
        discoverSessionSources: DiscoverSessionSourcesUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(sources: [
                monitoringAcceptanceSource(sourceID: sourceID),
            ])
        ),
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(sources: [
                monitoringAcceptanceSource(sourceID: sourceID),
            ]),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
                sourceID: CatalogSourceExtractionResult(sourceID: sourceID, sessions: [session]),
            ]),
            clock: FixedCatalogRefreshClock(now: Date(timeIntervalSince1970: 1_770_500_000))
        ),
        liveMonitoringStateProvider: {
            [
                .watching(sourceID: sourceID),
                .stale(sourceID: sourceID, reason: .missedChangeRecovered),
                .degraded(LiveMonitoringFailure(
                    sourceID: sourceID,
                    reason: .reconciliationFailed,
                    message: "synthetic reconciliation failure"
                )),
            ]
        }
    )

    let viewModel = useCase.makeViewModel()

    #expect(viewModel.monitoringHealthSummary.severity == .error)
    #expect(viewModel.monitoringHealthSummary.rows.map(\.title) == [
        "Reconciliation failed",
        "Reconciliation fallback active",
        "Watcher healthy",
    ])
    #expect(viewModel.monitoringHealthSummary.rows.map(\.diagnosticCode) == [
        "live_monitoring.reconciliation_failed",
        "live_monitoring.missed_change_recovered",
        nil,
    ])
    #expect(viewModel.catalogSummary.rows.map(\.id) == [session.id])
    #expect(viewModel.safetyPolicy.readsRealAgentStores == false)
}

@Test("refresh failure diagnostic preserves prior readable transcript content")
func refreshFailureDiagnosticPreservesPriorReadableTranscriptContent() {
    let sourceID = SessionSourceID(rawValue: "codex-live")
    let sessionID = SessionID(rawValue: "live-session")
    let readModel = SelectedTranscriptReadModel(
        session: monitoringAcceptanceSession(id: sessionID, sourceID: sourceID),
        decodeResult: TranscriptDecodeResult(
            sessionID: sessionID,
            title: "Live session",
            segments: [
                TranscriptSegment(
                    id: "line-1",
                    kind: .assistantMessage,
                    text: "Already readable content.",
                    order: TranscriptSegmentOrder(index: 0),
                    source: TranscriptSegmentSourceReference(
                        sourceID: sourceID,
                        relativePath: "live-session.jsonl",
                        lineNumber: 1
                    ),
                    timestampDescription: nil
                ),
            ],
            diagnostics: [],
            isPartial: false
        )
    )

    let state = AppShellSelectedTranscriptDetailState.liveRefresh(
        .failed(previous: readModel, message: "synthetic append refresh failed")
    )

    #expect(state.severity == .error)
    #expect(state.statusMessage == "Refresh failed: synthetic append refresh failed Last readable content is still shown.")
    #expect(state.rows.map(\.text) == ["Already readable content."])
    #expect(state.diagnosticRows.map(\.message) == ["Refresh error: synthetic append refresh failed"])
}

private struct MonitoringAcceptanceLaunchConfigurationProvider: LaunchConfigurationProviding {
    func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "SessionDeck",
            subtitle: "Monitoring acceptance fixture",
            statusMessage: "Loaded from controlled fakes.",
            configuredSourceCount: 0,
            safetyPolicy: LaunchSafetyPolicy(
                readsRealAgentStores: false,
                permitsNetworkCalls: false,
                permitsCommandExecution: false,
                permitsSessionMutation: false
            )
        )
    }
}

private func monitoringAcceptanceSource(sourceID: SessionSourceID) -> SessionSourceSummary {
    SessionSourceSummary(
        id: sourceID,
        displayName: "Codex live fixture",
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/live/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
    )
}

private func monitoringAcceptanceSession(
    id: SessionID = SessionID(rawValue: "live-session"),
    sourceID: SessionSourceID
) -> SessionSummary {
    SessionSummary(
        id: id,
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex live fixture",
            profileName: nil
        ),
        title: "Live session",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck/live/.codex/sessions/live-session.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        metadata: CatalogSessionMetadata(modelName: "gpt-5", agentProfileName: nil),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
