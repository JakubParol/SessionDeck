public enum SessionSourceKind: Equatable, Sendable {
    case codex
    case hermes
    case other(String)
}

public enum SourceAvailability: Equatable, Sendable {
    case available
    case missing
    case inaccessible
    case duplicate
    case unsupported
    case disabled
}

public struct SessionSourceID: Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct SessionSourceCounts: Equatable, Sendable {
    public static let empty = SessionSourceCounts(sessionBucketDirectoryCount: 0, transcriptFileCount: 0)

    public let sessionBucketDirectoryCount: Int
    public let transcriptFileCount: Int

    public init(sessionBucketDirectoryCount: Int, transcriptFileCount: Int) {
        self.sessionBucketDirectoryCount = sessionBucketDirectoryCount
        self.transcriptFileCount = transcriptFileCount
    }
}

public enum SessionSourceDiagnosticCode: String, Equatable, Sendable {
    case codexSessionsRootMissing = "codex.sessions_root_missing"
    case codexSessionsRootPermissionDenied = "codex.sessions_root_permission_denied"
    case codexSessionsRootUnreadable = "codex.sessions_root_unreadable"
    case codexSessionsRootEmpty = "codex.sessions_root_empty"
    case codexSessionsRootStale = "codex.sessions_root_stale"
    case sourceRootDuplicate = "source_root_duplicate"
    case sourceKindUnsupported = "source_kind_unsupported"
    case sourceRootDisabled = "source_root_disabled"
}

public enum SourceDiagnosticSeverity: Equatable, Sendable {
    case info
    case warning
    case error
}

public struct SessionSourceDiagnostic: Equatable, Sendable {
    public let code: SessionSourceDiagnosticCode
    public let severity: SourceDiagnosticSeverity
    public let allowsDiscoveryToContinue: Bool
    public let message: String

    public init(
        code: SessionSourceDiagnosticCode,
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

public struct SessionSourceSummary: Equatable, Sendable {
    public let id: SessionSourceID
    public let displayName: String
    public let kind: SessionSourceKind
    public let locationDescription: String
    public let availability: SourceAvailability
    public let diagnostic: SessionSourceDiagnostic?
    public let counts: SessionSourceCounts
    public let isEnabled: Bool

    public init(
        id: SessionSourceID,
        displayName: String,
        kind: SessionSourceKind,
        locationDescription: String,
        isEnabled: Bool,
        availability: SourceAvailability? = nil,
        diagnostic: SessionSourceDiagnostic? = nil,
        counts: SessionSourceCounts = .empty
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.locationDescription = locationDescription
        self.availability = availability ?? (isEnabled ? .available : .missing)
        self.diagnostic = diagnostic
        self.counts = counts
        self.isEnabled = isEnabled
    }
}
