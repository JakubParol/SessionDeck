import Foundation
import Testing
@testable import SessionDeckCore

@Test("local file source observer emits change event for appended temp transcript")
func localFileSourceObserverEmitsChangeEventForAppend() throws {
    let fixtureRoot = try makeLiveMonitoringFixtureRoot(name: "append-event")
    defer {
        try? fixtureRoot.cleanup()
    }

    let transcriptURL = fixtureRoot.url.appending(path: "session-123.jsonl")
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let sessionID = SessionID(rawValue: "session-123")
    let recorder = LiveObservationRecorder()
    let adapter = LocalFileSourceObservationAdapter()

    let observation = adapter.observe(
        targets: [
            LiveSourceWatchTarget(sourceID: sourceID, path: transcriptURL.path, sessionID: sessionID),
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
    #expect(event.sourceID == sourceID)
    #expect(event.sessionID == sessionID)
    #expect(event.affectedPath == transcriptURL.standardizedFileURL.path)
    #expect(event.kind == .modified)
}

@Test("local file source observer reports missing paths as degraded states")
func localFileSourceObserverReportsMissingPaths() throws {
    let fixtureRoot = try makeLiveMonitoringFixtureRoot(name: "missing-path")
    defer {
        try? fixtureRoot.cleanup()
    }

    let missingURL = fixtureRoot.url.appending(path: "missing.jsonl")
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let recorder = LiveObservationRecorder()
    let adapter = LocalFileSourceObservationAdapter()

    let observation = adapter.observe(
        targets: [
            LiveSourceWatchTarget(sourceID: sourceID, path: missingURL.path),
        ],
        eventHandler: recorder.record
    )
    defer {
        observation.cancel()
    }

    let degradedState = try #require(recorder.waitForDegradedState())
    #expect(degradedState.sourceID == sourceID)
    #expect(degradedState.path == missingURL.standardizedFileURL.path)
    #expect(degradedState.reason == .missingPath)
}

@Test("local file source observer reports deleted watched files as degraded states")
func localFileSourceObserverReportsDeletedWatchedFiles() throws {
    let fixtureRoot = try makeLiveMonitoringFixtureRoot(name: "deleted-path")
    defer {
        try? fixtureRoot.cleanup()
    }

    let transcriptURL = fixtureRoot.url.appending(path: "session-123.jsonl")
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let recorder = LiveObservationRecorder()
    let adapter = LocalFileSourceObservationAdapter()

    let observation = adapter.observe(
        targets: [
            LiveSourceWatchTarget(
                sourceID: sourceID,
                path: transcriptURL.path,
                sessionID: SessionID(rawValue: "session-123")
            ),
        ],
        eventHandler: recorder.record
    )
    defer {
        observation.cancel()
    }

    try FileManager.default.removeItem(at: transcriptURL)

    let degradedState = try #require(recorder.waitForDegradedState())
    #expect(degradedState.sourceID == sourceID)
    #expect(degradedState.path == transcriptURL.standardizedFileURL.path)
    #expect(degradedState.reason == .deletedPath)
}

@Test("local file source observer does not mutate watched fixture tree")
func localFileSourceObserverDoesNotMutateWatchedTree() throws {
    let fixtureRoot = try makeLiveMonitoringFixtureRoot(name: "read-only-safety")
    defer {
        try? fixtureRoot.cleanup()
    }

    let transcriptURL = fixtureRoot.url.appending(path: "session-123.jsonl")
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)
    let before = try relativeLiveMonitoringSnapshot(at: fixtureRoot.url)
    let adapter = LocalFileSourceObservationAdapter()

    let observation = adapter.observe(
        targets: [
            LiveSourceWatchTarget(
                sourceID: SessionSourceID(rawValue: "codex-default"),
                path: transcriptURL.path,
                sessionID: SessionID(rawValue: "session-123")
            ),
        ],
        eventHandler: { _ in }
    )
    observation.cancel()

    let after = try relativeLiveMonitoringSnapshot(at: fixtureRoot.url)
    #expect(after == before)
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
        waitForEvent { event in
            if case let .change(changeEvent) = event {
                return changeEvent
            }
            return nil
        }
    }

    func waitForDegradedState() -> LiveSourceWatcherDegradedState? {
        waitForEvent { event in
            if case let .degraded(degradedState) = event {
                return degradedState
            }
            return nil
        }
    }

    private func waitForEvent<T>(_ match: (LiveSourceObservationEvent) -> T?) -> T? {
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            if let event = lock.withLock({ events.compactMap(match).first }) {
                return event
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        return nil
    }
}

private func makeLiveMonitoringFixtureRoot(name: String) throws -> FixtureTempRoot {
    try FixtureTempRoot(
        parentDirectory: FileManager.default.temporaryDirectory,
        name: "SessionDeckLiveMonitoring-\(name)-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
}

private func relativeLiveMonitoringSnapshot(at root: URL) throws -> [String] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    let rootPath = root.standardizedFileURL.path
    return try enumerator.compactMap { item in
        guard let url = item as? URL else {
            return nil
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            return nil
        }
        return String(url.standardizedFileURL.path.dropFirst(rootPath.count + 1))
    }
    .sorted()
}
