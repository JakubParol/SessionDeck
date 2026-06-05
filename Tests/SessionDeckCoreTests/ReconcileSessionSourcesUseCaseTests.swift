import Foundation
import Testing
@testable import SessionDeckCore

@Test("reconciliation detects new changed missing and unchanged candidate files")
func reconciliationDetectsCandidateFileChanges() throws {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let modifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let changedAt = Date(timeIntervalSince1970: 1_700_000_100)
    let unchanged = CandidateSessionSnapshot(
        sourceID: sourceID,
        relativePath: "2026/06/05/unchanged.jsonl",
        absolutePath: "/tmp/unchanged.jsonl",
        byteSize: 42,
        modifiedAt: modifiedAt
    )
    let changedBefore = CandidateSessionSnapshot(
        sourceID: sourceID,
        relativePath: "2026/06/05/changed.jsonl",
        absolutePath: "/tmp/changed.jsonl",
        byteSize: 42,
        modifiedAt: modifiedAt
    )
    let missing = CandidateSessionSnapshot(
        sourceID: sourceID,
        relativePath: "2026/06/05/missing.jsonl",
        absolutePath: "/tmp/missing.jsonl",
        byteSize: 12,
        modifiedAt: modifiedAt
    )
    let enumeration = ReconciliationCandidateEnumerationFake(
        candidates: [
            candidate(from: unchanged),
            candidate(
                sourceID: sourceID,
                relativePath: "2026/06/05/changed.jsonl",
                absolutePath: "/tmp/changed.jsonl",
                byteSize: 84,
                modifiedAt: changedAt
            ),
            candidate(
                sourceID: sourceID,
                relativePath: "2026/06/05/new.jsonl",
                absolutePath: "/tmp/new.jsonl",
                byteSize: 20,
                modifiedAt: changedAt
            ),
        ]
    )
    let useCase = ReconcileSessionSourcesUseCase(candidateEnumeration: enumeration)

    let result = try useCase.reconcile(
        sourceID: sourceID,
        knownCandidates: [unchanged, changedBefore, missing],
        trigger: .reconciliation
    )

    #expect(result.sourceID == sourceID)
    #expect(result.trigger == .reconciliation)
    #expect(result.changes.map(\.kind) == [.changed, .missing, .new, .unchanged])
    #expect(result.counts == ReconciliationChangeCounts(new: 1, changed: 1, missing: 1, unchanged: 1))
    #expect(result.monitoringStates.contains(.stale(sourceID: sourceID, reason: .missedChangeRecovered)))
    #expect(result.refreshRequest == LiveRefreshRequest(scope: .source(sourceID), trigger: .reconciliation, eventCount: 3))
}

@Test("reconciliation does not request refresh when empty source remains current")
func reconciliationDoesNotRequestRefreshForCurrentEmptySource() throws {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let enumeration = ReconciliationCandidateEnumerationFake()
    let useCase = ReconcileSessionSourcesUseCase(candidateEnumeration: enumeration)

    let result = try useCase.reconcile(sourceID: sourceID, knownCandidates: [], trigger: .reconciliation)

    #expect(result.changes.isEmpty)
    #expect(result.monitoringStates == [.current(sourceID: sourceID)])
    #expect(result.refreshRequest == nil)
}

@Test("reconciliation maps candidate enumeration failure to degraded monitoring state")
func reconciliationMapsEnumerationFailureToDegradedState() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let enumeration = ReconciliationCandidateEnumerationFake(error: FakeReconciliationError.failed)
    let useCase = ReconcileSessionSourcesUseCase(candidateEnumeration: enumeration)

    do {
        _ = try useCase.reconcile(sourceID: sourceID, knownCandidates: [], trigger: .reconciliation)
        Issue.record("Expected reconciliation to throw")
    } catch let error as ReconcileSessionSourcesError {
        #expect(error.failure.sourceID == sourceID)
        #expect(error.failure.reason == .reconciliationFailed)
        #expect(error.monitoringState == .degraded(error.failure))
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}

private func candidate(from snapshot: CandidateSessionSnapshot) -> CandidateSessionFile {
    candidate(
        sourceID: snapshot.sourceID,
        relativePath: snapshot.relativePath,
        absolutePath: snapshot.absolutePath,
        byteSize: snapshot.byteSize,
        modifiedAt: snapshot.modifiedAt
    )
}

private func candidate(
    sourceID: SessionSourceID,
    relativePath: String,
    absolutePath: String,
    byteSize: Int64,
    modifiedAt: Date?
) -> CandidateSessionFile {
    CandidateSessionFile(
        sourceID: sourceID,
        relativePath: relativePath,
        absolutePath: absolutePath,
        byteSize: byteSize,
        modifiedAt: modifiedAt,
        confidence: .high,
        reason: "test",
        diagnostic: nil
    )
}

private struct ReconciliationCandidateEnumerationFake: CandidateSessionFileEnumerationPort {
    let candidates: [CandidateSessionFile]
    let error: Error?

    init(candidates: [CandidateSessionFile] = [], error: Error? = nil) {
        self.candidates = candidates
        self.error = error
    }

    func enumerateCandidateFiles(sourceID: SessionSourceID?) throws -> [CandidateSessionFile] {
        if let error {
            throw error
        }

        return candidates.filter { candidate in
            sourceID == nil || candidate.sourceID == sourceID
        }
    }
}

private enum FakeReconciliationError: Error {
    case failed
}
