public enum TranscriptSegmentRole: Equatable, Sendable {
    case user
    case assistant
    case tool
    case diagnostic
    case unknown(String)
}

public enum TranscriptSegmentKind: Equatable, Sendable {
    case userMessage
    case assistantMessage
    case toolCall(name: String, callID: String?)
    case toolOutput(callID: String?)
    case error(code: String?)
    case unknown(eventType: String)
    case metadata(name: String)
}

public struct TranscriptSegmentOrder: Comparable, Equatable, Sendable {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    public static func < (lhs: TranscriptSegmentOrder, rhs: TranscriptSegmentOrder) -> Bool {
        lhs.index < rhs.index
    }
}

public struct TranscriptSegmentSourceReference: Equatable, Sendable {
    public let sourceID: SessionSourceID?
    public let relativePath: String?
    public let lineNumber: Int?

    public init(
        sourceID: SessionSourceID?,
        relativePath: String?,
        lineNumber: Int?
    ) {
        self.sourceID = sourceID
        self.relativePath = relativePath
        self.lineNumber = lineNumber
    }

    public func withLineNumber(_ lineNumber: Int?) -> TranscriptSegmentSourceReference {
        TranscriptSegmentSourceReference(
            sourceID: sourceID,
            relativePath: relativePath,
            lineNumber: lineNumber
        )
    }
}

public struct TranscriptSegment: Equatable, Sendable {
    public let id: String
    public let kind: TranscriptSegmentKind
    public let text: String
    public let order: TranscriptSegmentOrder
    public let source: TranscriptSegmentSourceReference
    public let timestampDescription: String?
    public let metadata: [String: String]

    public var role: TranscriptSegmentRole {
        switch kind {
        case .userMessage:
            .user
        case .assistantMessage:
            .assistant
        case .toolCall, .toolOutput:
            .tool
        case .error, .metadata:
            .diagnostic
        case let .unknown(eventType):
            .unknown(eventType)
        }
    }

    public init(
        id: String,
        kind: TranscriptSegmentKind,
        text: String,
        order: TranscriptSegmentOrder,
        source: TranscriptSegmentSourceReference,
        timestampDescription: String?,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.order = order
        self.source = source
        self.timestampDescription = timestampDescription
        self.metadata = metadata
    }

    public init(
        id: String,
        role: TranscriptSegmentRole,
        text: String,
        timestampDescription: String?
    ) {
        self.id = id
        self.kind = TranscriptSegmentKind(role: role)
        self.text = text
        self.order = TranscriptSegmentOrder(index: 0)
        self.source = TranscriptSegmentSourceReference(sourceID: nil, relativePath: nil, lineNumber: nil)
        self.timestampDescription = timestampDescription
        self.metadata = [:]
    }
}

private extension TranscriptSegmentKind {
    init(role: TranscriptSegmentRole) {
        switch role {
        case .user:
            self = .userMessage
        case .assistant:
            self = .assistantMessage
        case .tool:
            self = .toolOutput(callID: nil)
        case .diagnostic:
            self = .error(code: nil)
        case let .unknown(eventType):
            self = .unknown(eventType: eventType)
        }
    }
}

public enum TranscriptDecodeDiagnosticSeverity: Equatable, Sendable {
    case info
    case warning
    case error
}

public struct TranscriptDecodeDiagnostic: Equatable, Sendable {
    public let code: String
    public let severity: TranscriptDecodeDiagnosticSeverity
    public let message: String
    public let source: TranscriptSegmentSourceReference?
    public let allowsDecodingToContinue: Bool

    public init(
        code: String,
        severity: TranscriptDecodeDiagnosticSeverity,
        message: String,
        source: TranscriptSegmentSourceReference?,
        allowsDecodingToContinue: Bool
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.source = source
        self.allowsDecodingToContinue = allowsDecodingToContinue
    }
}

public struct TranscriptDecodeResult: Equatable, Sendable {
    public let sessionID: SessionID
    public let title: String
    public let segments: [TranscriptSegment]
    public let diagnostics: [TranscriptDecodeDiagnostic]
    public let isPartial: Bool

    public var orderedSegments: [TranscriptSegment] {
        segments.sorted { $0.order < $1.order }
    }

    public var canContinueDecoding: Bool {
        diagnostics.allSatisfy(\.allowsDecodingToContinue)
    }

    public init(
        sessionID: SessionID,
        title: String,
        segments: [TranscriptSegment],
        diagnostics: [TranscriptDecodeDiagnostic],
        isPartial: Bool
    ) {
        self.sessionID = sessionID
        self.title = title
        self.segments = segments
        self.diagnostics = diagnostics
        self.isPartial = isPartial
    }

    public func preview(isTruncated: Bool) -> TranscriptPreview {
        TranscriptPreview(
            sessionID: sessionID,
            title: title,
            segments: orderedSegments,
            isTruncated: isTruncated
        )
    }
}

public struct TranscriptPreview: Equatable, Sendable {
    public let sessionID: SessionID
    public let title: String
    public let segments: [TranscriptSegment]
    public let isTruncated: Bool

    public init(
        sessionID: SessionID,
        title: String,
        segments: [TranscriptSegment],
        isTruncated: Bool
    ) {
        self.sessionID = sessionID
        self.title = title
        self.segments = segments
        self.isTruncated = isTruncated
    }
}
