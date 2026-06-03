public enum SessionSourceKind: Equatable, Sendable {
    case codex
    case hermes
    case other(String)
}

public enum SourceAvailability: Equatable, Sendable {
    case available
    case missing
    case inaccessible
}

public struct SessionSourceID: Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct SessionSourceCounts: Equatable, Sendable {
    public static let empty = SessionSourceCounts(sessionDirectoryCount: 0, transcriptFileCount: 0)

    public let sessionDirectoryCount: Int
    public let transcriptFileCount: Int

    public init(sessionDirectoryCount: Int, transcriptFileCount: Int) {
        self.sessionDirectoryCount = sessionDirectoryCount
        self.transcriptFileCount = transcriptFileCount
    }
}

public struct SessionSourceDiagnostic: Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
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
