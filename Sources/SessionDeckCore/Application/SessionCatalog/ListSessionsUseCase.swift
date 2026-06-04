public struct ListSessionsUseCase: Sendable {
    private let sessionCatalog: any SessionCatalogPort

    public init(sessionCatalog: any SessionCatalogPort) {
        self.sessionCatalog = sessionCatalog
    }

    public func listSessions(sourceID: SessionSourceID? = nil) throws -> [SessionSummary] {
        SessionCatalogOrdering.sort(try sessionCatalog.listSessions(sourceID: sourceID))
    }

    public func listSessions(scope: CatalogSessionScope) throws -> [SessionSummary] {
        let sessions: [SessionSummary]
        switch scope {
        case .all:
            sessions = try sessionCatalog.listSessions(sourceID: nil)
        case let .sessionIDs(sessionIDs):
            let selectedIDs = Set(sessionIDs)
            sessions = try sessionCatalog.listSessions(sourceID: nil).filter { selectedIDs.contains($0.id) }
        case let .source(sourceMetadata):
            sessions = try sessionCatalog.listSessions(sourceID: sourceMetadata.sourceID)
                .filter { $0.matches(sourceMetadata: sourceMetadata) }
        case let .profile(profileMetadata):
            sessions = try sessionCatalog.listSessions(sourceID: profileMetadata.sourceID)
                .filter { $0.matches(profileMetadata: profileMetadata) }
        }

        return SessionCatalogOrdering.sort(sessions)
    }
}

private extension SessionSummary {
    func matches(sourceMetadata: SourceProfileSourceNavigationMetadata) -> Bool {
        if sourceMetadata.isFallback {
            return fallbackReasons.contains(.unknownSource)
        }

        return sourceMetadata.sourceID == sourceID
    }

    func matches(profileMetadata: SourceProfileProfileNavigationMetadata) -> Bool {
        guard matchesSourceStableID(profileMetadata.sourceStableID),
              profileMetadata.isFallback == false else {
            return false
        }

        return sourceLabel.profileName == profileMetadata.displayName
            || metadata.agentProfileName == profileMetadata.displayName
    }

    func matchesSourceStableID(_ sourceStableID: String) -> Bool {
        "source.\(sourceID.rawValue)" == sourceStableID
    }
}
