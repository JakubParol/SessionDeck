import Testing
@testable import SessionDeckCore

@Test("catalog summaries keep stable identity and bounded metadata")
func catalogSummaryKeepsStableIdentityAndBoundedMetadata() {
    let summary = makeCatalogSummary(
        id: "codex-stable-1",
        sourceID: "codex-default",
        sourceDisplayName: "Codex default",
        profileName: "default",
        title: "Implement catalog",
        projectName: "SessionDeck",
        cwdPath: "/tmp/SessionDeck",
        path: "/tmp/codex-stable-1.jsonl",
        lastActivity: 1_770_003_000,
        byteCount: 4096,
        modelName: "gpt-test",
        parseStatus: .complete
    )

    #expect(summary.id.rawValue == "codex-stable-1")
    #expect(summary.identity == CatalogSessionIdentity(rawValue: "codex-stable-1"))
    #expect(summary.sourceLabel.profileName == "default")
    #expect(summary.displayTitle == "Implement catalog")
    #expect(summary.sessionPath == "/tmp/codex-stable-1.jsonl")
    #expect(summary.fileSize.byteCount == 4096)
    #expect(summary.metadata.modelName == "gpt-test")
    #expect(summary.health.parseStatus == .complete)
}

@Test("catalog summaries expose explicit fallbacks for incomplete metadata")
func catalogSummaryUsesFallbacksForIncompleteMetadata() {
    let summary = makeCatalogSummary(
        id: "missing-meta",
        sourceID: "unknown-source",
        sourceDisplayName: "Unknown Source",
        profileName: nil,
        title: nil,
        projectName: nil,
        cwdPath: nil,
        path: "/tmp/missing-meta.jsonl",
        lastActivity: nil,
        byteCount: 0,
        modelName: nil,
        parseStatus: .missingMetadata
    )

    #expect(summary.displayTitle == "Session missing-meta")
    #expect(summary.projectDisplayName == "Non-project Chat")
    #expect(summary.projectHint.cwdPath == nil)
    #expect(summary.lastActivityDescription == "Unknown activity")
    #expect(summary.sourceLabel.displayName == "Unknown Source")
    #expect(summary.metadata.modelName == nil)
    #expect(summary.health.parseStatus == .missingMetadata)
}

@Test("catalog summaries can represent parse and index health states")
func catalogSummaryRepresentsParseAndIndexHealthStates() {
    let statuses: [CatalogParseStatus] = [
        .complete,
        .missingMetadata,
        .malformed(reason: "invalid jsonl line"),
        .unreadable(reason: "permission denied"),
    ]

    let summaries = statuses.enumerated().map { index, status in
        makeCatalogSummary(
            id: "health-\(index)",
            sourceID: "codex-default",
            sourceDisplayName: "Codex default",
            profileName: "default",
            title: "Health \(index)",
            projectName: "SessionDeck",
            cwdPath: "/tmp/SessionDeck",
            path: "/tmp/health-\(index).jsonl",
            lastActivity: Int64(index),
            byteCount: 128,
            modelName: nil,
            parseStatus: status
        )
    }

    #expect(summaries.map(\.health.parseStatus) == statuses)
    #expect(summaries.allSatisfy { $0.health.allowsListing })
}

@Test("catalog entry health exposes typed diagnostics for visible problem sessions")
func catalogEntryHealthExposesTypedDiagnostics() {
    let diagnostics = [
        CatalogEntryDiagnostic(
            code: .malformedJSONL,
            severity: .warning,
            message: "One transcript line could not be parsed."
        ),
        CatalogEntryDiagnostic(
            code: .boundedReadTruncated,
            severity: .warning,
            message: "Catalog metadata scan stopped at the configured byte limit."
        ),
    ]
    let health = CatalogEntryHealth(
        parseStatus: .malformed(reason: "Malformed JSONL inside bounded catalog scan."),
        diagnostics: diagnostics
    )

    #expect(health.diagnostics.map(\.code) == [.malformedJSONL, .boundedReadTruncated])
    #expect(health.diagnostics.allSatisfy { $0.severity == .warning })
    #expect(health.allowsListing)
}

@Test("catalog use case applies deterministic ordering")
func catalogUseCaseAppliesDeterministicOrdering() throws {
    let newer = makeCatalogSummary(id: "newer", title: "A", lastActivity: 300)
    let older = makeCatalogSummary(id: "older", title: "B", lastActivity: 100)
    let unknownA = makeCatalogSummary(id: "unknown-b", title: "B", lastActivity: nil)
    let unknownB = makeCatalogSummary(id: "unknown-a", title: "B", lastActivity: nil)
    let untitled = makeCatalogSummary(id: "untitled", title: nil, lastActivity: nil)
    let useCase = ListSessionsUseCase(
        sessionCatalog: FakeSessionCatalogPort(sessions: [unknownA, older, untitled, newer, unknownB])
    )

    let orderedIDs = try useCase.listSessions().map(\.id.rawValue)

    #expect(orderedIDs == ["newer", "older", "unknown-a", "unknown-b", "untitled"])
}

private func makeCatalogSummary(
    id: String,
    sourceID: String = "codex-default",
    sourceDisplayName: String = "Codex default",
    profileName: String? = "default",
    title: String? = "Synthetic Session",
    projectName: String? = "SessionDeck",
    cwdPath: String? = "/tmp/SessionDeck",
    path: String = "/tmp/synthetic.jsonl",
    lastActivity: Int64? = 1,
    byteCount: Int64 = 128,
    modelName: String? = nil,
    parseStatus: CatalogParseStatus = .complete
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
        projectHint: projectName.map {
            CatalogProjectHint(cwdPath: cwdPath, displayName: $0)
        } ?? .unavailable,
        sessionPath: path,
        activity: CatalogActivityTimestamps(
            createdAtEpochSeconds: nil,
            lastActivityEpochSeconds: lastActivity
        ),
        fileSize: CatalogFileSize(byteCount: byteCount),
        metadata: CatalogSessionMetadata(modelName: modelName, agentProfileName: profileName),
        health: CatalogEntryHealth(parseStatus: parseStatus)
    )
}
