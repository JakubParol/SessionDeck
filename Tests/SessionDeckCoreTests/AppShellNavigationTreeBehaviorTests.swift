import Foundation
import Testing
@testable import SessionDeckCore

@Test("navigation tree keeps stable group identifiers across refresh order changes")
func navigationTreeKeepsStableGroupIdentifiersAcrossRefreshOrderChanges() {
    let sourceID = SessionSourceID(rawValue: "codex-stable")
    let sourceLabel = CatalogSourceLabel(
        sourceID: sourceID.rawValue,
        displayName: "Codex",
        profileName: nil
    )
    let alphaProject = CatalogProjectHint(cwdPath: "/tmp/work/Alpha", displayName: "Alpha")
    let betaProject = CatalogProjectHint(cwdPath: "/tmp/work/Beta", displayName: "Beta")
    let firstSnapshot = navigationSnapshot(
        sessions: [
            navigationSession(
                id: "alpha-older",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: alphaProject,
                profileName: "Naomi",
                lastActivity: 10
            ),
            navigationSession(
                id: "beta-newer",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: betaProject,
                profileName: "Naomi",
                lastActivity: 20
            ),
        ]
    )
    let refreshedSnapshot = navigationSnapshot(
        sessions: [
            navigationSession(
                id: "beta-newer",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: betaProject,
                profileName: "Naomi",
                lastActivity: 20
            ),
            navigationSession(
                id: "alpha-older",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: alphaProject,
                profileName: "Naomi",
                lastActivity: 10
            ),
        ]
    )

    let firstSummary = AppShellNavigationSummary.make(snapshot: firstSnapshot)
    let refreshedSummary = AppShellNavigationSummary.make(snapshot: refreshedSnapshot)

    #expect(firstSummary.sectionNodes.map(\.id) == refreshedSummary.sectionNodes.map(\.id))
    #expect(firstSummary.projectsNode.children.map(\.id) == refreshedSummary.projectsNode.children.map(\.id))
    #expect(firstSummary.sourcesNode.children.map(\.id) == refreshedSummary.sourcesNode.children.map(\.id))
    #expect(refreshedSummary.recentlyActiveNode.sessionIDs.map(\.rawValue) == ["beta-newer", "alpha-older"])
}

private func navigationSnapshot(sessions: [SessionSummary]) -> CatalogSnapshot {
    CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_300_300),
        sources: [],
        sessions: sessions
    )
}

private func navigationSession(
    id: String,
    sourceID: SessionSourceID,
    sourceLabel: CatalogSourceLabel,
    projectHint: CatalogProjectHint,
    profileName: String,
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
