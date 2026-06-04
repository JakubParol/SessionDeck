extension CodexTranscriptDecodingAdapter {
    func toolMetadata(
        displayLabel: String,
        status: String?,
        bodyAvailability: TranscriptToolBodyAvailability,
        body: String?
    ) -> TranscriptToolMetadata {
        TranscriptToolMetadata(
            displayLabel: displayLabel,
            status: status,
            bodyAvailability: bodyAvailability,
            characterCount: body?.count,
            byteCount: body?.utf8.count,
            lineCount: body.map(lineCount(in:))
        )
    }

    func lineCount(in body: String) -> Int {
        if body.isEmpty {
            return 0
        }

        return body.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    func metadataValue(for availability: TranscriptToolBodyAvailability) -> String {
        switch availability {
        case .available:
            "available"
        case .omitted:
            "omitted"
        case .malformed:
            "malformed"
        case .truncated:
            "truncated"
        }
    }
}
