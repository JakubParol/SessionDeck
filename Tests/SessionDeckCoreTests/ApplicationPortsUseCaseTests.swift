import Testing
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
