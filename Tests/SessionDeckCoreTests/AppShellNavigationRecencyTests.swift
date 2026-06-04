import Foundation
import Testing
@testable import SessionDeckCore

@Test("navigation tree orders groups by newest child session")
func navigationTreeOrdersGroupsByNewestChildSession() {
    let olderSourceID = SessionSourceID(rawValue: "older-source")
    let newerSourceID = SessionSourceID(rawValue: "newer-source")
    let snapshot = recencySnapshot(
        sessions: [
            recencySession(
                id: "alpha-older",
                sourceID: olderSourceID,
                sourceLabel: CatalogSourceLabel(
                    sourceID: olderSourceID.rawValue,
                    displayName: "Alpha Source",
                    profileName: "Alpha Profile"
                ),
                projectHint: CatalogProjectHint(cwdPath: "/tmp/work/Alpha", displayName: "Alpha"),
                profileName: "Alpha Profile",
                lastActivity: 10
            ),
            recencySession(
                id: "beta-newer-profile",
                sourceID: newerSourceID,
                sourceLabel: CatalogSourceLabel(
                    sourceID: newerSourceID.rawValue,
                    displayName: "Beta Source",
                    profileName: "Beta Profile"
                ),
                projectHint: CatalogProjectHint(cwdPath: "/tmp/work/Beta", displayName: "Beta"),
                profileName: "Beta Profile",
                lastActivity: 50
            ),
            recencySession(
                id: "beta-older-profile",
                sourceID: newerSourceID,
                sourceLabel: CatalogSourceLabel(
                    sourceID: newerSourceID.rawValue,
                    displayName: "Beta Source",
                    profileName: "Alpha Profile"
                ),
                projectHint: CatalogProjectHint(cwdPath: "/tmp/work/Beta", displayName: "Beta"),
                profileName: "Alpha Profile",
                lastActivity: 20
            ),
        ]
    )

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)
    let betaSourceNode = summary.sourcesNode.children[0]

    #expect(summary.projectsNode.children.map(\.id) == [
        "projects.project./tmp/work/Beta",
        "projects.project./tmp/work/Alpha",
    ])
    #expect(summary.sourcesNode.children.map(\.id) == [
        "sources.source.newer-source",
        "sources.source.older-source",
    ])
    #expect(betaSourceNode.children.map(\.id) == [
        "sources.source.newer-source.profile.beta-profile",
        "sources.source.newer-source.profile.alpha-profile",
    ])
}

@Test("navigation tree bounds recently active sessions")
func navigationTreeBoundsRecentlyActiveSessions() {
    let sourceID = SessionSourceID(rawValue: "bounded-source")
    let sourceLabel = CatalogSourceLabel(
        sourceID: sourceID.rawValue,
        displayName: "Codex",
        profileName: nil
    )
    let sessions = (1...12).map { index in
        recencySession(
            id: "session-\(index)",
            sourceID: sourceID,
            sourceLabel: sourceLabel,
            projectHint: .unavailable,
            profileName: nil,
            lastActivity: Int64(index)
        )
    }
    let snapshot = recencySnapshot(sessions: sessions)

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)

    #expect(summary.recentlyActiveNode.count == 10)
    #expect(summary.recentlyActiveNode.sessionIDs.map(\.rawValue) == [
        "session-12",
        "session-11",
        "session-10",
        "session-9",
        "session-8",
        "session-7",
        "session-6",
        "session-5",
        "session-4",
        "session-3",
    ])
}

private func recencySnapshot(sessions: [SessionSummary]) -> CatalogSnapshot {
    CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_300_300),
        sources: [],
        sessions: sessions
    )
}

private func recencySession(
    id: String,
    sourceID: SessionSourceID,
    sourceLabel: CatalogSourceLabel,
    projectHint: CatalogProjectHint,
    profileName: String?,
    lastActivity: Int64
) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: sourceID,
        sourceLabel: sourceLabel,
        title: "Session \(id)",
        projectHint: projectHint,
        sessionPath: "/tmp/sessiondeck/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: lastActivity),
        fileSize: CatalogFileSize(byteCount: 128),
        metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: profileName),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
