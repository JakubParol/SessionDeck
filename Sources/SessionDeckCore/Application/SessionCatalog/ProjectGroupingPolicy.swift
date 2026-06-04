public enum ProjectNavigationGroupKind: Equatable, Sendable {
    case project
    case nonProject
    case unknownProject
}

public struct ProjectNavigationGroup: Equatable, Sendable {
    public let kind: ProjectNavigationGroupKind
    public let id: String
    public let title: String
    public let sessionIDs: [SessionID]

    public init(
        kind: ProjectNavigationGroupKind,
        id: String,
        title: String,
        sessionIDs: [SessionID]
    ) {
        self.kind = kind
        self.id = id
        self.title = title
        self.sessionIDs = sessionIDs
    }
}

public enum ProjectGroupingPolicy {
    public static func resolve(sessions: [SessionSummary]) -> [ProjectNavigationGroup] {
        let groupedSessions = Dictionary(grouping: sessions, by: { resolve(session: $0).id })

        return groupedSessions.map { _, sessions in
            let orderedSessions = SessionCatalogOrdering.sort(sessions)
            let group = resolve(session: orderedSessions[0])
            return ProjectNavigationGroup(
                kind: group.kind,
                id: group.id,
                title: group.title,
                sessionIDs: orderedSessions.map(\.id)
            )
        }
        .sorted { lhs, rhs in
            lhs.title == rhs.title ? lhs.id < rhs.id : lhs.title < rhs.title
        }
    }

    public static func resolve(session: SessionSummary) -> ProjectNavigationGroup {
        let projectHint = session.projectHint

        guard session.fallbackReasons.contains(.ambiguousProject) == false else {
            return unknownProjectGroup(sessionID: session.id)
        }

        guard let cwdPath = normalizedPath(projectHint.cwdPath), cwdPath.isEmpty == false else {
            return nonProjectGroup(sessionID: session.id)
        }

        guard isMalformed(cwdPath: cwdPath, parseStatus: session.health.parseStatus) == false else {
            return unknownProjectGroup(sessionID: session.id)
        }

        let displayName = normalizedDisplayName(projectHint.displayName)
        guard isScratchPath(cwdPath, displayName: displayName) == false else {
            return unknownProjectGroup(sessionID: session.id)
        }

        return ProjectNavigationGroup(
            kind: .project,
            id: "project.\(cwdPath)",
            title: displayName ?? lastPathComponent(cwdPath) ?? "Unknown Project",
            sessionIDs: [session.id]
        )
    }

    private static func nonProjectGroup(sessionID: SessionID) -> ProjectNavigationGroup {
        ProjectNavigationGroup(
            kind: .nonProject,
            id: "non-project-chats",
            title: "Non-project Chats",
            sessionIDs: [sessionID]
        )
    }

    private static func unknownProjectGroup(sessionID: SessionID) -> ProjectNavigationGroup {
        ProjectNavigationGroup(
            kind: .unknownProject,
            id: "unknown-project",
            title: "Unknown Project",
            sessionIDs: [sessionID]
        )
    }

    private static func normalizedPath(_ path: String?) -> String? {
        guard let path else {
            return nil
        }

        let trimmed = trim(path)
        guard trimmed.isEmpty == false else {
            return nil
        }

        var normalized = trimmed
        while normalized.count > 1, normalized.last == "/" {
            normalized.removeLast()
        }

        return normalized
    }

    private static func normalizedDisplayName(_ displayName: String) -> String? {
        let trimmed = trim(displayName)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isMalformed(cwdPath: String, parseStatus: CatalogParseStatus) -> Bool {
        if cwdPath.contains("\u{0}") {
            return true
        }

        switch parseStatus {
        case .malformed, .missingMetadata:
            return true
        case .complete, .unreadable:
            return false
        }
    }

    private static func isScratchPath(_ cwdPath: String, displayName: String?) -> Bool {
        let lowercasedPath = cwdPath.lowercased()
        let lowercasedDisplayName = displayName?.lowercased()

        let isScratchDirectory = lowercasedPath.hasPrefix("/tmp/")
            || lowercasedPath.hasPrefix("/private/tmp/")
            || lowercasedPath.contains("/scratch/")
            || lowercasedPath.contains("/var/folders/")
        let hasGenericName = lowercasedDisplayName == nil
            || lowercasedDisplayName == "tmp"
            || lowercasedDisplayName == "scratch"
            || lowercasedDisplayName == "sessiondeck-scratch"

        return isScratchDirectory && hasGenericName
    }

    private static func lastPathComponent(_ path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        return components.last
    }

    private static func trim(_ value: String) -> String {
        String(value.drop(while: { $0.isWhitespace }).reversed().drop(while: { $0.isWhitespace }).reversed())
    }
}
