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

@Test("navigation tree groups unknown project fallbacks without hiding sessions")
func navigationTreeGroupsUnknownProjectFallbacksWithoutHidingSessions() throws {
    let sourceID = SessionSourceID(rawValue: "codex-fallbacks")
    let sourceLabel = CatalogSourceLabel(
        sourceID: sourceID.rawValue,
        displayName: "Codex",
        profileName: nil
    )
    let snapshot = navigationSnapshot(
        sessions: [
            navigationSession(
                id: "valid-project",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: CatalogProjectHint(
                    cwdPath: "/Users/kuba/Repos/SessionDeck",
                    displayName: "SessionDeck"
                ),
                profileName: "Naomi",
                lastActivity: 40
            ),
            navigationSession(
                id: "ambiguous-project",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: CatalogProjectHint(
                    cwdPath: "/Users/kuba/Repos/SessionDeck",
                    displayName: "SessionDeck"
                ),
                profileName: "Naomi",
                lastActivity: 30,
                fallbackReasons: [.ambiguousProject]
            ),
            navigationSession(
                id: "scratch-project",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: CatalogProjectHint(
                    cwdPath: "/tmp/sessiondeck-scratch",
                    displayName: "scratch"
                ),
                profileName: "Naomi",
                lastActivity: 20
            ),
            navigationSession(
                id: "plain-chat",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: .unavailable,
                profileName: "Naomi",
                lastActivity: 10
            ),
        ]
    )

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)
    let unknownProjectNode = try #require(
        summary.projectsNode.children.first { $0.id == "projects.unknown-project" }
    )

    #expect(summary.allChatsNode.count == 4)
    #expect(summary.projectsNode.count == 3)
    #expect(summary.nonProjectChatsNode.count == 1)
    #expect(summary.nonProjectChatsNode.sessionIDs.map(\.rawValue) == ["plain-chat"])
    #expect(summary.projectsNode.children.map(\.id) == [
        "projects.project./Users/kuba/Repos/SessionDeck",
        "projects.unknown-project",
    ])
    #expect(unknownProjectNode.title == "Unknown Project")
    #expect(unknownProjectNode.sessionIDs.map(\.rawValue) == [
        "ambiguous-project",
        "scratch-project",
    ])
    #expect(summary.diagnosticsNode.sessionIDs.map(\.rawValue) == ["ambiguous-project"])
}

@Test("navigation tree keeps duplicate project display names distinct")
func navigationTreeKeepsDuplicateProjectDisplayNamesDistinct() {
    let sourceID = SessionSourceID(rawValue: "codex-duplicates")
    let sourceLabel = CatalogSourceLabel(
        sourceID: sourceID.rawValue,
        displayName: "Codex",
        profileName: nil
    )
    let snapshot = navigationSnapshot(
        sessions: [
            navigationSession(
                id: "alpha-toolbox",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: CatalogProjectHint(cwdPath: "/Users/kuba/Repos/Alpha", displayName: "Toolbox"),
                profileName: "Naomi",
                lastActivity: 20
            ),
            navigationSession(
                id: "beta-toolbox",
                sourceID: sourceID,
                sourceLabel: sourceLabel,
                projectHint: CatalogProjectHint(cwdPath: "/Users/kuba/Repos/Beta", displayName: "Toolbox"),
                profileName: "Naomi",
                lastActivity: 10
            ),
        ]
    )

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)

    #expect(summary.projectsNode.children.map(\.id) == [
        "projects.project./Users/kuba/Repos/Alpha",
        "projects.project./Users/kuba/Repos/Beta",
    ])
    #expect(summary.projectsNode.children.map(\.title) == ["Toolbox", "Toolbox"])
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
    lastActivity: Int64,
    fallbackReasons: [CatalogSessionFallbackReason] = [],
    health: CatalogEntryHealth = CatalogEntryHealth(parseStatus: .complete)
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
        fallbackReasons: fallbackReasons,
        health: health
    )
}
