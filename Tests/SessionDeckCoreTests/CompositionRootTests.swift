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

    do {
        _ = try composition.loadTranscriptSegments.loadTranscript(sessionID: missingSessionID)
        Issue.record("Placeholder transcript decoding must not synthesize or read transcript content")
    } catch let error as PlaceholderTranscriptDecodingError {
        #expect(error == .transcriptUnavailable(missingSessionID))
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
    try """
    {"timestamp":"2026-06-03T06:00:00Z","type":"session_meta","payload":{"id":"composition-session","title":"Composition Catalog","cwd":"/tmp/SessionDeck","project":"SessionDeck","source":"codex-cli"}}
    {"timestamp":"2026-06-03T06:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Open the selected fixture."}]}}
    {"timestamp":"2026-06-03T06:00:02Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"The selected fixture is open."}]}}
    """
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

    let selectedTranscript = try composition.loadSelectedTranscript.loadTranscript(for: compositionSession)
    #expect(selectedTranscript.title == "Composition Catalog")
    #expect(selectedTranscript.segments.map(\.text) == [
        "Open the selected fixture.",
        "The selected fixture is open.",
    ])
    #expect(selectedTranscript.diagnostics.isEmpty)

    let report = try composition.discoverSessionSources.discoveryReport()
    #expect(report.candidateDiagnostics.map(\.candidate.relativePath) == [
        "2026/06/03/rollout-2026-06-03T06-01-00-unreadable.jsonl",
    ])
}

@Test("composition root exposes local file observation through application boundary")
func compositionRootExposesLocalFileObservationThroughApplicationBoundary() throws {
    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-composition-live-monitoring-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    let transcriptURL = fixtureRoot.url.appending(path: "session-123.jsonl")
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)
    let recorder = LiveObservationRecorder()
    let composition = SessionDeckCompositionRoot.makeApplicationComposition(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: fixtureRoot.url)
    )

    let observation = composition.sourceChangeObservation.observe(
        targets: [
            LiveSourceWatchTarget(
                sourceID: DefaultCodexSourceDiscoveryAdapter.sourceID,
                path: transcriptURL.path,
                sessionID: SessionID(rawValue: "session-123")
            ),
        ],
        eventHandler: recorder.record
    )
    defer {
        observation.cancel()
    }

    let handle = try FileHandle(forWritingTo: transcriptURL)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\n{\"type\":\"response_item\"}".utf8))
    try handle.close()

    let event = try #require(recorder.waitForChangeEvent())
    #expect(event.sourceID == DefaultCodexSourceDiscoveryAdapter.sourceID)
    #expect(event.sessionID == SessionID(rawValue: "session-123"))
    #expect(event.kind == .modified)
}

@Test("composition root exposes live refresh pipeline through application composition")
func compositionRootExposesLiveRefreshPipelineThroughApplicationComposition() throws {
    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-composition-live-refresh-pipeline-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    let sessionsRoot = fixtureRoot.url.appending(path: "configured/.codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessionsRoot, withIntermediateDirectories: true)
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

    composition.liveRefreshPipeline.start(
        LiveRefreshPipelineConfiguration(
            watchTargets: [
                LiveSourceWatchTarget(sourceID: SessionSourceID(rawValue: "codex-configured"), path: sessionsRoot.path),
            ],
            knownCandidates: [],
            reconciliationSourceID: SessionSourceID(rawValue: "codex-configured")
        )
    )
    defer {
        composition.liveRefreshPipeline.stop()
    }

    #expect(composition.liveRefreshPipeline.monitoringStates.contains(
        .watching(sourceID: SessionSourceID(rawValue: "codex-configured"))
    ))
    #expect(composition.appShellUseCase.makeViewModel().monitoringHealthSummary.rows.contains(
        AppShellMonitoringHealthRow(
            id: "watcher.codex-configured",
            title: "Watcher healthy",
            detail: "Source updates are being watched for codex-configured.",
            severity: .healthy,
            diagnosticCode: nil,
            sourceID: SessionSourceID(rawValue: "codex-configured")
        )
    ))
}

@Test("composition root dispatches live refresh work off the caller path")
func compositionRootDispatchesLiveRefreshWorkOffCallerPath() throws {
    let compositionRoot = repositoryRoot()
        .appending(path: "Sources/SessionDeckCore/CompositionRoot/SessionDeckCompositionRoot.swift")
    let contents = try String(contentsOf: compositionRoot, encoding: .utf8)

    #expect(contents.contains(#"DispatchQueue(label: "SessionDeck.live-refresh-work")"#))
    #expect(contents.contains("refreshQueue.async"))
}

private final class LiveObservationRecorder {
    private let lock = NSLock()
    private var events: [LiveSourceObservationEvent] = []

    func record(_ event: LiveSourceObservationEvent) {
        lock.withLock {
            events.append(event)
        }
    }

    func waitForChangeEvent() -> LiveSourceChangeEvent? {
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            if let event = lock.withLock({ events.compactMap(changeEvent).first }) {
                return event
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        return nil
    }

    private func changeEvent(from event: LiveSourceObservationEvent) -> LiveSourceChangeEvent? {
        if case let .change(changeEvent) = event {
            return changeEvent
        }

        return nil
    }
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
