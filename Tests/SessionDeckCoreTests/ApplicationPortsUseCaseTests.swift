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
        title: "Implement app shell",
        projectDisplayName: "SessionDeck",
        lastActivityDescription: "2026-06-02T20:00:00Z",
        previewText: "Created a placeholder shell."
    )
    let hermesSession = SessionSummary(
        id: SessionID(rawValue: "hermes-1"),
        sourceID: hermesSourceID,
        title: "Review handoff",
        projectDisplayName: "SessionDeck",
        lastActivityDescription: "2026-06-02T21:00:00Z",
        previewText: "Reviewed the delivery slice."
    )
    let useCase = ListSessionsUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [codexSession, hermesSession])
    )

    let sessions = try useCase.listSessions(sourceID: codexSourceID)

    #expect(sessions == [codexSession])
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
