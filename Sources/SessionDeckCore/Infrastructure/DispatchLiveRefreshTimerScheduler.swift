import Foundation

public final class DispatchLiveRefreshTimerScheduler: LiveRefreshTimerScheduling, @unchecked Sendable {
    private let queue: DispatchQueue

    public init(queue: DispatchQueue = DispatchQueue(label: "SessionDeck.live-refresh-timer")) {
        self.queue = queue
    }

    public func schedule(after interval: TimeInterval, _ operation: @escaping () -> Void) -> any LiveRefreshScheduledTask {
        let workItem = DispatchWorkItem(block: operation)
        queue.asyncAfter(deadline: .now() + interval, execute: workItem)
        return DispatchLiveRefreshScheduledTask(workItem: workItem)
    }
}

private final class DispatchLiveRefreshScheduledTask: LiveRefreshScheduledTask {
    private let workItem: DispatchWorkItem

    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    func cancel() {
        workItem.cancel()
    }
}
