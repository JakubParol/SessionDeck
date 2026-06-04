public struct AppShellNavigationSummary: Equatable, Sendable {
    public static let placeholder = AppShellNavigationSummary(
        allChatsNode: AppShellNavigationNode(
            id: "all-chats",
            title: "All Chats",
            count: 0,
            sessionIDs: []
        ),
        projectsNode: AppShellNavigationNode(
            id: "projects",
            title: "Projects",
            count: 0,
            sessionIDs: []
        ),
        nonProjectChatsNode: AppShellNavigationNode(
            id: "non-project-chats",
            title: "Non-project Chats",
            count: 0,
            sessionIDs: []
        ),
        sourcesNode: AppShellNavigationNode(
            id: "sources",
            title: "Sources / Profiles",
            count: 0,
            sessionIDs: []
        ),
        recentlyActiveNode: AppShellNavigationNode(
            id: "recently-active",
            title: "Recently Active",
            count: 0,
            sessionIDs: []
        ),
        diagnosticsNode: AppShellNavigationNode(
            id: "diagnostics",
            title: "Diagnostics",
            count: 0,
            sessionIDs: []
        )
    )

    public let allChatsNode: AppShellNavigationNode
    public let projectsNode: AppShellNavigationNode
    public let nonProjectChatsNode: AppShellNavigationNode
    public let sourcesNode: AppShellNavigationNode
    public let recentlyActiveNode: AppShellNavigationNode
    public let diagnosticsNode: AppShellNavigationNode

    public var sectionNodes: [AppShellNavigationNode] {
        [
            allChatsNode,
            projectsNode,
            nonProjectChatsNode,
            sourcesNode,
            recentlyActiveNode,
            diagnosticsNode,
        ]
    }

    public var problemSessionsNode: AppShellNavigationNode {
        diagnosticsNode.children.first(where: { $0.id == "diagnostics.problem-sessions" })
            ?? AppShellNavigationNode(
                id: "diagnostics.problem-sessions",
                title: "Problem Sessions",
                count: 0,
                sessionIDs: []
            )
    }

    public init(
        allChatsNode: AppShellNavigationNode,
        projectsNode: AppShellNavigationNode,
        nonProjectChatsNode: AppShellNavigationNode,
        sourcesNode: AppShellNavigationNode,
        recentlyActiveNode: AppShellNavigationNode,
        diagnosticsNode: AppShellNavigationNode
    ) {
        self.allChatsNode = allChatsNode
        self.projectsNode = projectsNode
        self.nonProjectChatsNode = nonProjectChatsNode
        self.sourcesNode = sourcesNode
        self.recentlyActiveNode = recentlyActiveNode
        self.diagnosticsNode = diagnosticsNode
    }

    public static func make(snapshot: CatalogSnapshot) -> AppShellNavigationSummary {
        let sessionIDs = snapshot.sessions.map(\.id)
        let problemGroups = problemCategoriesBySession(snapshot: snapshot)
        let problemSessionIDs = problemGroups.values
            .flatMap { $0 }
            .uniqueSortedByRawValue()
        let categoryNodes: [AppShellNavigationNode] = AppShellNavigationProblemCategory.navigationOrder.compactMap { category in
            guard let categorySessionIDs = problemGroups[category], categorySessionIDs.isEmpty == false else {
                return nil
            }

            return AppShellNavigationNode(
                id: "diagnostics.problem-sessions.\(category.rawValue)",
                title: category.label,
                count: categorySessionIDs.count,
                sessionIDs: categorySessionIDs.uniqueSortedByRawValue(),
                problemCategory: category
            )
        }
        let problemSessionsNode = AppShellNavigationNode(
            id: "diagnostics.problem-sessions",
            title: "Problem Sessions",
            count: problemSessionIDs.count,
            sessionIDs: problemSessionIDs,
            children: categoryNodes
        )

        return AppShellNavigationSummary(
            allChatsNode: AppShellNavigationNode(
                id: "all-chats",
                title: "All Chats",
                count: sessionIDs.count,
                sessionIDs: sessionIDs
            ),
            projectsNode: AppShellNavigationNode(
                id: "projects",
                title: "Projects",
                count: 0,
                sessionIDs: []
            ),
            nonProjectChatsNode: AppShellNavigationNode(
                id: "non-project-chats",
                title: "Non-project Chats",
                count: 0,
                sessionIDs: []
            ),
            sourcesNode: AppShellNavigationNode(
                id: "sources",
                title: "Sources / Profiles",
                count: 0,
                sessionIDs: []
            ),
            recentlyActiveNode: AppShellNavigationNode(
                id: "recently-active",
                title: "Recently Active",
                count: 0,
                sessionIDs: []
            ),
            diagnosticsNode: AppShellNavigationNode(
                id: "diagnostics",
                title: "Diagnostics",
                count: problemSessionIDs.count,
                sessionIDs: problemSessionIDs,
                children: [problemSessionsNode]
            )
        )
    }

    private static func problemCategoriesBySession(
        snapshot: CatalogSnapshot
    ) -> [AppShellNavigationProblemCategory: [SessionID]] {
        var groups: [AppShellNavigationProblemCategory: [SessionID]] = [:]
        let diagnosticsBySessionID = Dictionary(
            grouping: snapshot.diagnostics.flatMap { diagnostic in
                diagnostic.sessionIDs.map { (sessionID: $0, diagnostic: diagnostic) }
            },
            by: \.sessionID
        )

        for session in snapshot.sessions {
            let categories = problemCategories(
                for: session,
                snapshotDiagnostics: diagnosticsBySessionID[session.id]?.map(\.diagnostic) ?? []
            )

            for category in categories {
                groups[category, default: []].append(session.id)
            }
        }

        return groups
    }

    private static func problemCategories(
        for session: SessionSummary,
        snapshotDiagnostics: [CatalogSnapshotDiagnostic]
    ) -> [AppShellNavigationProblemCategory] {
        var categories: [AppShellNavigationProblemCategory] = []

        if session.sessionPath.isEmpty || session.fallbackReasons.contains(.missingPath) {
            categories.append(.missingPath)
        }
        if session.fallbackReasons.contains(.unknownSource) {
            categories.append(.unknownSource)
        }
        if session.fallbackReasons.contains(.ambiguousProject) {
            categories.append(.ambiguousProject)
        }

        let hasPermissionDiagnostic = session.health.diagnostics.contains {
            $0.problemCategories.contains(.permissionDenied)
        }
        switch session.health.parseStatus {
        case .complete:
            break
        case .missingMetadata:
            categories.append(.missingMetadata)
        case .malformed:
            categories.append(.malformedMetadata)
        case let .unreadable(reason) where reason.localizedCaseInsensitiveContains("permission"):
            categories.append(.permissionDenied)
        case .unreadable where hasPermissionDiagnostic:
            break
        case .unreadable:
            categories.append(.parseWarning)
        }

        for diagnostic in session.health.diagnostics {
            categories.append(contentsOf: diagnostic.problemCategories)
        }
        if snapshotDiagnostics.isEmpty == false {
            categories.append(.parseWarning)
        }

        return categories.uniquePreservingOrder()
    }
}

