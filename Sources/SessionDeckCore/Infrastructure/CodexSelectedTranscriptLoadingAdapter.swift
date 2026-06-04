import Foundation

public struct CodexSelectedTranscriptLoadingAdapter: SelectedTranscriptLoadingPort, Sendable {
    public init() {}

    public func loadSelectedTranscript(for session: SessionSummary) throws -> TranscriptDecodeResult {
        let transcriptURL = URL(fileURLWithPath: session.sessionPath)
        try validateTranscriptFile(at: transcriptURL, sessionID: session.id)

        let decoder = CodexTranscriptDecodingAdapter(
            files: [
                CodexTranscriptFile(
                    sessionID: session.id,
                    fileURL: transcriptURL,
                    source: TranscriptSegmentSourceReference(
                        sourceID: session.sourceID,
                        relativePath: transcriptURL.lastPathComponent,
                        lineNumber: nil
                    ),
                    fallbackTitle: session.displayTitle
                )
            ]
        )

        do {
            return try decoder.loadTranscript(sessionID: session.id)
        } catch CodexTranscriptDecodingError.transcriptUnavailable {
            throw SelectedTranscriptLoadingError.transcriptUnavailable(session.id)
        } catch CodexTranscriptDecodingError.unreadableTranscript {
            throw SelectedTranscriptLoadingError.transcriptUnreadable(session.id)
        }
    }

    private func validateTranscriptFile(at url: URL, sessionID: SessionID) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw SelectedTranscriptLoadingError.transcriptMissing(sessionID)
        }

        guard isDirectory.boolValue == false,
              fileManager.isReadableFile(atPath: url.path)
        else {
            throw SelectedTranscriptLoadingError.transcriptUnreadable(sessionID)
        }
    }
}
