import Foundation

public enum SelectedSessionLiveRefreshState: Equatable, Sendable {
    case idle
    case ignored(previous: SelectedTranscriptReadModel?)
    case refreshing(previous: SelectedTranscriptReadModel?)
    case loaded(SelectedTranscriptReadModel)
    case failed(previous: SelectedTranscriptReadModel?, message: String)
}

public final class SelectedSessionLiveRefreshCoordinator: @unchecked Sendable {
    private let loadSelectedTranscript: LoadSelectedTranscriptUseCase
    private let stateRecorder: (SelectedSessionLiveRefreshState) -> Void
    private let lock = NSLock()
    private var recordedState: SelectedSessionLiveRefreshState = .idle

    public var state: SelectedSessionLiveRefreshState {
        lock.withLock {
            recordedState
        }
    }

    public init(
        loadSelectedTranscript: LoadSelectedTranscriptUseCase,
        stateRecorder: @escaping (SelectedSessionLiveRefreshState) -> Void = { _ in }
    ) {
        self.loadSelectedTranscript = loadSelectedTranscript
        self.stateRecorder = stateRecorder
    }

    public func handle(
        _ request: LiveRefreshRequest,
        selectedSession: SessionSummary?,
        currentReadModel: SelectedTranscriptReadModel?
    ) -> SelectedSessionLiveRefreshState {
        guard let selectedSession,
              SelectedSessionLiveRefreshPolicy.shouldRefreshSelectedSession(selectedSession, for: request)
        else {
            return record(.ignored(previous: currentReadModel))
        }

        record(.refreshing(previous: currentReadModel))

        do {
            let refreshedModel = try loadSelectedTranscript.loadTranscript(for: selectedSession)
            return record(.loaded(refreshedModel))
        } catch {
            return record(.failed(previous: currentReadModel, message: String(describing: error)))
        }
    }

    @discardableResult
    private func record(_ nextState: SelectedSessionLiveRefreshState) -> SelectedSessionLiveRefreshState {
        lock.withLock {
            recordedState = nextState
        }
        stateRecorder(nextState)
        return nextState
    }
}