private extension AppShellNavigationProblemCategory {
    static let navigationOrder: [AppShellNavigationProblemCategory] = [
        .missingPath,
        .permissionDenied,
        .missingMetadata,
        .malformedMetadata,
        .parseWarning,
        .unknownSource,
        .ambiguousProject,
    ]
}

private extension CatalogEntryDiagnostic {
    var problemCategories: [AppShellNavigationProblemCategory] {
        switch code {
        case .permissionDenied:
            return [.permissionDenied]
        case .missingMetadata:
            return [.missingMetadata]
        case .malformedJSONL:
            return [.malformedMetadata]
        case .unreadableFile where message.localizedCaseInsensitiveContains("permission"):
            return [.permissionDenied]
        case .unknownEventShape, .boundedReadTruncated, .unreadableFile:
            return [.parseWarning]
        }
    }
}

private extension Array where Element == AppShellNavigationProblemCategory {
    func uniquePreservingOrder() -> [AppShellNavigationProblemCategory] {
        var seen: Set<AppShellNavigationProblemCategory> = []
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == SessionID {
    func uniqueSortedByRawValue() -> [SessionID] {
        var seen: Set<SessionID> = []
        return filter { seen.insert($0).inserted }
            .sorted { $0.rawValue < $1.rawValue }
    }
}
