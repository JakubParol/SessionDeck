public struct CatalogSessionIdentity: Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct CatalogSourceLabel: Equatable, Sendable {
    public let sourceID: String
    public let displayName: String
    public let profileName: String?

    public init(sourceID: String, displayName: String, profileName: String?) {
        self.sourceID = sourceID
        self.displayName = displayName
        self.profileName = profileName
    }
}

public struct CatalogProjectHint: Equatable, Sendable {
    public static let unavailable = CatalogProjectHint(cwdPath: nil, displayName: "Non-project Chat")

    public let cwdPath: String?
    public let displayName: String

    public init(cwdPath: String?, displayName: String) {
        self.cwdPath = cwdPath
        self.displayName = displayName
    }
}

public struct CatalogActivityTimestamps: Equatable, Sendable {
    public let createdAtEpochSeconds: Int64?
    public let lastActivityEpochSeconds: Int64?

    public init(createdAtEpochSeconds: Int64?, lastActivityEpochSeconds: Int64?) {
        self.createdAtEpochSeconds = createdAtEpochSeconds
        self.lastActivityEpochSeconds = lastActivityEpochSeconds
    }
}

public struct CatalogFileSize: Equatable, Sendable {
    public let byteCount: Int64

    public init(byteCount: Int64) {
        self.byteCount = byteCount
    }
}

public struct CatalogSessionMetadata: Equatable, Sendable {
    public let modelName: String?
    public let agentProfileName: String?
    public let parentThreadID: SessionID?
    public let forkedFromID: SessionID?
    public let threadSource: String?
    public let agentNickname: String?
    public let agentRole: String?
    public let agentPath: String?

    public init(
        modelName: String?,
        agentProfileName: String?,
        parentThreadID: SessionID? = nil,
        forkedFromID: SessionID? = nil,
        threadSource: String? = nil,
        agentNickname: String? = nil,
        agentRole: String? = nil,
        agentPath: String? = nil
    ) {
        self.modelName = modelName
        self.agentProfileName = agentProfileName
        self.parentThreadID = parentThreadID
        self.forkedFromID = forkedFromID
        self.threadSource = threadSource
        self.agentNickname = agentNickname
        self.agentRole = agentRole
        self.agentPath = agentPath
    }
}

public enum CatalogSessionFallbackReason: String, Equatable, Sendable {
    case missingPath = "catalog.fallback.missing_path"
    case unknownSource = "catalog.fallback.unknown_source"
    case ambiguousProject = "catalog.fallback.ambiguous_project"
}

public enum CatalogParseStatus: Equatable, Sendable {
    case complete
    case missingMetadata
    case malformed(reason: String)
    case unreadable(reason: String)
}

public enum CatalogEntryDiagnosticCode: String, Equatable, Sendable {
    case malformedJSONL = "catalog.malformed_jsonl"
    case missingMetadata = "catalog.missing_metadata"
    case permissionDenied = "catalog.permission_denied"
    case unreadableFile = "catalog.unreadable_file"
    case unknownEventShape = "catalog.unknown_event_shape"
    case boundedReadTruncated = "catalog.bounded_read_truncated"
}

public enum CatalogEntryDiagnosticSeverity: Equatable, Sendable {
    case info
    case warning
    case error
}

public struct CatalogEntryDiagnostic: Equatable, Sendable {
    public let code: CatalogEntryDiagnosticCode
    public let severity: CatalogEntryDiagnosticSeverity
    public let message: String

    public init(
        code: CatalogEntryDiagnosticCode,
        severity: CatalogEntryDiagnosticSeverity,
        message: String
    ) {
        self.code = code
        self.severity = severity
        self.message = message
    }
}

public struct CatalogEntryHealth: Equatable, Sendable {
    public let parseStatus: CatalogParseStatus
    public let diagnostics: [CatalogEntryDiagnostic]
    public let allowsListing: Bool

    public init(
        parseStatus: CatalogParseStatus,
        diagnostics: [CatalogEntryDiagnostic] = [],
        allowsListing: Bool = true
    ) {
        self.parseStatus = parseStatus
        self.diagnostics = diagnostics
        self.allowsListing = allowsListing
    }
}
