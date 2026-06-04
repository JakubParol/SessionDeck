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

@Test("catalog refresh keeps duplicate identities visible and emits deterministic diagnostics")
func catalogRefreshKeepsDuplicateIdentitiesVisibleAndEmitsDeterministicDiagnostics() throws {
    let primarySourceID = SessionSourceID(rawValue: "codex-primary")
    let secondarySourceID = SessionSourceID(rawValue: "codex-secondary")
    let duplicateIdentity = CatalogSessionIdentity(rawValue: "shared-session")
    let primarySession = makeSession(
        id: "primary-session",
        identity: duplicateIdentity,
        sourceID: primarySourceID,
        title: "Primary",
        lastActivity: 200
    )
    let secondarySession = makeSession(
        id: "secondary-session",
        identity: duplicateIdentity,
        sourceID: secondarySourceID,
        title: "Secondary",
        lastActivity: 100
    )
    let useCase = RefreshCatalogSnapshotUseCase(
        sourceDiscovery: FakeSourceDiscoveryPort(sources: [
            makeSource(id: primarySourceID, displayName: "Codex primary"),
            makeSource(id: secondarySourceID, displayName: "Codex secondary"),
        ]),
        metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
            primarySourceID: CatalogSourceExtractionResult(sourceID: primarySourceID, sessions: [primarySession]),
            secondarySourceID: CatalogSourceExtractionResult(sourceID: secondarySourceID, sessions: [secondarySession]),
        ]),
        clock: FixedCatalogRefreshClock(now: Date(timeIntervalSince1970: 1))
    )

    let snapshot = try useCase.refreshSnapshot()

    #expect(snapshot.sessions.map(\.id.rawValue) == ["primary-session", "secondary-session"])
    #expect(snapshot.diagnostics == [
        CatalogSnapshotDiagnostic(
            code: .duplicateSessionIdentity,
            severity: .warning,
            identity: duplicateIdentity,
            sessionIDs: [SessionID(rawValue: "primary-session"), SessionID(rawValue: "secondary-session")],
            message: "Duplicate session identity shared-session appears in 2 catalog entries."
        )
    ])
    #expect(snapshot.counts.totalEntries == 2)
    #expect(snapshot.counts.diagnosticEntries == 2)
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
    identity: CatalogSessionIdentity? = nil,
    sourceID: SessionSourceID,
    title: String?,
    lastActivity: Int64? = 1_770_000_000,
    parseStatus: CatalogParseStatus = .complete,
    diagnostics: [CatalogEntryDiagnostic] = []
) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: id),
        identity: identity,
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
