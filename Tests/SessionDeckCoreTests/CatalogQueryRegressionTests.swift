import Testing
@testable import SessionDeckCore

@Test("catalog query searches each lightweight metadata field")
func catalogQuerySearchesEachLightweightMetadataField() throws {
    let sessions = [
        regressionCatalogSummary(id: "title", title: "Needle title"),
        regressionCatalogSummary(id: "fallback", title: nil, fallbackTitle: "Needle fallback"),
        regressionCatalogSummary(id: "preview", previewText: "Needle preview"),
        regressionCatalogSummary(id: "path", path: "/tmp/needle-path.jsonl"),
        regressionCatalogSummary(id: "source-id", sourceID: "needle-source"),
        regressionCatalogSummary(id: "source-label", sourceDisplayName: "Needle Source"),
        regressionCatalogSummary(id: "profile", profileName: "needle-profile"),
        regressionCatalogSummary(id: "project-path", cwdPath: "/repos/needle-project"),
        regressionCatalogSummary(id: "project-name", projectName: "Needle Project"),
        regressionCatalogSummary(id: "model", modelName: "needle-model"),
        regressionCatalogSummary(id: "other", title: "Other"),
    ]
    let useCase = QueryCatalogUseCase(sessionCatalog: FakeSessionCatalogPort(sessions: sessions))

    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle title")).map(\.id.rawValue) == ["title"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle fallback")).map(\.id.rawValue) == ["fallback"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle preview")).map(\.id.rawValue) == ["preview"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle-path")).map(\.id.rawValue) == ["path"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle-source")).map(\.id.rawValue) == ["source-id"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle source")).map(\.id.rawValue) == ["source-label"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle-profile")).map(\.id.rawValue) == ["profile"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle-project")).map(\.id.rawValue) == ["project-path"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle project")).map(\.id.rawValue) == ["project-name"])
    #expect(try useCase.query(CatalogQueryRequest(searchText: "needle-model")).map(\.id.rawValue) == ["model"])
}

@Test("catalog query default and cleared criteria return the full sorted snapshot")
func catalogQueryDefaultAndClearedCriteriaReturnFullSortedSnapshot() throws {
    let newer = regressionCatalogSummary(id: "newer", title: "A", lastActivity: 300)
    let older = regressionCatalogSummary(id: "older", title: "B", lastActivity: 100)
    let unknownA = regressionCatalogSummary(id: "unknown-b", title: "B", lastActivity: nil)
    let unknownB = regressionCatalogSummary(id: "unknown-a", title: "B", lastActivity: nil)
    let useCase = QueryCatalogUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [unknownA, older, newer, unknownB])
    )

    let defaultIDs = try useCase.query().map(\.id.rawValue)
    let clearedIDs = try useCase.query(CatalogQueryRequest()).map(\.id.rawValue)
    let repeatedIDs = try useCase.query(CatalogQueryRequest()).map(\.id.rawValue)

    #expect(defaultIDs == ["newer", "older", "unknown-a", "unknown-b"])
    #expect(clearedIDs == defaultIDs)
    #expect(repeatedIDs == defaultIDs)
}

@Test("catalog query filters individual source profile and parse status criteria")
func catalogQueryFiltersIndividualSourceProfileAndParseStatusCriteria() throws {
    let codexCLI = regressionCatalogSummary(
        id: "cli-naomi",
        sourceID: "codex-cli",
        profileName: "naomi",
        parseStatus: .complete
    )
    let codexApp = regressionCatalogSummary(
        id: "app-default",
        sourceID: "codex-app",
        profileName: "default",
        parseStatus: .missingMetadata
    )
    let unreadable = regressionCatalogSummary(
        id: "unreadable",
        sourceID: "codex-cli",
        profileName: "default",
        parseStatus: .unreadable(reason: "permission denied")
    )
    let useCase = QueryCatalogUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [unreadable, codexApp, codexCLI])
    )

    let sourceResults = try useCase.query(
        CatalogQueryRequest(sourceID: SessionSourceID(rawValue: "codex-app"))
    )
    let profileResults = try useCase.query(
        CatalogQueryRequest(
            profile: CatalogProfileFilter(
                stableID: "source.codex-cli.profile.naomi",
                sourceID: SessionSourceID(rawValue: "codex-cli")
            )
        )
    )
    let statusResults = try useCase.query(CatalogQueryRequest(parseStatuses: [.unreadable]))
    let unsupportedResults = try useCase.query(
        CatalogQueryRequest(
            profile: CatalogProfileFilter(
                stableID: "source.codex-cli.profile.missing",
                sourceID: SessionSourceID(rawValue: "codex-cli")
            )
        )
    )

    #expect(sourceResults.map(\.id.rawValue) == ["app-default"])
    #expect(profileResults.map(\.id.rawValue) == ["cli-naomi"])
    #expect(statusResults.map(\.id.rawValue) == ["unreadable"])
    #expect(unsupportedResults.isEmpty)
}

private func regressionCatalogSummary(
    id: String,
    sourceID: String = "codex-default",
    sourceDisplayName: String = "Codex default",
    profileName: String? = "default",
    title: String? = "Synthetic Session",
    fallbackTitle: String? = nil,
    previewText: String? = nil,
    projectName: String? = "SessionDeck",
    cwdPath: String? = "/tmp/SessionDeck",
    path: String = "/tmp/synthetic.jsonl",
    createdAt: Int64? = nil,
    lastActivity: Int64? = 1,
    modelName: String? = nil,
    parseStatus: CatalogParseStatus = .complete
) -> SessionSummary {
    SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: SessionSourceID(rawValue: sourceID),
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID,
            displayName: sourceDisplayName,
            profileName: profileName
        ),
        title: title,
        previewText: previewText,
        fallbackTitle: fallbackTitle,
        projectHint: projectName.map {
            CatalogProjectHint(cwdPath: cwdPath, displayName: $0)
        } ?? .unavailable,
        sessionPath: path,
        activity: CatalogActivityTimestamps(
            createdAtEpochSeconds: createdAt,
            lastActivityEpochSeconds: lastActivity
        ),
        fileSize: CatalogFileSize(byteCount: 128),
        metadata: CatalogSessionMetadata(modelName: modelName, agentProfileName: profileName),
        health: CatalogEntryHealth(parseStatus: parseStatus)
    )
}
