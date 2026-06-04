public struct SourceProfileSourceNavigationMetadata: Equatable, Sendable {
    public let stableID: String
    public let sourceID: SessionSourceID?
    public let displayName: String
    public let isFallback: Bool

    public init(
        stableID: String,
        sourceID: SessionSourceID?,
        displayName: String,
        isFallback: Bool
    ) {
        self.stableID = stableID
        self.sourceID = sourceID
        self.displayName = displayName
        self.isFallback = isFallback
    }
}

public struct SourceProfileProfileNavigationMetadata: Equatable, Sendable {
    public let stableID: String
    public let sourceID: SessionSourceID?
    public let sourceStableID: String
    public let displayName: String
    public let isFallback: Bool

    public init(
        stableID: String,
        sourceID: SessionSourceID?,
        sourceStableID: String,
        displayName: String,
        isFallback: Bool
    ) {
        self.stableID = stableID
        self.sourceID = sourceID
        self.sourceStableID = sourceStableID
        self.displayName = displayName
        self.isFallback = isFallback
    }
}

public enum AppShellSourceProfileNavigationMetadata: Equatable, Sendable {
    case source(SourceProfileSourceNavigationMetadata)
    case profile(SourceProfileProfileNavigationMetadata)
}

public enum CatalogSessionScope: Equatable, Sendable {
    case all
    case sessionIDs([SessionID])
    case source(SourceProfileSourceNavigationMetadata)
    case profile(SourceProfileProfileNavigationMetadata)
}
