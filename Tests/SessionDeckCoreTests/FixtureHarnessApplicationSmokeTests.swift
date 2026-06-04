import Testing
@testable import SessionDeckCore

@Test("fixture harness drives application use cases without real HOME data")
func fixtureHarnessDrivesApplicationUseCasesWithoutRealHomeData() throws {
    let harness = try FixtureHarnessApplicationSmoke(name: "application")
    defer {
        try? harness.cleanup()
    }

    let codexSource = try harness.codexSource(label: "codex-cli", profile: "default")
    let appSource = try harness.codexSource(label: "codex-app", profile: "viewer")
    let projectSession = try harness.installProjectSession(
        .projectSession,
        source: codexSource,
        sessionID: "00000000-0000-4000-8000-000000005001",
        projectName: "SessionDeck",
        timestamp: "2026-06-03T05:00:01Z"
    )
    let nonProjectChat = try harness.installNonProjectChat(
        .nonProjectChat,
        source: appSource,
        sessionID: "00000000-0000-4000-8000-000000005002",
        timestamp: "2026-06-03T05:00:02Z"
    )
    _ = try harness.installGeneratedLargeProjectSession(
        source: codexSource,
        sessionID: "00000000-0000-4000-8000-000000005003",
        projectName: "LargeFixtureProject",
        options: GeneratedCodexTranscriptOptions(eventCount: 4, toolOutputByteCount: 256),
        timestamp: "2026-06-03T05:00:03Z"
    )

    let composition = try harness.makeApplicationComposition()
    let sources = try composition.discoverSessionSources.discoverSources()
    let codexSessions = try composition.listSessions.listSessions(sourceID: codexSource.id)
    let allSessions = try composition.listSessions.listSessions(sourceID: nil)
    let projectPreview = try composition.loadTranscriptPreview.loadPreview(sessionID: projectSession.id)

    #expect(sources.map(\.id) == [codexSource.id, appSource.id])
    #expect(codexSessions.map(\.id) == [SessionID(rawValue: "00000000-0000-4000-8000-000000005003"), projectSession.id])
    #expect(allSessions.map(\.id).contains(nonProjectChat.id))
    #expect(projectPreview.title == "Synthetic SessionDeck Session")
    #expect(projectPreview.segments.contains { $0.role == .user })
    #expect(projectPreview.segments.contains { $0.role == .tool })
    #expect(projectPreview.isTruncated == true)
    #expect(harness.rootPath.contains("/.codex") == false)
    #expect(harness.rootPath.contains("/.hermes") == false)
}
