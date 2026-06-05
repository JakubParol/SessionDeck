struct BoundedToolBody: Equatable {
    let text: String?
    let availability: TranscriptToolBodyAvailability
}

extension CodexTranscriptDecodingAdapter {
    func boundedToolBody(_ body: String?, maximumCharacters: Int) -> BoundedToolBody {
        guard let body else {
            return BoundedToolBody(text: nil, availability: .omitted)
        }

        guard body.count > maximumCharacters else {
            return BoundedToolBody(text: body, availability: .available)
        }

        let endIndex = body.index(body.startIndex, offsetBy: maximumCharacters)
        return BoundedToolBody(
            text: String(body[..<endIndex]),
            availability: .truncated
        )
    }
}
