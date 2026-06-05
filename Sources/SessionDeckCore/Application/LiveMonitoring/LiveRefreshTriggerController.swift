import Foundation

public final class LiveRefreshTriggerController {
    private let reconciliationInterval: TimeInterval
    private let timerScheduler: any LiveRefreshTimerScheduling
    private let emit: (LiveRefreshRequest) -> Void
    private var reconciliationTask: (any LiveRefreshScheduledTask)?

    public init(
        reconciliationInterval: TimeInterval,
        timerScheduler: any LiveRefreshTimerScheduling,
        emit: @escaping (LiveRefreshRequest) -> Void
    ) {
        self.reconciliationInterval = reconciliationInterval
        self.timerScheduler = timerScheduler
        self.emit = emit
    }

    public func requestManualRefresh(scope: LiveRefreshScope) {
        emit(LiveRefreshRequest(scope: scope, trigger: .manualRefresh, eventCount: 1))
    }

    public func requestStartupRefresh(scope: LiveRefreshScope) {
        emit(LiveRefreshRequest(scope: scope, trigger: .appStartup, eventCount: 1))
    }

    public func scheduleReconciliation(scope: LiveRefreshScope) {
        reconciliationTask?.cancel()
        reconciliationTask = timerScheduler.schedule(after: reconciliationInterval) { [weak self] in
            self?.emitReconciliation(scope: scope)
        }
    }

    public func cancel() {
        reconciliationTask?.cancel()
        reconciliationTask = nil
    }

    private func emitReconciliation(scope: LiveRefreshScope) {
        reconciliationTask = nil
        emit(LiveRefreshRequest(scope: scope, trigger: .reconciliation, eventCount: 1))
    }
}
