import Foundation

public protocol LiveRefreshScheduledTask: AnyObject {
    func cancel()
}

public protocol LiveRefreshTimerScheduling: AnyObject {
    func schedule(after interval: TimeInterval, _ operation: @escaping () -> Void) -> any LiveRefreshScheduledTask
}

public final class DebouncedLiveRefreshScheduler {
    private struct PendingRefresh {
        let scope: LiveRefreshScope
        var eventCount: Int
        var task: any LiveRefreshScheduledTask
    }

    private let debounceInterval: TimeInterval
    private let timerScheduler: any LiveRefreshTimerScheduling
    private let emit: (LiveRefreshRequest) -> Void
    private let lock = NSLock()
    private var pendingRefreshes: [LiveRefreshIdentity: PendingRefresh] = [:]

    public init(
        debounceInterval: TimeInterval,
        timerScheduler: any LiveRefreshTimerScheduling,
        emit: @escaping (LiveRefreshRequest) -> Void
    ) {
        self.debounceInterval = debounceInterval
        self.timerScheduler = timerScheduler
        self.emit = emit
    }

    public func record(_ event: LiveSourceChangeEvent) {
        let identity = event.identity
        let previousTask = lock.withLock {
            let previousTask = pendingRefreshes[identity]?.task
            let nextCount = (pendingRefreshes[identity]?.eventCount ?? 0) + 1

            let task = timerScheduler.schedule(after: debounceInterval) { [weak self] in
                self?.emitPendingRefresh(for: identity)
            }
            pendingRefreshes[identity] = PendingRefresh(
                scope: identity.refreshScope,
                eventCount: nextCount,
                task: task
            )
            return previousTask
        }
        previousTask?.cancel()
    }

    public func cancel() {
        let tasksToCancel = lock.withLock {
            let tasks = pendingRefreshes.values.map(\.task)
            pendingRefreshes.removeAll()
            return tasks
        }

        for task in tasksToCancel {
            task.cancel()
        }
    }

    private func emitPendingRefresh(for identity: LiveRefreshIdentity) {
        guard let pendingRefresh = lock.withLock({ pendingRefreshes.removeValue(forKey: identity) }) else {
            return
        }

        emit(
            LiveRefreshRequest(
                scope: pendingRefresh.scope,
                trigger: .debouncedSourceChange,
                eventCount: pendingRefresh.eventCount
            )
        )
    }
}

private extension LiveRefreshIdentity {
    var refreshScope: LiveRefreshScope {
        switch self {
        case let .source(sourceID):
            return .source(sourceID)
        case let .session(sessionID, sourceID):
            return .session(sessionID, sourceID: sourceID)
        case let .path(path, sourceID):
            return .path(path, sourceID: sourceID)
        case .unidentified:
            return .allSources
        }
    }
}
