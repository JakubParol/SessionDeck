import Foundation
import Testing
@testable import SessionDeckCore

@Test("catalog refresh use case returns a timestamped snapshot from discovered sources")
func catalogRefreshUseCaseReturnsTimestampedSnapshotFromDiscoveredSources() throws {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let source = makeSource(id: sourceID, displayName: "Codex default")
    let session = makeSession(id: "codex-1", sourceID: sourceID, title: "Build refresh snapshots")
    let refreshedAt = Date(timeIntervalSince1970: 1_770_100_000)
    let useCase = RefreshCatalogSnapshotUseCase(
        sourceDiscovery: FakeSourceDiscoveryPort(sources: [source]),
        metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
            sourceID: CatalogSourceExtractionResult(sourceID: sourceID, sessions: [session])
        ]),
        clock: FixedCatalogRefreshClock(now: refreshedAt)
    )

    let snapshot = try useCase.refreshSnapshot()

    #expect(snapshot.refreshedAt == refreshedAt)
    #expect(snapshot.sources == [source])
    #expect(snapshot.sessions == [session])
    #expect(snapshot.counts.totalEntries == 1)
    #expect(snapshot.counts.healthyEntries == 1)
    #expect(snapshot.counts.diagnosticEntries == 0)
    #expect(snapshot.sourceWarnings.isEmpty)
    #expect(snapshot.refreshErrors.isEmpty)
}

private func makeSource(
    id: SessionSourceID,
    displayName: String,
    availability: SourceAvailability = .available,
    diagnostic: SessionSourceDiagnostic? = nil
) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: displayName,
        kind: .codex,
        locationDescription: "Synthetic fixture source",
        isEnabled: true,
        availability: availability,
        diagnostic: diagnostic,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
    )
}

private func makeSession(
    id: String,
    sourceID: SessionSourceID,
    title: String?,
    lastActivity: Int64? = 1_770_000_000,
    parseStatus: CatalogParseStatus = .complete,
    diagnostics: [CatalogEntryDiagnostic] = []
) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Synthetic source",
            profileName: "test"
        ),
        title: title,
        projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: lastActivity),
        fileSize: CatalogFileSize(byteCount: 128),
        metadata: CatalogSessionMetadata(modelName: "gpt-test", agentProfileName: "test"),
        health: CatalogEntryHealth(parseStatus: parseStatus, diagnostics: diagnostics)
    )
}
