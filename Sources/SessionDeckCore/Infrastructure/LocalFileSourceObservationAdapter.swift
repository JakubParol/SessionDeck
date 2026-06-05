import Darwin
import Foundation

public final class LocalFileSourceObservationAdapter: LiveSourceChangeObservationPort, @unchecked Sendable {
    private let fileManager: FileManager
    private let queue: DispatchQueue

    public init(
        fileManager: FileManager = .default,
        queue: DispatchQueue = DispatchQueue(label: "SessionDeck.local-file-source-observation")
    ) {
        self.fileManager = fileManager
        self.queue = queue
    }

    public func observe(
        targets: [LiveSourceWatchTarget],
        eventHandler: @escaping (LiveSourceObservationEvent) -> Void
    ) -> any LiveSourceObservation {
        let observation = LocalFileSourceObservation()

        for target in targets {
            observe(target: target, observation: observation, eventHandler: eventHandler)
        }

        return observation
    }

    private func observe(
        target: LiveSourceWatchTarget,
        observation: LocalFileSourceObservation,
        eventHandler: @escaping (LiveSourceObservationEvent) -> Void
    ) {
        let url = URL(fileURLWithPath: target.path).standardizedFileURL
        let path = url.path
        guard fileManager.fileExists(atPath: path) else {
            eventHandler(.degraded(LiveSourceWatcherDegradedState(
                sourceID: target.sourceID,
                path: path,
                reason: .missingPath
            )))
            return
        }
        guard fileManager.isReadableFile(atPath: path) else {
            eventHandler(.degraded(LiveSourceWatcherDegradedState(
                sourceID: target.sourceID,
                path: path,
                reason: .permissionDenied
            )))
            return
        }

        let fileDescriptor = Darwin.open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            eventHandler(.degraded(LiveSourceWatcherDegradedState(
                sourceID: target.sourceID,
                path: path,
                reason: errno == EACCES ? .permissionDenied : .unavailable
            )))
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak source] in
            guard let source else {
                return
            }
            eventHandler(.change(LiveSourceChangeEvent(
                sourceID: target.sourceID,
                affectedPath: path,
                sessionID: target.sessionID,
                kind: Self.changeKind(from: source.data)
            )))
        }
        source.setCancelHandler {
            Darwin.close(fileDescriptor)
        }

        observation.append(source)
        source.resume()
    }

    private static func changeKind(from event: DispatchSource.FileSystemEvent) -> LiveSourceChangeKind {
        if event.contains(.delete) {
            return .deleted
        }
        if event.contains(.rename) {
            return .moved
        }
        if event.contains(.write) || event.contains(.extend) || event.contains(.attrib) {
            return .modified
        }

        return .unknown
    }
}

private final class LocalFileSourceObservation: LiveSourceObservation, @unchecked Sendable {
    private let lock = NSLock()
    private var sources: [DispatchSourceFileSystemObject] = []
    private var isCancelled = false

    func append(_ source: DispatchSourceFileSystemObject) {
        lock.withLock {
            guard isCancelled == false else {
                source.cancel()
                return
            }
            sources.append(source)
        }
    }

    func cancel() {
        let sourcesToCancel = lock.withLock {
            guard isCancelled == false else {
                return [DispatchSourceFileSystemObject]()
            }
            isCancelled = true
            let currentSources = sources
            sources.removeAll()
            return currentSources
        }

        for source in sourcesToCancel {
            source.cancel()
        }
    }

    deinit {
        cancel()
    }
}
