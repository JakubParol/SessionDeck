import Testing
@testable import SessionDeckCore

@Test("catalog query request exposes typed MVP criteria")
func catalogQueryRequestExposesTypedMVPCriteria() {
    let request = CatalogQueryRequest(
        searchText: "  SessionDeck  ",
        project: .project(id: "project./repos/SessionDeck"),
        sourceID: SessionSourceID(rawValue: "codex-cli"),
        profile: CatalogProfileFilter(
            stableID: "source.codex-cli.profile.naomi",
            sourceID: SessionSourceID(rawValue: "codex-cli")
        ),
        parseStatuses: [.complete, .malformed],
        sort: .lastActivityDescending
    )

    #expect(request.searchText == "  SessionDeck  ")
    #expect(request.project == .project(id: "project./repos/SessionDeck"))
    #expect(request.sourceID == SessionSourceID(rawValue: "codex-cli"))
    #expect(request.profile?.stableID == "source.codex-cli.profile.naomi")
    #expect(request.parseStatuses == [.complete, .malformed])
    #expect(request.sort == .lastActivityDescending)
}

@Test("catalog summary carries lightweight preview metadata for search")
func catalogSummaryCarriesLightweightPreviewMetadataForSearch() {
    let summary = makeQueryCatalogSummary(
        id: "preview-search",
        title: "Catalog contract",
        previewText: "Preview mentions metadata search without loading transcript bodies."
    )

    #expect(summary.previewText == "Preview mentions metadata search without loading transcript bodies.")
}

@Test("catalog query use case searches lightweight metadata only")
func catalogQueryUseCaseSearchesLightweightMetadataOnly() throws {
    let titleMatch = makeQueryCatalogSummary(id: "title", title: "Implement Catalog Search")
    let previewMatch = makeQueryCatalogSummary(id: "preview", previewText: "Preview mentions metadata search.")
    let pathMatch = makeQueryCatalogSummary(id: "path", path: "/tmp/searchable-path.jsonl")
    let projectMatch = makeQueryCatalogSummary(id: "project", projectName: "SearchableProject")
    let sourceMatch = makeQueryCatalogSummary(id: "source", sourceDisplayName: "Searchable Source")
    let profileMatch = makeQueryCatalogSummary(id: "profile", profileName: "searchable-profile")
    let nonMatch = makeQueryCatalogSummary(id: "other", title: "Other Session")
    let useCase = QueryCatalogUseCase(
        sessionCatalog: FakeSessionCatalogPort(
            sessions: [nonMatch, profileMatch, titleMatch, sourceMatch, pathMatch, previewMatch, projectMatch]
        )
    )

    let results = try useCase.query(CatalogQueryRequest(searchText: "  SEARCHABLE  "))

    #expect(results.map(\.id.rawValue) == ["path", "profile", "project", "source"])
}

@Test("catalog query use case applies combined explicit filters")
func catalogQueryUseCaseAppliesCombinedExplicitFilters() throws {
    let matching = makeQueryCatalogSummary(
        id: "matching",
        sourceID: "codex-cli",
        profileName: "naomi",
        title: "Release notes",
        previewText: "Contains query needle",
        projectName: "SessionDeck",
        cwdPath: "/repos/SessionDeck",
        lastActivity: 300,
        parseStatus: .unreadable(reason: "permission denied")
    )
    let wrongProject = makeQueryCatalogSummary(
        id: "wrong-project",
        sourceID: "codex-cli",
        profileName: "naomi",
        previewText: "Contains query needle",
        projectName: "Other",
        cwdPath: "/repos/Other",
        lastActivity: 400,
        parseStatus: .unreadable(reason: "permission denied")
    )
    let wrongSource = makeQueryCatalogSummary(
        id: "wrong-source",
        sourceID: "codex-app",
        profileName: "naomi",
        previewText: "Contains query needle",
        projectName: "SessionDeck",
        cwdPath: "/repos/SessionDeck",
        lastActivity: 500,
        parseStatus: .unreadable(reason: "permission denied")
    )
    let wrongStatus = makeQueryCatalogSummary(
        id: "wrong-status",
        sourceID: "codex-cli",
        profileName: "naomi",
        previewText: "Contains query needle",
        projectName: "SessionDeck",
        cwdPath: "/repos/SessionDeck",
        lastActivity: 600,
        parseStatus: .complete
    )
    let useCase = QueryCatalogUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [wrongStatus, wrongSource, wrongProject, matching])
    )

    let results = try useCase.query(
        CatalogQueryRequest(
            searchText: "needle",
            project: .project(id: "project./repos/SessionDeck"),
            sourceID: SessionSourceID(rawValue: "codex-cli"),
            profile: CatalogProfileFilter(
                stableID: "source.codex-cli.profile.naomi",
                sourceID: SessionSourceID(rawValue: "codex-cli")
            ),
            parseStatuses: [.unreadable]
        )
    )

    #expect(results.map(\.id.rawValue) == ["matching"])
}

