import Foundation
import Testing
@testable import SessionDeckCore

@Test("pipeline start observes configured targets and emits startup refresh")
func pipelineStartObservesConfiguredTargetsAndEmitsStartupRefresh() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let target = LiveSourceWatchTarget(sourceID: sourceID, path: "/tmp/session.jsonl")
    let observationPort = PipelineObservationPortFake()
    let timer = PipelineManualTimerScheduler()
    var refreshRequests: [LiveRefreshRequest] = []
    let pipeline = LiveRefreshPipelineCoordinator(
        sourceChangeObservation: observationPort,
        reconciliation: ReconcileSessionSourcesUseCase(candidateEnumeration: PipelineCandidateEnumerationFake()),
        timerScheduler: timer,
        debounceInterval: 0.25,
        reconciliationInterval: 5
    ) { request in
        refreshRequests.append(request)
    }

    pipeline.start(
        LiveRefreshPipelineConfiguration(
            watchTargets: [target],
            knownCandidates: [],
            reconciliationSourceID: sourceID
        )
    )

    #expect(observationPort.observedTargets == [target])
    #expect(pipeline.monitoringStates.contains(.watching(sourceID: sourceID)))
    #expect(refreshRequests == [
        LiveRefreshRequest(scope: .allSources, trigger: .appStartup, eventCount: 1),
    ])
    #expect(timer.pendingTaskCount == 1)
}

@Test("pipeline debounces watcher append events into bounded refresh requests")
func pipelineDebouncesWatcherAppendEventsIntoBoundedRefreshRequests() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let sessionID = SessionID(rawValue: "session-123")
    let target = LiveSourceWatchTarget(sourceID: sourceID, path: "/tmp/session.jsonl", sessionID: sessionID)
    let observationPort = PipelineObservationPortFake()
    let timer = PipelineManualTimerScheduler()
    var refreshRequests: [LiveRefreshRequest] = []
    let pipeline = LiveRefreshPipelineCoordinator(
        sourceChangeObservation: observationPort,
        reconciliation: ReconcileSessionSourcesUseCase(candidateEnumeration: PipelineCandidateEnumerationFake()),
        timerScheduler: timer,
        debounceInterval: 0.25,
        reconciliationInterval: 5
    ) { request in
        refreshRequests.append(request)
    }

    pipeline.start(
        LiveRefreshPipelineConfiguration(
            watchTargets: [target],
            knownCandidates: [],
            reconciliationSourceID: sourceID
        )
    )
    refreshRequests.removeAll()
    observationPort.emit(.change(LiveSourceChangeEvent(
        sourceID: sourceID,
        affectedPath: target.path,
        sessionID: sessionID,
        kind: .modified
    )))
    observationPort.emit(.change(LiveSourceChangeEvent(
        sourceID: sourceID,
        affectedPath: target.path,
        sessionID: sessionID,
        kind: .modified
    )))

    #expect(refreshRequests.isEmpty)
    #expect(timer.pendingTaskCount == 2)

    timer.fireTasks(matching: 0.25)

    #expect(refreshRequests == [
        LiveRefreshRequest(scope: .session(sessionID, sourceID: sourceID), trigger: .debouncedSourceChange, eventCount: 2),
    ])
}

@Test("pipeline reconciliation recovers missed source changes")
func pipelineReconciliationRecoversMissedSourceChanges() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let current = PipelineCandidateEnumerationFake.candidate(
        sourceID: sourceID,
        relativePath: "2026/06/05/session.jsonl",
        absolutePath: "/tmp/session.jsonl",
        byteSize: 42
    )
    let timer = PipelineManualTimerScheduler()
    var refreshRequests: [LiveRefreshRequest] = []
    let pipeline = LiveRefreshPipelineCoordinator(
        sourceChangeObservation: PipelineObservationPortFake(),
        reconciliation: ReconcileSessionSourcesUseCase(
            candidateEnumeration: PipelineCandidateEnumerationFake(candidates: [current])
        ),
        timerScheduler: timer,
        debounceInterval: 0.25,
        reconciliationInterval: 5
    ) { request in
        refreshRequests.append(request)
    }

    pipeline.start(
        LiveRefreshPipelineConfiguration(
            watchTargets: [],
            knownCandidates: [],
            reconciliationSourceID: sourceID
        )
    )
    refreshRequests.removeAll()
    timer.fireTasks(matching: 5)

    #expect(pipeline.monitoringStates.contains(.reconciling(sourceID: sourceID, trigger: .reconciliation)))
    #expect(pipeline.monitoringStates.contains(.stale(sourceID: sourceID, reason: .missedChangeRecovered)))
    #expect(refreshRequests == [
        LiveRefreshRequest(scope: .source(sourceID), trigger: .reconciliation, eventCount: 1),
    ])
}

