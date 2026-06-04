public struct CatalogQueryRequest: Equatable, Sendable {
    public let searchText: String
    public let project: CatalogProjectFilter?
    public let sourceID: SessionSourceID?
    public let profile: CatalogProfileFilter?
    public let parseStatuses: Set<CatalogParseStatusFilter>
    public let sort: CatalogQuerySort

    public init(
        searchText: String = "",
        project: CatalogProjectFilter? = nil,
        sourceID: SessionSourceID? = nil,
        profile: CatalogProfileFilter? = nil,
        parseStatuses: Set<CatalogParseStatusFilter> = [],
        sort: CatalogQuerySort = .lastActivityDescending
    ) {
        self.searchText = searchText
        self.project = project
        self.sourceID = sourceID
        self.profile = profile
        self.parseStatuses = parseStatuses
        self.sort = sort
    }
}

public enum CatalogProjectFilter: Equatable, Hashable, Sendable {
    case project(id: String)
    case nonProject
    case unknownProject
}

public struct CatalogProfileFilter: Equatable, Hashable, Sendable {
    public let stableID: String
    public let sourceID: SessionSourceID?

    public init(stableID: String, sourceID: SessionSourceID?) {
        self.stableID = stableID
        self.sourceID = sourceID
    }
}

public enum CatalogParseStatusFilter: Equatable, Hashable, Sendable {
    case complete
    case missingMetadata
    case malformed
    case unreadable
}

public enum CatalogQuerySort: Equatable, Sendable {
    case lastActivityDescending
}
