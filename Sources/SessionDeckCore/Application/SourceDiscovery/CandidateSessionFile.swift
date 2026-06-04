import Foundation

public enum CandidateSessionFileConfidence: Equatable, Sendable {
    case high
    case medium
    case low
}

public enum CandidateSessionFileDiagnosticCode: String, Equatable, Sendable {
    case codexCandidateFileUnreadable = "codex.candidate_file_unreadable"
}

public struct CandidateSessionFileDiagnostic: Equatable, Sendable {
    public let code: CandidateSessionFileDiagnosticCode
    public let severity: SourceDiagnosticSeverity
    public let allowsDiscoveryToContinue: Bool
    public let message: String

    public init(
        code: CandidateSessionFileDiagnosticCode,
        severity: SourceDiagnosticSeverity = .warning,
        allowsDiscoveryToContinue: Bool = true,
        message: String
    ) {
        self.code = code
        self.severity = severity
        self.allowsDiscoveryToContinue = allowsDiscoveryToContinue
        self.message = message
    }
}

public struct CandidateSessionFile: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let relativePath: String
    public let absolutePath: String
    public let byteSize: Int64
    public let modifiedAt: Date?
    public let confidence: CandidateSessionFileConfidence
    public let reason: String
    public let diagnostic: CandidateSessionFileDiagnostic?

    public init(
        sourceID: SessionSourceID,
        relativePath: String,
        absolutePath: String,
        byteSize: Int64,
        modifiedAt: Date?,
        confidence: CandidateSessionFileConfidence,
        reason: String,
        diagnostic: CandidateSessionFileDiagnostic?
    ) {
        self.sourceID = sourceID
        self.relativePath = relativePath
        self.absolutePath = absolutePath
        self.byteSize = byteSize
        self.modifiedAt = modifiedAt
        self.confidence = confidence
        self.reason = reason
        self.diagnostic = diagnostic
    }
}
