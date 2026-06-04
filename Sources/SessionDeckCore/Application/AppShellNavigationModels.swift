public enum AppShellNavigationProblemCategory: String, Equatable, Hashable, Sendable {
    case missingPath
    case permissionDenied
    case missingMetadata
    case malformedMetadata
    case parseWarning
    case unknownSource
    case ambiguousProject

    public var label: String {
        switch self {
        case .missingPath:
            return "Missing path"
        case .permissionDenied:
            return "Permission denied"
        case .missingMetadata:
            return "Missing metadata"
        case .malformedMetadata:
            return "Malformed metadata"
        case .parseWarning:
            return "Parse warning"
        case .unknownSource:
            return "Unknown source"
        case .ambiguousProject:
            return "Ambiguous project"
        }
    }
}

public struct AppShellNavigationNode: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let count: Int
    public let sessionIDs: [SessionID]
    public let problemCategory: AppShellNavigationProblemCategory?
    public let children: [AppShellNavigationNode]

    public init(
        id: String,
        title: String,
        count: Int,
        sessionIDs: [SessionID],
        problemCategory: AppShellNavigationProblemCategory? = nil,
        children: [AppShellNavigationNode] = []
    ) {
        self.id = id
        self.title = title
        self.count = count
        self.sessionIDs = sessionIDs
        self.problemCategory = problemCategory
        self.children = children
    }

    public var countLabel: String {
        count == 1 ? "1 session" : "\(count) sessions"
    }
}
