import Testing
import Foundation
@testable import SessionDeckCore

@Test("source discovery use case returns source summaries through an injected fake port")
func sourceDiscoveryUseCaseUsesFakePort() throws {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let useCase = DiscoverSessionSourcesUseCase(
        sourceDiscovery: FakeSourceDiscoveryPort(
            sources: [
                SessionSourceSummary(
                    id: sourceID,
                    displayName: "Codex default profile",
                    kind: .codex,
                    locationDescription: "Synthetic fixture source",
                    isEnabled: true
                )
            ]
        )
    )

    let sources = try useCase.discoverSources()

    #expect(sources == [
        SessionSourceSummary(
            id: sourceID,
            displayName: "Codex default profile",
            kind: .codex,
            locationDescription: "Synthetic fixture source",
            isEnabled: true
        )
    ])
}

@Test("source discovery report preserves healthy sources and failed diagnostics")
func sourceDiscoveryReportPreservesHealthySourcesAndFailedDiagnostics() throws {
    let healthySource = SessionSourceSummary(
        id: SessionSourceID(rawValue: "codex-healthy"),
        displayName: "Codex healthy",
        kind: .codex,
        locationDescription: "Synthetic healthy source",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 2)
    )
    let failedSource = SessionSourceSummary(
        id: SessionSourceID(rawValue: "codex-missing"),
        displayName: "Codex missing",
        kind: .codex,
        locationDescription: "Synthetic missing source",
        isEnabled: true,
        availability: .missing,
        diagnostic: SessionSourceDiagnostic(
            code: .codexSessionsRootMissing,
            message: "Configured Codex sessions root was not found."
        )
    )
    let useCase = DiscoverSessionSourcesUseCase(
        sourceDiscovery: FakeSourceDiscoveryPort(sources: [healthySource, failedSource])
    )

    let report = try useCase.discoveryReport()

    #expect(report.sources == [healthySource, failedSource])
    #expect(report.availableSources == [healthySource])
    #expect(report.diagnostics.map(\.sourceID) == [failedSource.id])
    #expect(report.diagnostics.map(\.diagnostic.code) == [.codexSessionsRootMissing])
    #expect(report.canContinueDiscovery)
}

@Test("candidate file enumeration use case returns bounded metadata through an injected fake port")
func candidateFileEnumerationUseCaseUsesFakePort() throws {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let modifiedAt = Date(timeIntervalSince1970: 1_770_000_000)
    let candidate = CandidateSessionFile(
        sourceID: sourceID,
        relativePath: "2026/06/04/rollout-2026-06-04T10-00-00-test.jsonl",
        absolutePath: "/tmp/source/.codex/sessions/2026/06/04/rollout-2026-06-04T10-00-00-test.jsonl",
        byteSize: 4096,
        modifiedAt: modifiedAt,
        confidence: .high,
        reason: "codex.sessions.jsonl",
        diagnostic: nil
    )
    let useCase = EnumerateCandidateSessionFilesUseCase(
        candidateFileEnumeration: FakeCandidateSessionFileEnumerationPort(files: [candidate])
    )

    let files = try useCase.enumerateCandidateFiles(sourceID: sourceID)

    #expect(files == [candidate])
}

@Test("source diagnostics expose typed codes for application and presentation DTOs")
func sourceDiagnosticsExposeTypedCodes() throws {
    let sourceDiagnostic = SessionSourceDiagnostic(
        code: .codexSessionsRootMissing,
        message: "Configured Codex sessions root was not found."
    )
    let candidateDiagnostic = CandidateSessionFileDiagnostic(
        code: .codexCandidateFileUnreadable,
        message: "Candidate transcript file could not be read by the current process."
    )

    #expect(sourceDiagnostic.code == .codexSessionsRootMissing)
    #expect(candidateDiagnostic.code == .codexCandidateFileUnreadable)
}

@Test("source diagnostics expose severity and continuation policy")
func sourceDiagnosticsExposeSeverityAndContinuationPolicy() throws {
    let missingDiagnostic = SessionSourceDiagnostic(
        code: .codexSessionsRootMissing,
        severity: .warning,
        allowsDiscoveryToContinue: true,
        message: "Configured Codex sessions root was not found."
    )
    let unreadableCandidateDiagnostic = CandidateSessionFileDiagnostic(
        code: .codexCandidateFileUnreadable,
        severity: .warning,
        allowsDiscoveryToContinue: true,
        message: "Candidate transcript file could not be read by the current process."
    )

    #expect(missingDiagnostic.severity == .warning)
    #expect(missingDiagnostic.allowsDiscoveryToContinue)
    #expect(unreadableCandidateDiagnostic.severity == .warning)
    #expect(unreadableCandidateDiagnostic.allowsDiscoveryToContinue)
}

