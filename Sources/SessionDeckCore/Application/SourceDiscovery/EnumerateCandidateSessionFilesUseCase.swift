public struct EnumerateCandidateSessionFilesUseCase: Sendable {
    private let candidateFileEnumeration: any CandidateSessionFileEnumerationPort

    public init(candidateFileEnumeration: any CandidateSessionFileEnumerationPort) {
        self.candidateFileEnumeration = candidateFileEnumeration
    }

    public func enumerateCandidateFiles(sourceID: SessionSourceID? = nil) throws -> [CandidateSessionFile] {
        try candidateFileEnumeration.enumerateCandidateFiles(sourceID: sourceID)
    }
}
