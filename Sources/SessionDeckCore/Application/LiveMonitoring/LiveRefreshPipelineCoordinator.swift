import Foundation

public struct LiveRefreshPipelineConfiguration: Equatable, Sendable {
    public let watchTargets: [LiveSourceWatchTarget]
    public let knownCandidates: [CandidateSessionSnapshot]
    public let reconciliationSourceID: SessionSourceID?

    public init(
        watchTargets: [LiveSourceWatchTarget],
        knownCandidates: [CandidateSessionSnapshot],
        reconciliationSourceID: SessionSourceID?
    ) {
        self.watchTargets = watchTargets
        self.knownCandidates = knownCandidates
        self.reconciliationSourceID = reconciliationSourceID
    }
}

public final class LiveRefreshPipelineCoordinator: @unchecked Sendable {
    private let sourceChangeObservation: any LiveSourceChangeObservationPort
    private let reconciliation: ReconcileSessionSourcesUseCase
    private let timerScheduler: any LiveRefreshTimerScheduling
    private let debounceInterval: TimeInterval
    private let reconciliationInterval: TimeInterval
    private let refreshHandler: (LiveRefreshRequest) -> Void
    private let lock = NSLock()

    private var observation: (any LiveSourceObservation)?
    private var debounceScheduler: DebouncedLiveRefreshScheduler?
    private var triggerController: LiveRefreshTriggerController?
    private var configuration: LiveRefreshPipelineConfiguration?
    private var recordedMonitoringStates: [LiveMonitoringState] = []

    public init(
        sourceChangeObservation: any LiveSourceChangeObservationPort,
        reconciliation: ReconcileSessionSourcesUseCase,
        timerScheduler: any LiveRefreshTimerScheduling,
        debounceInterval: TimeInterval,
        reconciliationInterval: TimeInterval,
        refreshHandler: @escaping (LiveRefreshRequest) -> Void
    ) {
        self.sourceChangeObservation = sourceChangeObservation
        self.reconciliation = reconciliation
        self.timerScheduler = timerScheduler
        self.debounceInterval = debounceInterval
        self.reconciliationInterval = reconciliationInterval
        self.refreshHandler = refreshHandler
    }

    public var monitoringStates: [LiveMonitoringState] {
        lock.withLock {
            recordedMonitoringStates
        }
    }

    public func start(_ configuration: LiveRefreshPipelineConfiguration) {
        cancelCurrentMonitoring(recordStopped: false)
        lock.withLock {
            self.configuration = configuration
            self.recordedMonitoringStates = Self.initialMonitoringStates(for: configuration.watchTargets)
        }

        let debounceScheduler = DebouncedLiveRefreshScheduler(
            debounceInterval: debounceInterval,
            timerScheduler: timerScheduler
        ) { [weak self] request in
            self?.performRefresh(request)
        }
        let triggerController = LiveRefreshTriggerController(
            reconciliationInterval: reconciliationInterval,
            timerScheduler: timerScheduler
        ) { [weak self] request in
            self?.handleTriggerRequest(request)
        }
        let observation = sourceChangeObservation.observe(targets: configuration.watchTargets) { [weak self] event in
            self?.handleObservationEvent(event)
        }

        lock.withLock {
            self.debounceScheduler = debounceScheduler
            self.triggerController = triggerController
            self.observation = observation
        }

        triggerController.requestStartupRefresh(scope: .allSources)
        triggerController.scheduleReconciliation(scope: configuration.reconciliationSourceID.map(LiveRefreshScope.source) ?? .allSources)
    }

    public func stop() {
        cancelCurrentMonitoring(recordStopped: true)
    }

    private func cancelCurrentMonitoring(recordStopped: Bool) {
        let resources = lock.withLock {
            let resources = (observation, debounceScheduler, triggerController)
            observation = nil
            debounceScheduler = nil
            triggerController = nil
            configuration = nil
            if recordStopped {
                recordedMonitoringStates.append(.stopped)
            }
            return resources
        }

        resources.0?.cancel()
        resources.1?.cancel()
        resources.2?.cancel()
    }

