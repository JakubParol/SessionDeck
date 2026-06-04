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

public struct CatalogFilterOptions: Equatable, Sendable {
    public let projectOptions: [CatalogProjectFilterOption]
    public let sourceOptions: [CatalogSourceFilterOption]
    public let profileOptions: [CatalogProfileFilterOption]
    public let parseStatusOptions: [CatalogParseStatusFilterOption]

    public init(
        projectOptions: [CatalogProjectFilterOption],
        sourceOptions: [CatalogSourceFilterOption],
        profileOptions: [CatalogProfileFilterOption],
        parseStatusOptions: [CatalogParseStatusFilterOption]
    ) {
        self.projectOptions = projectOptions
        self.sourceOptions = sourceOptions
        self.profileOptions = profileOptions
        self.parseStatusOptions = parseStatusOptions
    }
}

public struct CatalogProjectFilterOption: Equatable, Sendable {
    public let filter: CatalogProjectFilter
    public let title: String
    public let sessionCount: Int

    public init(filter: CatalogProjectFilter, title: String, sessionCount: Int) {
        self.filter = filter
        self.title = title
        self.sessionCount = sessionCount
    }
}

public struct CatalogSourceFilterOption: Equatable, Sendable {
    public let stableID: String
    public let sourceID: SessionSourceID?
    public let displayName: String
    public let isFallback: Bool
    public let sessionCount: Int

    public init(
        stableID: String,
        sourceID: SessionSourceID?,
        displayName: String,
        isFallback: Bool,
        sessionCount: Int
    ) {
        self.stableID = stableID
        self.sourceID = sourceID
        self.displayName = displayName
        self.isFallback = isFallback
        self.sessionCount = sessionCount
    }
}

public struct CatalogProfileFilterOption: Equatable, Sendable {
    public let filter: CatalogProfileFilter
    public let sourceStableID: String
    public let displayName: String
    public let isFallback: Bool
    public let sessionCount: Int

    public init(
        filter: CatalogProfileFilter,
        sourceStableID: String,
        displayName: String,
        isFallback: Bool,
        sessionCount: Int
    ) {
        self.filter = filter
        self.sourceStableID = sourceStableID
        self.displayName = displayName
        self.isFallback = isFallback
        self.sessionCount = sessionCount
    }
}

public struct CatalogParseStatusFilterOption: Equatable, Sendable {
    public let filter: CatalogParseStatusFilter
    public let sessionCount: Int

    public init(filter: CatalogParseStatusFilter, sessionCount: Int) {
        self.filter = filter
        self.sessionCount = sessionCount
    }
}
