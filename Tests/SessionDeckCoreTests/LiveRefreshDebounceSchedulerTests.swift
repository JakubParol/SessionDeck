import Foundation
import Testing
@testable import SessionDeckCore

@Test("debounce scheduler coalesces same-session bursts into one refresh request")
func debounceSchedulerCoalescesSameSessionBursts() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let sessionID = SessionID(rawValue: "session-123")
    let timer = ManualLiveRefreshTimerScheduler()
    var emittedRequests: [LiveRefreshRequest] = []
    let scheduler = DebouncedLiveRefreshScheduler(
        debounceInterval: 0.25,
        timerScheduler: timer
    ) { request in
        emittedRequests.append(request)
    }
    let event = LiveSourceChangeEvent(
        sourceID: sourceID,
        affectedPath: "/tmp/session-123.jsonl",
        sessionID: sessionID,
        kind: .modified
    )

    scheduler.record(event)
    scheduler.record(event)
    scheduler.record(event)

    #expect(emittedRequests.isEmpty)
    #expect(timer.pendingTaskCount == 1)

    timer.fireAll()

    #expect(emittedRequests == [
        LiveRefreshRequest(scope: .session(sessionID, sourceID: sourceID), trigger: .sourceChange, eventCount: 3)
    ])
}

@Test("debounce scheduler preserves distinct refresh identities")
func debounceSchedulerPreservesDistinctIdentities() {
    let firstSourceID = SessionSourceID(rawValue: "codex-primary")
    let secondSourceID = SessionSourceID(rawValue: "codex-secondary")
    let timer = ManualLiveRefreshTimerScheduler()
    var emittedRequests: [LiveRefreshRequest] = []
    let scheduler = DebouncedLiveRefreshScheduler(
        debounceInterval: 0.25,
        timerScheduler: timer
    ) { request in
        emittedRequests.append(request)
    }

    scheduler.record(
        LiveSourceChangeEvent(
            sourceID: firstSourceID,
            affectedPath: "/tmp/primary.jsonl",
            kind: .modified
        )
    )
    scheduler.record(
        LiveSourceChangeEvent(
            sourceID: secondSourceID,
            affectedPath: "/tmp/secondary.jsonl",
            kind: .modified
        )
    )

    #expect(timer.pendingTaskCount == 2)

    timer.fireAll()

    #expect(emittedRequests == [
        LiveRefreshRequest(scope: .path("/tmp/primary.jsonl", sourceID: firstSourceID), trigger: .sourceChange, eventCount: 1),
        LiveRefreshRequest(scope: .path("/tmp/secondary.jsonl", sourceID: secondSourceID), trigger: .sourceChange, eventCount: 1),
    ])
}

@Test("debounce scheduler cancellation suppresses pending refresh requests")
func debounceSchedulerCancellationSuppressesPendingRequests() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let timer = ManualLiveRefreshTimerScheduler()
    var emittedRequests: [LiveRefreshRequest] = []
    let scheduler = DebouncedLiveRefreshScheduler(
        debounceInterval: 0.25,
        timerScheduler: timer
    ) { request in
        emittedRequests.append(request)
    }

    scheduler.record(
        LiveSourceChangeEvent(
            sourceID: sourceID,
            affectedPath: "/tmp/session-123.jsonl",
            kind: .modified
        )
    )
    scheduler.cancel()
    timer.fireAll()

    #expect(emittedRequests.isEmpty)
    #expect(timer.pendingTaskCount == 0)
}

private final class ManualLiveRefreshTimerScheduler: LiveRefreshTimerScheduling {
    private var tasks: [ManualLiveRefreshScheduledTask] = []

    var pendingTaskCount: Int {
        tasks.filter { $0.isCancelled == false }.count
    }

    func schedule(after interval: TimeInterval, _ operation: @escaping () -> Void) -> any LiveRefreshScheduledTask {
        let task = ManualLiveRefreshScheduledTask(interval: interval, operation: operation)
        tasks.append(task)
        return task
    }

    func fireAll() {
        let tasksToFire = tasks
        tasks.removeAll()

        for task in tasksToFire where task.isCancelled == false {
            task.fire()
        }
    }
}

private final class ManualLiveRefreshScheduledTask: LiveRefreshScheduledTask {
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