    private func handleObservationEvent(_ event: LiveSourceObservationEvent) {
        switch event {
        case let .change(changeEvent):
            appendMonitoringState(.refreshPending(LiveRefreshRequest(
                scope: changeEvent.identity.refreshScope,
                trigger: .sourceChange,
                eventCount: 1
            )))
            currentDebounceScheduler()?.record(changeEvent)
        case let .degraded(degradedState):
            appendMonitoringState(.degraded(LiveMonitoringFailure(
                sourceID: degradedState.sourceID,
                reason: degradedState.reason.monitoringFailureReason,
                message: degradedState.reason.code
            )))
            performRefresh(LiveRefreshRequest(
                scope: degradedState.sourceID.map(LiveRefreshScope.source) ?? .allSources,
                trigger: .watcherDegraded,
                eventCount: 1
            ))
        }
    }

    private func handleTriggerRequest(_ request: LiveRefreshRequest) {
        if request.trigger == .reconciliation {
            runReconciliation(trigger: request.trigger)
            return
        }

        performRefresh(request)
    }

    private func runReconciliation(trigger: LiveRefreshTrigger) {
        guard let configuration = currentConfiguration() else {
            return
        }
        appendMonitoringState(.reconciling(sourceID: configuration.reconciliationSourceID, trigger: trigger))

        do {
            let result = try reconciliation.reconcile(
                sourceID: configuration.reconciliationSourceID,
                knownCandidates: configuration.knownCandidates,
                trigger: trigger
            )
            appendMonitoringStates(result.monitoringStates)
            if let refreshRequest = result.refreshRequest {
                performRefresh(refreshRequest)
            }
        } catch let error as ReconcileSessionSourcesError {
            appendMonitoringState(error.monitoringState)
        } catch {
            appendMonitoringState(.degraded(LiveMonitoringFailure(
                sourceID: configuration.reconciliationSourceID,
                reason: .reconciliationFailed,
                message: String(describing: error)
            )))
        }
    }

    private func performRefresh(_ request: LiveRefreshRequest) {
        guard currentConfiguration() != nil else {
            return
        }
        appendMonitoringState(.refreshRunning(request))
        refreshHandler(request)
        appendMonitoringState(.current(sourceID: request.scope.sourceID))
    }

    private func currentConfiguration() -> LiveRefreshPipelineConfiguration? {
        lock.withLock {
            configuration
        }
    }

    private func currentDebounceScheduler() -> DebouncedLiveRefreshScheduler? {
        lock.withLock {
            debounceScheduler
        }
    }

    private func appendMonitoringState(_ state: LiveMonitoringState) {
        lock.withLock {
            recordedMonitoringStates.append(state)
        }
    }

    private func appendMonitoringStates(_ states: [LiveMonitoringState]) {
        lock.withLock {
            recordedMonitoringStates.append(contentsOf: states)
        }
    }

    private static func initialMonitoringStates(for targets: [LiveSourceWatchTarget]) -> [LiveMonitoringState] {
        let sourceIDs = Set(targets.map(\.sourceID))
        if sourceIDs.isEmpty {
            return [.watching(sourceID: nil)]
        }

        return sourceIDs
            .sorted { $0.rawValue < $1.rawValue }
            .map { .watching(sourceID: $0) }
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

private extension LiveRefreshScope {
    var sourceID: SessionSourceID? {
        switch self {
        case .allSources:
            return nil
        case let .source(sourceID):
            return sourceID
        case let .session(_, sourceID):
            return sourceID
        case let .path(_, sourceID):
            return sourceID
        }
    }
}

private extension LiveSourceWatcherDegradedReason {
    var monitoringFailureReason: LiveMonitoringFailureReason {
        switch self {
        case .missingPath, .deletedPath:
            return .sourceMissing
        case .permissionDenied:
            return .permissionDenied
        case .unsupportedEvent, .unavailable:
            return .watcherSetupFailed
        }
    }
}
