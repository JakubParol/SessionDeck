enum AppShellNavigationOrdering {
    static let recentlyActiveLimit = 10

    static func recentlyActiveSessionIDs(from orderedSessions: [SessionSummary]) -> [SessionID] {
        orderedSessions.prefix(recentlyActiveLimit).map(\.id)
    }

    static func sortNodesByRecency(
        _ nodes: [(node: AppShellNavigationNode, sessions: [SessionSummary])]
    ) -> [AppShellNavigationNode] {
        nodes.sorted { lhs, rhs in
            let lhsActivity = SessionCatalogOrdering.sort(lhs.sessions).first?.lastActivitySortKey
            let rhsActivity = SessionCatalogOrdering.sort(rhs.sessions).first?.lastActivitySortKey

            switch (lhsActivity, rhsActivity) {
            case let (lhsTimestamp?, rhsTimestamp?) where lhsTimestamp != rhsTimestamp:
                return lhsTimestamp > rhsTimestamp
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.node.title == rhs.node.title
                    ? lhs.node.id < rhs.node.id
                    : lhs.node.title < rhs.node.title
            }
        }
        .map(\.node)
    }
}
