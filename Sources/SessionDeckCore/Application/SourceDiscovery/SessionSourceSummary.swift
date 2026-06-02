public enum SessionSourceKind: Equatable, Sendable {
    case codex
    case hermes
    case other(String)
}

public struct SessionSourceID: Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct SessionSourceSummary: Equatable, Sendable {
    public let id: SessionSourceID
    public let displayName: String
    public let kind: SessionSourceKind
    public let locationDescription: String
    public let isEnabled: Bool

    public init(
        id: SessionSourceID,
        displayName: String,
        kind: SessionSourceKind,
        locationDescription: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.locationDescription = locationDescription
        self.isEnabled = isEnabled
    }
}
