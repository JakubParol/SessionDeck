import Foundation
import Testing
@testable import SessionDeckCore

@Test("composition root wires default source discovery without presentation IO")
func compositionRootWiresDefaultSourceDiscoveryWithoutPresentationIO() throws {
    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-composition-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    let composition = SessionDeckCompositionRoot.makeApplicationComposition(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: fixtureRoot.url)
    )

    #expect(composition.appShellViewModel.title == "SessionDeck")
    #expect(composition.appShellViewModel.configuredSourceCount == 1)
    #expect(composition.appShellViewModel.safetyPolicy.readsRealAgentStores == true)
    #expect(composition.appShellViewModel.safetyPolicy.permitsNetworkCalls == false)
    #expect(composition.appShellViewModel.safetyPolicy.permitsCommandExecution == false)
    #expect(composition.appShellViewModel.safetyPolicy.permitsSessionMutation == false)

    let sources = try composition.discoverSessionSources.discoverSources()
    #expect(sources.map(\.id) == [DefaultCodexSourceDiscoveryAdapter.sourceID])
    #expect(sources.first?.availability == .missing)

    let sessions = try composition.listSessions.listSessions()
    #expect(sessions.isEmpty)

    let snapshot = try composition.refreshCatalogSnapshot.refreshSnapshot()
    #expect(snapshot.sessions.isEmpty)
    #expect(snapshot.refreshErrors.isEmpty)

    let missingSessionID = SessionID(rawValue: "placeholder-missing")
    do {
        _ = try composition.loadTranscriptPreview.loadPreview(sessionID: missingSessionID)
        Issue.record("Placeholder transcript loading must not synthesize or read transcript content")
    } catch let error as PlaceholderTranscriptLoadingError {
        #expect(error == .previewUnavailable(missingSessionID))
    }
}

@Test("composition root passes configured source definitions through one boundary")
func compositionRootPassesConfiguredSourceDefinitionsThroughOneBoundary() throws {
    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-composition-configured-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    let sessionsRoot = fixtureRoot.url
        .appending(path: "configured/.codex/sessions", directoryHint: .isDirectory)
    let transcriptURL = sessionsRoot
        .appending(path: "2026/06/03", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-03T06-00-00-composition.jsonl")
    let unreadableTranscriptURL = sessionsRoot
        .appending(path: "2026/06/03", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-03T06-01-00-unreadable.jsonl")
    try FileManager.default.createDirectory(
        at: transcriptURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"timestamp":"2026-06-03T06:00:00Z","type":"session_meta","payload":{"id":"composition-session","title":"Composition Catalog","cwd":"/tmp/SessionDeck","project":"SessionDeck","source":"codex-cli"}}"#
        .write(to: transcriptURL, atomically: true, encoding: .utf8)
    try #"{"type":"session_meta"}"#.write(to: unreadableTranscriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadableTranscriptURL.path)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: unreadableTranscriptURL.path)
    }

    let composition = SessionDeckCompositionRoot.makeApplicationComposition(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: fixtureRoot.url),
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-configured"),
                displayName: "Codex configured",
                kind: .codex,
                rootPath: sessionsRoot.path,
                isEnabled: true
            ),
        ]
    )

    let sources = try composition.discoverSessionSources.discoverSources()

    #expect(sources.map(\.id.rawValue) == ["codex-configured"])
    #expect(sources.first?.displayName == "Codex configured")
    #expect(sources.first?.availability == .available)
    #expect(sources.first?.locationDescription == sessionsRoot.standardizedFileURL.path)

    let candidates = try composition.enumerateCandidateSessionFiles.enumerateCandidateFiles()
    #expect(candidates.map(\.sourceID.rawValue) == ["codex-configured", "codex-configured"])
    #expect(candidates.map(\.relativePath) == [
        "2026/06/03/rollout-2026-06-03T06-00-00-composition.jsonl",
        "2026/06/03/rollout-2026-06-03T06-01-00-unreadable.jsonl",
    ])

    let sessions = try composition.listSessions.listSessions()
    let compositionSession = try #require(sessions.first { $0.id.rawValue == "composition-session" })
    #expect(sessions.count == 2)
    #expect(compositionSession.displayTitle == "Composition Catalog")
    #expect(compositionSession.sourceLabel.displayName == "Codex configured")

    let snapshot = try composition.refreshCatalogSnapshot.refreshSnapshot()
    #expect(snapshot.sources.map(\.id.rawValue) == ["codex-configured"])
    #expect(snapshot.sessions.map(\.id.rawValue).contains("composition-session"))
    #expect(snapshot.counts.totalEntries == 2)

    let report = try composition.discoverSessionSources.discoveryReport()
    #expect(report.candidateDiagnostics.map(\.candidate.relativePath) == [
        "2026/06/03/rollout-2026-06-03T06-01-00-unreadable.jsonl",
    ])
}
