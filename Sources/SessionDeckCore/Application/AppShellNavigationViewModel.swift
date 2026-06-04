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

}
