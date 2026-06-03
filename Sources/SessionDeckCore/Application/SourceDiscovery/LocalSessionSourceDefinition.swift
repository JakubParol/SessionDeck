public struct LocalSessionSourceDefinition: Equatable, Sendable {
    public let id: SessionSourceID
    public let displayName: String
    public let kind: SessionSourceKind
    public let rootPath: String
    public let isEnabled: Bool

    public init(
        id: SessionSourceID,
        displayName: String,
        kind: SessionSourceKind,
        rootPath: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.rootPath = rootPath
        self.isEnabled = isEnabled
    }
}
