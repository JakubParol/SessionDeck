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

private final class PipelineObservationPortFake: LiveSourceChangeObservationPort, @unchecked Sendable {
    private var eventHandler: ((LiveSourceObservationEvent) -> Void)?
    private(set) var observedTargets: [LiveSourceWatchTarget] = []
    private(set) var observation: PipelineObservationFake?

    func observe(
        targets: [LiveSourceWatchTarget],
        eventHandler: @escaping (LiveSourceObservationEvent) -> Void
    ) -> any LiveSourceObservation {
        observedTargets = targets
        self.eventHandler = eventHandler
        let observation = PipelineObservationFake()
        self.observation = observation
        return observation
    }

    func emit(_ event: LiveSourceObservationEvent) {
        eventHandler?(event)
    }
}

private final class PipelineObservationFake: LiveSourceObservation, @unchecked Sendable {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

private final class PipelineManualTimerScheduler: LiveRefreshTimerScheduling {
    private var tasks: [PipelineManualScheduledTask] = []

    var pendingTaskCount: Int {
        tasks.filter { $0.isCancelled == false }.count
    }

    func schedule(after interval: TimeInterval, _ operation: @escaping () -> Void) -> any LiveRefreshScheduledTask {
        let task = PipelineManualScheduledTask(interval: interval, operation: operation)
        tasks.append(task)
        return task
    }

    func fireTasks(matching interval: TimeInterval) {
        let tasksToFire = tasks.filter { $0.interval == interval }
        tasks.removeAll { $0.interval == interval }

        for task in tasksToFire where task.isCancelled == false {
            task.fire()
        }
    }

    func fireAll() {
        let tasksToFire = tasks
        tasks.removeAll()

        for task in tasksToFire where task.isCancelled == false {
            task.fire()
        }
    }
}

private final class PipelineManualScheduledTask: LiveRefreshScheduledTask {
    let interval: TimeInterval
    private let operation: () -> Void
    private(set) var isCancelled = false

    init(interval: TimeInterval, operation: @escaping () -> Void) {
        self.interval = interval
        self.operation = operation
    }

    func cancel() {
        isCancelled = true
    }

    func fire() {
        operation()
    }
}

private struct PipelineCandidateEnumerationFake: CandidateSessionFileEnumerationPort {
    let candidates: [CandidateSessionFile]

    init(candidates: [CandidateSessionFile] = []) {
        self.candidates = candidates
    }

    func enumerateCandidateFiles(sourceID: SessionSourceID?) throws -> [CandidateSessionFile] {
        candidates.filter { candidate in
            sourceID == nil || candidate.sourceID == sourceID
        }
    }

    static func candidate(
        sourceID: SessionSourceID,
        relativePath: String,
        absolutePath: String,
        byteSize: Int64
    ) -> CandidateSessionFile {
        CandidateSessionFile(
            sourceID: sourceID,
            relativePath: relativePath,
            absolutePath: absolutePath,
            byteSize: byteSize,
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
            confidence: .high,
            reason: "test",
            diagnostic: nil
        )
    }
}