@Test("pipeline stop cancels observation and pending scheduled work")
func pipelineStopCancelsObservationAndPendingScheduledWork() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let target = LiveSourceWatchTarget(sourceID: sourceID, path: "/tmp/session.jsonl")
    let observationPort = PipelineObservationPortFake()
    let timer = PipelineManualTimerScheduler()
    var refreshRequests: [LiveRefreshRequest] = []
    let pipeline = LiveRefreshPipelineCoordinator(
        sourceChangeObservation: observationPort,
        reconciliation: ReconcileSessionSourcesUseCase(candidateEnumeration: PipelineCandidateEnumerationFake()),
        timerScheduler: timer,
        debounceInterval: 0.25,
        reconciliationInterval: 5
    ) { request in
        refreshRequests.append(request)
    }

    pipeline.start(
        LiveRefreshPipelineConfiguration(
            watchTargets: [target],
            knownCandidates: [],
            reconciliationSourceID: sourceID
        )
    )
    refreshRequests.removeAll()
    observationPort.emit(.change(LiveSourceChangeEvent(sourceID: sourceID, affectedPath: target.path, kind: .modified)))
    pipeline.stop()
    timer.fireAll()

    #expect(observationPort.observation?.isCancelled == true)
    #expect(refreshRequests.isEmpty)
    #expect(pipeline.monitoringStates.last == .stopped)
}

@Test("pipeline observes appended temp fixture transcript through local file watcher")
func pipelineObservesAppendedTempFixtureTranscriptThroughLocalFileWatcher() throws {
    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: FileManager.default.temporaryDirectory,
        name: "SessionDeckLiveRefreshPipeline-append-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    let transcriptURL = fixtureRoot.url.appending(path: "session-123.jsonl")
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let sessionID = SessionID(rawValue: "session-123")
    let timer = PipelineManualTimerScheduler()
    var refreshRequests: [LiveRefreshRequest] = []
    let pipeline = LiveRefreshPipelineCoordinator(
        sourceChangeObservation: LocalFileSourceObservationAdapter(),
        reconciliation: ReconcileSessionSourcesUseCase(candidateEnumeration: PipelineCandidateEnumerationFake()),
        timerScheduler: timer,
        debounceInterval: 0.25,
        reconciliationInterval: 5
    ) { request in
        refreshRequests.append(request)
    }

    pipeline.start(
        LiveRefreshPipelineConfiguration(
            watchTargets: [
                LiveSourceWatchTarget(sourceID: sourceID, path: transcriptURL.path, sessionID: sessionID),
            ],
            knownCandidates: [],
            reconciliationSourceID: sourceID
        )
    )
    refreshRequests.removeAll()

    let handle = try FileHandle(forWritingTo: transcriptURL)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\n{\"type\":\"response_item\"}".utf8))
    try handle.close()

    #expect(waitUntil { timer.pendingTaskCount == 2 })
    timer.fireTasks(matching: 0.25)
    pipeline.stop()

    #expect(refreshRequests == [
        LiveRefreshRequest(scope: .session(sessionID, sourceID: sourceID), trigger: .debouncedSourceChange, eventCount: 1),
    ])
    #expect(pipeline.monitoringStates.contains(.refreshRunning(refreshRequests[0])))
}
