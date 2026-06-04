public protocol CandidateSessionFileEnumerationPort: Sendable {
    func enumerateCandidateFiles(sourceID: SessionSourceID?) throws -> [CandidateSessionFile]
}
