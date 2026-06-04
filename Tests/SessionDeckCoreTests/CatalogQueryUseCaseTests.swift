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