@Test("catalog query use case derives stable filter options")
func catalogQueryUseCaseDerivesStableFilterOptions() throws {
    let project = makeQueryCatalogSummary(
        id: "project",
        sourceID: "codex-cli",
        sourceDisplayName: "Codex CLI",
        profileName: "Naomi",
        projectName: "SessionDeck",
        cwdPath: "/repos/SessionDeck",
        parseStatus: .complete
    )
    let nonProject = makeQueryCatalogSummary(
        id: "non-project",
        sourceID: "codex-app",
        sourceDisplayName: "Codex App",
        profileName: nil,
        projectName: nil,
        cwdPath: nil,
        parseStatus: .missingMetadata
    )
    let unknownProject = makeQueryCatalogSummary(
        id: "unknown-project",
        sourceID: "broken-source",
        sourceDisplayName: "",
        profileName: nil,
        projectName: "Scratch",
        cwdPath: "/private/tmp/scratch",
        parseStatus: .complete,
        fallbackReasons: [.unknownSource]
    )
    let useCase = QueryCatalogUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [unknownProject, nonProject, project])
    )

    let options = try useCase.filterOptions()

    #expect(options.projectOptions.map(\.filter) == [
        .nonProject,
        .project(id: "project./repos/SessionDeck"),
        .unknownProject,
    ])
    #expect(options.sourceOptions.map(\.stableID) == [
        "source.codex-app",
        "source.codex-cli",
        SourceProfileNavigationPolicy.unknownSourceStableID,
    ])
    #expect(options.profileOptions.map(\.filter.stableID) == [
        "source.codex-app.profile.unknown-profile",
        "source.codex-cli.profile.naomi",
        "unknown-source.profile.unknown-profile",
    ])
    #expect(options.parseStatusOptions.map(\.filter) == [.complete, .missingMetadata])
}

@Test("catalog query use case keeps fallback sessions visible through fallback filters")
func catalogQueryUseCaseKeepsFallbackSessionsVisibleThroughFallbackFilters() throws {
    let nonProject = makeQueryCatalogSummary(
        id: "non-project",
        projectName: nil,
        cwdPath: nil,
        lastActivity: 200,
        parseStatus: .missingMetadata
    )
    let unknownProject = makeQueryCatalogSummary(
        id: "unknown-project",
        projectName: "Scratch",
        cwdPath: "/private/tmp/scratch",
        lastActivity: 300
    )
    let project = makeQueryCatalogSummary(id: "project", lastActivity: 400)
    let useCase = QueryCatalogUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [project, unknownProject, nonProject])
    )

    let nonProjectResults = try useCase.query(CatalogQueryRequest(project: .nonProject))
    let unknownProjectResults = try useCase.query(CatalogQueryRequest(project: .unknownProject))
    let unsupportedResults = try useCase.query(
        CatalogQueryRequest(project: .project(id: "project./missing"))
    )

    #expect(nonProjectResults.map(\.id.rawValue) == ["non-project"])
    #expect(unknownProjectResults.map(\.id.rawValue) == ["unknown-project"])
    #expect(unsupportedResults.isEmpty)
}

private func makeQueryCatalogSummary(
    id: String,
    sourceID: String = "codex-default",
    sourceDisplayName: String = "Codex default",
    profileName: String? = "default",
    title: String? = "Synthetic Session",
    previewText: String? = nil,
    projectName: String? = "SessionDeck",
    cwdPath: String? = "/tmp/SessionDeck",
    path: String = "/tmp/synthetic.jsonl",
    createdAt: Int64? = nil,
    lastActivity: Int64? = 1,
    byteCount: Int64 = 128,
    modelName: String? = nil,
    parseStatus: CatalogParseStatus = .complete,
    fallbackReasons: [CatalogSessionFallbackReason] = []
) -> SessionSummary {
    let sessionSourceID = SessionSourceID(rawValue: sourceID)
    return SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: sessionSourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID,
            displayName: sourceDisplayName,
            profileName: profileName
        ),
        title: title,
        previewText: previewText,
        projectHint: projectName.map {
            CatalogProjectHint(cwdPath: cwdPath, displayName: $0)
        } ?? .unavailable,
        sessionPath: path,
        activity: CatalogActivityTimestamps(
            createdAtEpochSeconds: createdAt,
            lastActivityEpochSeconds: lastActivity
        ),
        fileSize: CatalogFileSize(byteCount: byteCount),
        metadata: CatalogSessionMetadata(modelName: modelName, agentProfileName: profileName),
        fallbackReasons: fallbackReasons,
        health: CatalogEntryHealth(parseStatus: parseStatus)
    )
}
