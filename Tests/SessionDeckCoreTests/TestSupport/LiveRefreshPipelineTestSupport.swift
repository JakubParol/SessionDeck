import Foundation
@testable import SessionDeckCore

final class PipelineObservationPortFake: LiveSourceChangeObservationPort, @unchecked Sendable {
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

final class PipelineObservationFake: LiveSourceObservation, @unchecked Sendable {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

final class PipelineManualTimerScheduler: LiveRefreshTimerScheduling {
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

struct PipelineCandidateEnumerationFake: CandidateSessionFileEnumerationPort {
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

func waitUntil(_ predicate: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(2)

    while Date() < deadline {
        if predicate() {
            return true
        }
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }

    return false
}

func relativePipelineFixtureSnapshot(at root: URL) throws -> [String] {
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
