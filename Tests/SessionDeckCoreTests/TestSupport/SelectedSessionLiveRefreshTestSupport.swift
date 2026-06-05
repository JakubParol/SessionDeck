import SessionDeckCore

func selectedReadModel(
    _ session: SessionSummary,
    title: String,
    segments: [TranscriptSegment]
) -> SelectedTranscriptReadModel {
    SelectedTranscriptReadModel(
        session: session,
        decodeResult: selectedDecodeResult(sessionID: session.id, title: title, segments: segments)
    )
}

func selectedDecodeResult(
    sessionID: SessionID,
    title: String,
    segments: [TranscriptSegment]
) -> TranscriptDecodeResult {
    TranscriptDecodeResult(
        sessionID: sessionID,
        title: title,
        segments: segments,
        diagnostics: [],
        isPartial: false
    )
}

func selectedSegment(
    id: String,
    text: String,
    order: Int
) -> TranscriptSegment {
    TranscriptSegment(
        id: id,
        kind: .userMessage,
        text: text,
        order: TranscriptSegmentOrder(index: order),
        source: TranscriptSegmentSourceReference(sourceID: nil, relativePath: nil, lineNumber: order + 1),
        timestampDescription: nil
    )
}

final class RecordingSelectedTranscriptLoadingPort: SelectedTranscriptLoadingPort, @unchecked Sendable {
    private let resultsBySessionID: [SessionID: TranscriptDecodeResult]
    private(set) var loadCount = 0

    init(results: [SessionID: TranscriptDecodeResult]) {
        self.resultsBySessionID = results
    }

    func loadSelectedTranscript(for session: SessionSummary) throws -> TranscriptDecodeResult {
        loadCount += 1
        guard let result = resultsBySessionID[session.id] else {
            throw SelectedTranscriptLoadingError.transcriptUnavailable(session.id)
        }

        return result
    }
}

struct FailingSelectedTranscriptLoadingPort: SelectedTranscriptLoadingPort {
    func loadSelectedTranscript(for session: SessionSummary) throws -> TranscriptDecodeResult {
        throw SelectedTranscriptLoadingError.transcriptUnreadable(session.id)
    }
}

extension SelectedSessionLiveRefreshState {
    var loadedReadModel: SelectedTranscriptReadModel? {
        guard case let .loaded(readModel) = self else {
            return nil
        }

        return readModel
    }

    var previousReadModel: SelectedTranscriptReadModel? {
        switch self {
        case let .ignored(previous),
             let .refreshing(previous),
             let .failed(previous, _):
            return previous
        case .idle, .loaded:
            return nil
        }
    }
}
