import Foundation

public struct CandidateSessionSnapshot: Equatable, Hashable, Sendable {
    public let sourceID: SessionSourceID
    public let relativePath: String
    public let absolutePath: String
    public let byteSize: Int64
    public let modifiedAt: Date?

    public init(
        sourceID: SessionSourceID,
        relativePath: String,
        absolutePath: String,
        byteSize: Int64,
        modifiedAt: Date?
    ) {
        self.sourceID = sourceID
        self.relativePath = relativePath
        self.absolutePath = absolutePath
        self.byteSize = byteSize
        self.modifiedAt = modifiedAt
    }

    public init(candidate: CandidateSessionFile) {
        self.init(
            sourceID: candidate.sourceID,
            relativePath: candidate.relativePath,
            absolutePath: candidate.absolutePath,
            byteSize: candidate.byteSize,
            modifiedAt: candidate.modifiedAt
        )
    }

    fileprivate var identity: CandidateSessionSnapshotIdentity {
        CandidateSessionSnapshotIdentity(sourceID: sourceID, relativePath: relativePath)
    }
}

public enum ReconciliationChangeKind: Equatable, Sendable {
    case new
    case changed
    case missing
    case unchanged
}

public struct ReconciliationChange: Equatable, Sendable {
    public let kind: ReconciliationChangeKind
    public let previous: CandidateSessionSnapshot?
    public let current: CandidateSessionSnapshot?

    public init(kind: ReconciliationChangeKind, previous: CandidateSessionSnapshot?, current: CandidateSessionSnapshot?) {
        self.kind = kind
        self.previous = previous
        self.current = current
    }
}

public struct ReconciliationChangeCounts: Equatable, Sendable {
    public let new: Int
    public let changed: Int
    public let missing: Int
    public let unchanged: Int

    public init(new: Int, changed: Int, missing: Int, unchanged: Int) {
        self.new = new
        self.changed = changed
        self.missing = missing
        self.unchanged = unchanged
    }
}

public struct ReconcileSessionSourcesResult: Equatable, Sendable {
    public let sourceID: SessionSourceID?
    public let trigger: LiveRefreshTrigger
    public let changes: [ReconciliationChange]
    public let monitoringStates: [LiveMonitoringState]

    public init(
        sourceID: SessionSourceID?,
        trigger: LiveRefreshTrigger,
        changes: [ReconciliationChange],
        monitoringStates: [LiveMonitoringState]
    ) {
        self.sourceID = sourceID
        self.trigger = trigger
        self.changes = changes
        self.monitoringStates = monitoringStates
    }

    public var counts: ReconciliationChangeCounts {
        ReconciliationChangeCounts(
            new: changes.filter { $0.kind == .new }.count,
            changed: changes.filter { $0.kind == .changed }.count,
            missing: changes.filter { $0.kind == .missing }.count,
            unchanged: changes.filter { $0.kind == .unchanged }.count
        )
    }

    public var refreshRequest: LiveRefreshRequest? {
        let recoveredChangeCount = counts.new + counts.changed + counts.missing
        guard recoveredChangeCount > 0 else {
            return nil
        }

        return LiveRefreshRequest(
            scope: sourceID.map(LiveRefreshScope.source) ?? .allSources,
            trigger: trigger,
            eventCount: recoveredChangeCount
        )
    }
}

public struct ReconcileSessionSourcesError: Error, Equatable, Sendable {
    public let failure: LiveMonitoringFailure

    public init(failure: LiveMonitoringFailure) {
        self.failure = failure
    }

    public var monitoringState: LiveMonitoringState {
        .degraded(failure)
    }
}

public struct ReconcileSessionSourcesUseCase: Sendable {
    private let candidateEnumeration: any CandidateSessionFileEnumerationPort

    public init(candidateEnumeration: any CandidateSessionFileEnumerationPort) {
        self.candidateEnumeration = candidateEnumeration
    }

