import Testing
@testable import SessionDeckCore

@Test("source profile navigation fixture catalog covers required synthetic scenarios")
func sourceProfileNavigationFixtureCatalogCoversRequiredSyntheticScenarios() {
    let snapshot = SourceProfileNavigationFixtureCatalog.snapshot()
    let summary = AppShellNavigationSummary.make(snapshot: snapshot)
    let sourceIDs = Set(snapshot.sessions.map(\.sourceID.rawValue))
    let sourceDisplayNames = snapshot.sessions.map(\.sourceLabel.displayName)
    let profileNames = snapshot.sessions.compactMap(\.sourceLabel.profileName)

    #expect(snapshot.sessions.count == 5)
    #expect(sourceIDs == [
        SourceProfileNavigationFixtureCatalog.cliSourceID.rawValue,
        SourceProfileNavigationFixtureCatalog.appSourceID.rawValue,
        SourceProfileNavigationFixtureCatalog.automationSourceID.rawValue,
        SourceProfileNavigationFixtureCatalog.unknownSourceID.rawValue,
    ])
    #expect(sourceDisplayNames.filter { $0 == "Codex" }.count == 3)
    #expect(profileNames.contains("default"))
    #expect(profileNames.contains("viewer"))
    #expect(snapshot.sessions.contains { $0.fallbackReasons.contains(.unknownSource) })
    #expect(snapshot.sessions.allSatisfy { $0.sessionPath.hasPrefix("/tmp/sessiondeck-fixtures/") })
    #expect(summary.projectsNode.children.map(\.title).contains("SessionDeck"))
    #expect(summary.projectsNode.children.map(\.title).contains("CrackerAi"))
    #expect(summary.sourcesNode.children.map(\.id).contains("sources.unknown-source"))
}
