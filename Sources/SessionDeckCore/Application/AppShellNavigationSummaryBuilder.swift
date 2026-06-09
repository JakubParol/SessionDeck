public extension AppShellNavigationSummary {
    static func make(snapshot: CatalogSnapshot) -> AppShellNavigationSummary {
        let orderedSessions = SessionCatalogOrdering.sort(snapshot.sessions)
        let sessionIDs = orderedSessions.map(\.id)
        let recentlyActiveSessionIDs = AppShellNavigationOrdering.recentlyActiveSessionIDs(from: orderedSessions)
        let problemSessionsNode = problemSessionsNode(snapshot: snapshot)

        return AppShellNavigationSummary(
            allChatsNode: AppShellNavigationNode(
                id: "all-chats",
                title: "All Chats",
                count: sessionIDs.count,
                sessionIDs: sessionIDs
            ),
            projectsNode: projectsNode(sessions: orderedSessions),
            nonProjectChatsNode: nonProjectChatsNode(sessions: orderedSessions),
            sourcesNode: sourcesNode(sessions: orderedSessions),
            recentlyActiveNode: AppShellNavigationNode(
                id: "recently-active",
                title: "Recently Active",
                count: recentlyActiveSessionIDs.count,
                sessionIDs: recentlyActiveSessionIDs
            ),
            diagnosticsNode: AppShellNavigationNode(
                id: "diagnostics",
                title: "Diagnostics",
                count: problemSessionsNode.count,
                sessionIDs: problemSessionsNode.sessionIDs,
                children: [problemSessionsNode]
            )
        )
    }

    private static func projectsNode(sessions: [SessionSummary]) -> AppShellNavigationNode {
        let projectSessions = sessions.filter { session in
            ProjectGroupingPolicy.resolve(session: session).kind != .nonProject
        }
        let children = projectNodes(sessions: projectSessions)

        return AppShellNavigationNode(
            id: "projects",
            title: "Projects",
            count: projectSessions.count,
            sessionIDs: projectSessions.map(\.id),
            children: children
        )
    }

    private static func projectNodes(sessions: [SessionSummary]) -> [AppShellNavigationNode] {
        AppShellNavigationOrdering.sortNodesByRecency(
            Dictionary(grouping: sessions, by: { ProjectGroupingPolicy.resolve(session: $0).id })
                .map { groupKey, groupSessions in
                    let orderedGroupSessions = SessionCatalogOrdering.sort(groupSessions)
                    let projectGroup = ProjectGroupingPolicy.resolve(session: orderedGroupSessions[0])
                    return (
                        node: AppShellNavigationNode(
                            id: "projects.\(groupKey)",
                            title: projectGroup.title,
                            count: orderedGroupSessions.count,
                            sessionIDs: orderedGroupSessions.map(\.id),
                            children: threadNodes(
                                sessions: orderedGroupSessions,
                                idPrefix: "projects.\(groupKey).thread"
                            )
                        ),
                        sessions: groupSessions
                    )
                }
        )
    }

    private static func nonProjectChatsNode(sessions: [SessionSummary]) -> AppShellNavigationNode {
        let nonProjectSessions = sessions.filter { session in
            ProjectGroupingPolicy.resolve(session: session).kind == .nonProject
        }

        return AppShellNavigationNode(
            id: "non-project-chats",
            title: "Non-project Chats",
            count: nonProjectSessions.count,
            sessionIDs: nonProjectSessions.map(\.id)
        )
    }

    private static func sourcesNode(sessions: [SessionSummary]) -> AppShellNavigationNode {
        let children = AppShellNavigationOrdering.sortNodesByRecency(
            Dictionary(grouping: sessions, by: { SourceProfileNavigationPolicy.sourceMetadata(for: $0).stableID })
                .map { (node: sourceNode(sessions: $0.value), sessions: $0.value) }
        )

        return AppShellNavigationNode(
            id: "sources",
            title: "Sources / Profiles",
            count: sessions.count,
            sessionIDs: sessions.map(\.id),
            children: children
        )
    }

    private static func sourceNode(sessions: [SessionSummary]) -> AppShellNavigationNode {
        let orderedSessions = SessionCatalogOrdering.sort(sessions)
        let sourceMetadata = SourceProfileNavigationPolicy.sourceMetadata(for: orderedSessions[0])
        let sessionIDs = orderedSessions.map { $0.id }

        return AppShellNavigationNode(
            id: "sources." + sourceMetadata.stableID,
            title: sourceMetadata.displayName,
            count: orderedSessions.count,
            sessionIDs: sessionIDs,
            catalogScope: .source(sourceMetadata),
            sourceProfileMetadata: .source(sourceMetadata),
            children: profileNodes(sessions: orderedSessions)
        )
    }

    private static func profileNodes(sessions: [SessionSummary]) -> [AppShellNavigationNode] {
        AppShellNavigationOrdering.sortNodesByRecency(
            Dictionary(grouping: sessions, by: { SourceProfileNavigationPolicy.profileMetadata(for: $0).stableID })
                .map { (node: profileNode(sessions: $0.value), sessions: $0.value) }
        )
    }

    private static func profileNode(sessions: [SessionSummary]) -> AppShellNavigationNode {
        let orderedSessions = SessionCatalogOrdering.sort(sessions)
        let profileMetadata = SourceProfileNavigationPolicy.profileMetadata(for: orderedSessions[0])
        let sessionIDs = orderedSessions.map { $0.id }

        return AppShellNavigationNode(
            id: "sources." + profileMetadata.stableID,
            title: profileMetadata.displayName,
            count: orderedSessions.count,
            sessionIDs: sessionIDs,
            catalogScope: .profile(profileMetadata),
            sourceProfileMetadata: .profile(profileMetadata)
        )
    }

    private static func problemSessionsNode(snapshot: CatalogSnapshot) -> AppShellNavigationNode {
        let problemGroups = problemCategoriesBySession(snapshot: snapshot)
        let problemSessionIDs = problemGroups.values
            .flatMap { $0 }
            .uniqueSortedByRawValue()
        let categoryNodes: [AppShellNavigationNode] = AppShellNavigationProblemCategory.navigationOrder.compactMap {
            category in
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

        return AppShellNavigationNode(
            id: "diagnostics.problem-sessions",
            title: "Problem Sessions",
            count: problemSessionIDs.count,
            sessionIDs: problemSessionIDs,
            children: categoryNodes
        )
    }

    private static func threadNodes(
        sessions: [SessionSummary],
        idPrefix: String
    ) -> [AppShellNavigationNode] {
        let orderedSessions = SessionCatalogOrdering.sort(sessions)
        let sessionIDs = Set(orderedSessions.map(\.id))
        let parentPairs: [(parentID: SessionID, session: SessionSummary)] = orderedSessions.compactMap { session in
            guard let parentID = relationshipParentID(for: session, sessionIDs: sessionIDs) else {
                return nil
            }
            return (parentID: parentID, session: session)
        }
        let childSessionsByParent = Dictionary(grouping: parentPairs) { $0.parentID }
            .mapValues { parentPairs in
                SessionCatalogOrdering.sort(parentPairs.map(\.session))
            }
        let threadedSessionIDs = Set(parentPairs.flatMap { [$0.parentID, $0.session.id] })
        guard threadedSessionIDs.isEmpty == false else {
            return []
        }

        let threadedSessions = orderedSessions.filter { threadedSessionIDs.contains($0.id) }
        let rootSessions = threadedSessions.filter {
            relationshipParentID(for: $0, sessionIDs: sessionIDs) == nil
        }
        let safeRootSessions = rootSessions.isEmpty ? threadedSessions : rootSessions

        return safeRootSessions.map { session in
            threadNode(
                session: session,
                idPrefix: idPrefix,
                childSessionsByParent: childSessionsByParent,
                visitedSessionIDs: []
            )
        }
    }

    private static func threadNode(
        session: SessionSummary,
        idPrefix: String,
        childSessionsByParent: [SessionID: [SessionSummary]],
        visitedSessionIDs: Set<SessionID>
    ) -> AppShellNavigationNode {
        guard visitedSessionIDs.contains(session.id) == false else {
            return AppShellNavigationNode(
                id: "\(idPrefix).\(session.id.rawValue)",
                title: session.displayTitle,
                count: 1,
                sessionIDs: [session.id]
            )
        }

        let nextVisitedSessionIDs = visitedSessionIDs.union([session.id])
        let children = (childSessionsByParent[session.id] ?? []).map { childSession in
            threadNode(
                session: childSession,
                idPrefix: idPrefix,
                childSessionsByParent: childSessionsByParent,
                visitedSessionIDs: nextVisitedSessionIDs
            )
        }
        let sessionIDs = ([session.id] + children.flatMap(\.sessionIDs)).uniqueSessionIDsPreservingOrder()

        return AppShellNavigationNode(
            id: "\(idPrefix).\(session.id.rawValue)",
            title: session.displayTitle,
            count: sessionIDs.count,
            sessionIDs: sessionIDs,
            children: children
        )
    }

    private static func relationshipParentID(
        for session: SessionSummary,
        sessionIDs: Set<SessionID>
    ) -> SessionID? {
        let parentID = session.metadata.parentThreadID ?? session.metadata.forkedFromID
        guard let parentID,
              parentID != session.id,
              sessionIDs.contains(parentID)
        else {
            return nil
        }

        return parentID
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
    func uniqueSessionIDsPreservingOrder() -> [SessionID] {
        var seen: Set<SessionID> = []
        return filter { seen.insert($0).inserted }
    }

    func uniqueSortedByRawValue() -> [SessionID] {
        var seen: Set<SessionID> = []
        return filter { seen.insert($0).inserted }
            .sorted { $0.rawValue < $1.rawValue }
    }
}