    public func reconcile(
        sourceID: SessionSourceID?,
        knownCandidates: [CandidateSessionSnapshot],
        trigger: LiveRefreshTrigger
    ) throws -> ReconcileSessionSourcesResult {
        let currentCandidates: [CandidateSessionSnapshot]

        do {
            currentCandidates = try candidateEnumeration
                .enumerateCandidateFiles(sourceID: sourceID)
                .map(CandidateSessionSnapshot.init(candidate:))
        } catch {
            throw ReconcileSessionSourcesError(
                failure: LiveMonitoringFailure(
                    sourceID: sourceID,
                    reason: .reconciliationFailed,
                    message: error.reconciliationMessage
                )
            )
        }

        let scopedKnownCandidates = knownCandidates.filter { snapshot in
            sourceID == nil || snapshot.sourceID == sourceID
        }
        let changes = Self.changes(previous: scopedKnownCandidates, current: currentCandidates)
        return ReconcileSessionSourcesResult(
            sourceID: sourceID,
            trigger: trigger,
            changes: changes,
            monitoringStates: Self.monitoringStates(sourceID: sourceID, changes: changes)
        )
    }

    private static func changes(
        previous: [CandidateSessionSnapshot],
        current: [CandidateSessionSnapshot]
    ) -> [ReconciliationChange] {
        let previousByIdentity = Self.snapshotsByIdentity(previous)
        let currentByIdentity = Self.snapshotsByIdentity(current)
        let identities = Set(previousByIdentity.keys).union(currentByIdentity.keys)

        return identities
            .map { identity -> ReconciliationChange in
                let previous = previousByIdentity[identity]
                let current = currentByIdentity[identity]

                switch (previous, current) {
                case (nil, let current?):
                    return ReconciliationChange(kind: .new, previous: nil, current: current)
                case (let previous?, nil):
                    return ReconciliationChange(kind: .missing, previous: previous, current: nil)
                case let (previous?, current?) where previous != current:
                    return ReconciliationChange(kind: .changed, previous: previous, current: current)
                case let (previous?, current?):
                    return ReconciliationChange(kind: .unchanged, previous: previous, current: current)
                case (nil, nil):
                    return ReconciliationChange(kind: .unchanged, previous: nil, current: nil)
                }
            }
            .sorted { lhs, rhs in
                if lhs.kind.sortRank != rhs.kind.sortRank {
                    return lhs.kind.sortRank < rhs.kind.sortRank
                }

                return lhs.sortPath < rhs.sortPath
            }
    }

    private static func snapshotsByIdentity(
        _ snapshots: [CandidateSessionSnapshot]
    ) -> [CandidateSessionSnapshotIdentity: CandidateSessionSnapshot] {
        var snapshotsByIdentity: [CandidateSessionSnapshotIdentity: CandidateSessionSnapshot] = [:]
        for snapshot in snapshots {
            snapshotsByIdentity[snapshot.identity] = snapshot
        }

        return snapshotsByIdentity
    }

    private static func monitoringStates(
        sourceID: SessionSourceID?,
        changes: [ReconciliationChange]
    ) -> [LiveMonitoringState] {
        if changes.contains(where: { $0.kind != .unchanged }) {
            return [.stale(sourceID: sourceID, reason: .missedChangeRecovered)]
        }

        return [.current(sourceID: sourceID)]
    }
}

private struct CandidateSessionSnapshotIdentity: Hashable {
    let sourceID: SessionSourceID
    let relativePath: String
}

private extension ReconciliationChange {
    var sortPath: String {
        current?.relativePath ?? previous?.relativePath ?? ""
    }
}

private extension ReconciliationChangeKind {
    var sortRank: Int {
        switch self {
        case .changed:
            return 0
        case .missing:
            return 1
        case .new:
            return 2
        case .unchanged:
            return 3
        }
    }
}

private extension Error {
    var reconciliationMessage: String {
        if let localizedError = self as? LocalizedError,
           let errorDescription = localizedError.errorDescription,
           errorDescription.isEmpty == false {
            return errorDescription
        }

        return String(describing: self)
    }
}
