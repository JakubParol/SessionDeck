import Testing
@testable import SessionDeckCore

@Test("project grouping resolves stable project groups from cwd metadata")
func projectGroupingResolvesStableProjectGroupsFromCWDMetadata() {
    let session = projectGroupingSession(
        id: "project-session",
        projectHint: CatalogProjectHint(
            cwdPath: "/Users/kuba/Repos/SessionDeck",
            displayName: "SessionDeck"
        )
    )

    let group = ProjectGroupingPolicy.resolve(session: session)

    #expect(group.kind == .project)
    #expect(group.id == "project./Users/kuba/Repos/SessionDeck")
    #expect(group.title == "SessionDeck")
    #expect(group.sessionIDs == [SessionID(rawValue: "project-session")])
}

@Test("project grouping keeps worktree paths as distinct deterministic projects")
func projectGroupingKeepsWorktreePathsAsDistinctDeterministicProjects() {
    let session = projectGroupingSession(
        id: "worktree-session",
        projectHint: CatalogProjectHint(
            cwdPath: "/Users/kuba/Repos/worktrees/SessionDeck-sdeck-67",
            displayName: "SessionDeck"
        )
    )

    let group = ProjectGroupingPolicy.resolve(session: session)

    #expect(group.kind == .project)
    #expect(group.id == "project./Users/kuba/Repos/worktrees/SessionDeck-sdeck-67")
    #expect(group.title == "SessionDeck")
}

@Test("project grouping sends missing cwd to non-project chats")
func projectGroupingSendsMissingCWDToNonProjectChats() {
    let session = projectGroupingSession(
        id: "non-project-chat",
        projectHint: .unavailable
    )

    let group = ProjectGroupingPolicy.resolve(session: session)

    #expect(group.kind == .nonProject)
    #expect(group.id == "non-project-chats")
    #expect(group.title == "Non-project Chats")
}

@Test("project grouping safely falls back for scratch and malformed metadata")
func projectGroupingSafelyFallsBackForScratchAndMalformedMetadata() {
    let scratchSession = projectGroupingSession(
        id: "scratch-session",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck-scratch", displayName: "scratch")
    )
    let malformedSession = projectGroupingSession(
        id: "malformed-session",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/project\u{0}", displayName: "Project"),
        health: CatalogEntryHealth(parseStatus: .malformed(reason: "cwd contained invalid data"))
    )

    let scratchGroup = ProjectGroupingPolicy.resolve(session: scratchSession)
    let malformedGroup = ProjectGroupingPolicy.resolve(session: malformedSession)

    #expect(scratchGroup.kind == .unknownProject)
    #expect(scratchGroup.id == "unknown-project")
    #expect(scratchGroup.title == "Unknown Project")
    #expect(malformedGroup.kind == .unknownProject)
    #expect(malformedGroup.id == "unknown-project")
    #expect(malformedGroup.title == "Unknown Project")
}

@Test("project grouping marks ambiguous metadata as unknown project")
func projectGroupingMarksAmbiguousMetadataAsUnknownProject() {
    let session = projectGroupingSession(
        id: "ambiguous-session",
        projectHint: CatalogProjectHint(
            cwdPath: "/Users/kuba/Repos/SessionDeck",
            displayName: "SessionDeck"
        ),
        fallbackReasons: [.ambiguousProject]
    )

    let group = ProjectGroupingPolicy.resolve(session: session)

    #expect(group.kind == .unknownProject)
    #expect(group.id == "unknown-project")
    #expect(group.title == "Unknown Project")
}

@Test("project grouping keeps duplicate display names distinct by cwd")
func projectGroupingKeepsDuplicateDisplayNamesDistinctByCWD() {
    let first = projectGroupingSession(
        id: "first-session",
        projectHint: CatalogProjectHint(cwdPath: "/Users/kuba/Repos/Alpha", displayName: "Toolbox")
    )
    let second = projectGroupingSession(
        id: "second-session",
        projectHint: CatalogProjectHint(cwdPath: "/Users/kuba/Repos/Beta", displayName: "Toolbox")
    )

    let firstGroup = ProjectGroupingPolicy.resolve(session: first)
    let secondGroup = ProjectGroupingPolicy.resolve(session: second)

    #expect(firstGroup.title == "Toolbox")
    #expect(secondGroup.title == "Toolbox")
    #expect(firstGroup.id == "project./Users/kuba/Repos/Alpha")
    #expect(secondGroup.id == "project./Users/kuba/Repos/Beta")
    #expect(firstGroup.id != secondGroup.id)
}

private func projectGroupingSession(
    id: String,
    projectHint: CatalogProjectHint,
    fallbackReasons: [CatalogSessionFallbackReason] = [],
    health: CatalogEntryHealth = CatalogEntryHealth(parseStatus: .complete)
) -> SessionSummary {
    let sourceID = SessionSourceID(rawValue: "codex")
    return SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex",
            profileName: nil
        ),
        title: "Session \(id)",
        projectHint: projectHint,
        sessionPath: "/tmp/sessiondeck/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: nil),
        fileSize: CatalogFileSize(byteCount: 128),
        fallbackReasons: fallbackReasons,
        health: health
    )
}