@Test("session catalog use case filters session summaries through an injected fake port")
func sessionCatalogUseCaseUsesFakePort() throws {
    let codexSourceID = SessionSourceID(rawValue: "codex-default")
    let hermesSourceID = SessionSourceID(rawValue: "hermes-naomi")
    let codexSession = SessionSummary(
        id: SessionID(rawValue: "codex-1"),
        sourceID: codexSourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: codexSourceID.rawValue,
            displayName: "Codex default",
            profileName: "default"
        ),
        title: "Implement app shell",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/codex-1.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1_770_000_000, lastActivityEpochSeconds: 1_770_001_000),
        fileSize: CatalogFileSize(byteCount: 4096),
        metadata: CatalogSessionMetadata(modelName: "gpt-test", agentProfileName: "default"),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
    let hermesSession = SessionSummary(
        id: SessionID(rawValue: "hermes-1"),
        sourceID: hermesSourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: hermesSourceID.rawValue,
            displayName: "Hermes Naomi",
            profileName: "naomi"
        ),
        title: "Review handoff",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/hermes-1.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1_770_000_000, lastActivityEpochSeconds: 1_770_002_000),
        fileSize: CatalogFileSize(byteCount: 2048),
        metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: "naomi"),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
    let useCase = ListSessionsUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [codexSession, hermesSession])
    )

    let sessions = try useCase.listSessions(sourceID: codexSourceID)

    #expect(sessions == [codexSession])
}

@Test("session catalog use case filters catalog selection scopes")
func sessionCatalogUseCaseFiltersCatalogSelectionScopes() throws {
    let codexSourceID = SessionSourceID(rawValue: "codex-default")
    let otherSourceID = SessionSourceID(rawValue: "other-default")
    let codexSourceMetadata = SourceProfileSourceNavigationMetadata(
        stableID: "source.codex-default",
        sourceID: codexSourceID,
        displayName: "Codex Default",
        isFallback: false
    )
    let codexViewerProfileMetadata = SourceProfileProfileNavigationMetadata(
        stableID: "source.codex-default.profile.viewer",
        sourceID: codexSourceID,
        sourceStableID: codexSourceMetadata.stableID,
        displayName: "viewer",
        isFallback: false
    )
    let codexDefault = scopedCatalogSession(
        id: "codex-default-profile",
        sourceID: codexSourceID,
        sourceDisplayName: "Codex Default",
        profileName: "default",
        lastActivity: 10
    )
    let codexViewer = scopedCatalogSession(
        id: "codex-viewer-profile",
        sourceID: codexSourceID,
        sourceDisplayName: "Codex Default",
        profileName: "viewer",
        lastActivity: 30
    )
    let otherViewer = scopedCatalogSession(
        id: "other-viewer-profile",
        sourceID: otherSourceID,
        sourceDisplayName: "Other Default",
        profileName: "viewer",
        lastActivity: 20
    )
    let useCase = ListSessionsUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [codexDefault, codexViewer, otherViewer])
    )

    let allSessions = try useCase.listSessions(scope: .all)
    let sourceSessions = try useCase.listSessions(scope: .source(codexSourceMetadata))
    let profileSessions = try useCase.listSessions(scope: .profile(codexViewerProfileMetadata))
    let selectedSessions = try useCase.listSessions(scope: .sessionIDs([codexDefault.id, otherViewer.id]))

    #expect(allSessions.map(\.id.rawValue) == [
        "codex-viewer-profile",
        "other-viewer-profile",
        "codex-default-profile",
    ])
    #expect(sourceSessions.map(\.id.rawValue) == [
        "codex-viewer-profile",
        "codex-default-profile",
    ])
    #expect(profileSessions.map(\.id.rawValue) == ["codex-viewer-profile"])
    #expect(selectedSessions.map(\.id.rawValue) == [
        "other-viewer-profile",
        "codex-default-profile",
    ])
}

@Test("transcript loading use case returns transcript previews through an injected fake port")
func transcriptLoadingUseCaseUsesFakePort() throws {
    let sessionID = SessionID(rawValue: "codex-1")
    let preview = TranscriptPreview(
        sessionID: sessionID,
        title: "Implement app shell",
        segments: [
            TranscriptSegment(
                id: "segment-1",
                role: .user,
                text: "Build the placeholder shell.",
                timestampDescription: "2026-06-02T20:00:00Z"
            ),
            TranscriptSegment(
                id: "segment-2",
                role: .assistant,
                text: "Implemented with Clean Architecture boundaries.",
                timestampDescription: "2026-06-02T20:01:00Z"
            ),
        ],
        isTruncated: false
    )
    let useCase = LoadTranscriptPreviewUseCase(
        transcriptLoading: FakeTranscriptLoadingPort(previews: [preview])
    )

    let loadedPreview = try useCase.loadPreview(sessionID: sessionID)

    #expect(loadedPreview == preview)
}

private func scopedCatalogSession(
    id: String,
    sourceID: SessionSourceID,
    sourceDisplayName: String,
    profileName: String?,
    lastActivity: Int64
) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: sourceDisplayName,
            profileName: profileName
        ),
        title: "Session \(id)",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: lastActivity),
        fileSize: CatalogFileSize(byteCount: 128),
        metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: profileName),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
