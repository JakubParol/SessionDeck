import Foundation
import Testing
@testable import SessionDeckCore

@Test("trigger controller emits manual and startup refresh requests immediately")
func triggerControllerEmitsManualAndStartupRequests() {
    var emittedRequests: [LiveRefreshRequest] = []
    let controller = LiveRefreshTriggerController(
        reconciliationInterval: 5,
        timerScheduler: ManualTriggerTimerScheduler()
    ) { request in
        emittedRequests.append(request)
    }

    controller.requestManualRefresh(scope: .allSources)
    controller.requestStartupRefresh(scope: .source(SessionSourceID(rawValue: "codex-default")))

    #expect(emittedRequests == [
        LiveRefreshRequest(scope: .allSources, trigger: .manualRefresh, eventCount: 1),
        LiveRefreshRequest(
            scope: .source(SessionSourceID(rawValue: "codex-default")),
            trigger: .appStartup,
            eventCount: 1
        ),
    ])
}

@Test("trigger controller schedules reconciliation and cancellation suppresses pending request")
func triggerControllerSchedulesAndCancelsReconciliation() {
    let timer = ManualTriggerTimerScheduler()
    var emittedRequests: [LiveRefreshRequest] = []
    let controller = LiveRefreshTriggerController(
        reconciliationInterval: 5,
        timerScheduler: timer
    ) { request in
        emittedRequests.append(request)
    }

    controller.scheduleReconciliation(scope: .allSources)
    #expect(timer.pendingTaskCount == 1)

    controller.cancel()
    timer.fireAll()

    #expect(emittedRequests.isEmpty)
    #expect(timer.pendingTaskCount == 0)
}

@Test("trigger controller emits scheduled reconciliation refresh request")
func triggerControllerEmitsScheduledReconciliation() {
    let timer = ManualTriggerTimerScheduler()
    var emittedRequests: [LiveRefreshRequest] = []
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let controller = LiveRefreshTriggerController(
        reconciliationInterval: 5,
        timerScheduler: timer
    ) { request in
        emittedRequests.append(request)
    }

    controller.scheduleReconciliation(scope: .source(sourceID))
    timer.fireAll()

    #expect(emittedRequests == [
        LiveRefreshRequest(scope: .source(sourceID), trigger: .reconciliation, eventCount: 1)
    ])
}

private final class ManualTriggerTimerScheduler: LiveRefreshTimerScheduling {
    private var tasks: [ManualTriggerScheduledTask] = []

    var pendingTaskCount: Int {
        tasks.filter { $0.isCancelled == false }.count
    }

    func schedule(after interval: TimeInterval, _ operation: @escaping () -> Void) -> any LiveRefreshScheduledTask {
        let task = ManualTriggerScheduledTask(interval: interval, operation: operation)
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

private final class ManualTriggerScheduledTask: LiveRefreshScheduledTask {
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
