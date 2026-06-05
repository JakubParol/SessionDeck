import Foundation

public enum SelectedSessionLiveRefreshPolicy {
    public static func shouldRefreshSelectedSession(
        _ selectedSession: SessionSummary,
        for request: LiveRefreshRequest
    ) -> Bool {
        switch request.scope {
        case .allSources:
            return true
        case let .source(sourceID):
            return sourceID == selectedSession.sourceID
        case let .session(sessionID, sourceID):
            return sessionID == selectedSession.id && sourceID == selectedSession.sourceID
        case let .path(path, sourceID):
            return sourceMatches(sourceID, selectedSession: selectedSession)
                && pathsMatch(path, selectedSession.sessionPath)
        }
    }

    private static func sourceMatches(
        _ sourceID: SessionSourceID?,
        selectedSession: SessionSummary
    ) -> Bool {
        guard let sourceID else {
            return true
        }

        return sourceID == selectedSession.sourceID
    }

    private static func pathsMatch(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path
            == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }
}
