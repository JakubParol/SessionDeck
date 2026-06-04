import Foundation
import Testing
@testable import SessionDeckCore

@Test("Codex catalog adapter returns valid and diagnostic entries from mixed fixtures")
func codexCatalogAdapterReturnsValidAndDiagnosticEntriesFromMixedFixtures() throws {
    let fixtureRoot = try makeMixedCatalogFixtureRoot(name: "mixed-fixtures")
    defer {
        try? fixtureRoot.cleanup()
    }
    let store = TempCodexSessionStore(tempRoot: fixtureRoot)
    let source = try store.source(label: "Codex default", profile: "default")
    let valid = try store.installProjectSession(
        .projectSession,
        source: source,
        sessionID: "valid-session",
        projectName: "SessionDeck",
        timestamp: "2026-01-01T00:06:00Z"
    )
    let malformed = try store.installProjectSession(
        .malformedLine,
        source: source,
        sessionID: "malformed-session",
        projectName: "SessionDeck",
        timestamp: "2026-01-01T00:07:00Z"
    )
    let unknown = try store.installProjectSession(
        .unknownEvent,
        source: source,
        sessionID: "unknown-session",
        projectName: "SessionDeck",
        timestamp: "2026-01-01T00:08:00Z"
    )
    let missingMetadata = try store.installMissingMetadataSession(
        .missingMetadata,
        source: source,
        sessionID: "missing-metadata-session",
        timestamp: "2026-01-01T00:09:00Z"
    )
    let adapter = try makeMixedCatalogAdapter(
        source: source,
        transcripts: [valid, malformed, unknown, missingMetadata]
    )

    let summariesByID = Dictionary(uniqueKeysWithValues: try adapter.listSessions(sourceID: nil).map { ($0.id.rawValue, $0) })

    #expect(Set(summariesByID.keys) == [
        "valid-session",
        "malformed-session",
        "unknown-session",
        "missing-metadata-session",
    ])
    #expect(try #require(summariesByID["valid-session"]).health.diagnostics.isEmpty)
    #expect(try diagnosticCodes(in: #require(summariesByID["malformed-session"])) == [.malformedJSONL])
    #expect(try diagnosticCodes(in: #require(summariesByID["unknown-session"])) == [.unknownEventShape])
    #expect(try diagnosticCodes(in: #require(summariesByID["missing-metadata-session"])) == [.missingMetadata])
    #expect(summariesByID.values.allSatisfy { $0.health.allowsListing })
}

private func makeMixedCatalogFixtureRoot(name: String) throws -> FixtureTempRoot {
    try FixtureTempRoot(
        parentDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionDeckCodexSessionCatalogAdapterMixedFixtureTests", isDirectory: true),
        name: name,
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
}

private func makeMixedCatalogAdapter(
    source: TempCodexSessionSource,
    transcripts: [TempCodexSessionFile]
) throws -> CodexSessionCatalogAdapter {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    return CodexSessionCatalogAdapter(
        sourceDiscovery: FakeSourceDiscoveryPort(
            sources: [
                SessionSourceSummary(
                    id: sourceID,
                    displayName: "Codex default",
                    kind: .codex,
                    locationDescription: source.sessionsRootURL.path,
                    isEnabled: true
                ),
            ]
        ),
        candidateFileEnumeration: FakeCandidateSessionFileEnumerationPort(
            files: try transcripts.map { transcript in
                CandidateSessionFile(
                    sourceID: sourceID,
                    relativePath: transcript.url.lastPathComponent,
                    absolutePath: transcript.url.path,
                    byteSize: Int64((try String(contentsOf: transcript.url, encoding: .utf8)).utf8.count),
                    modifiedAt: nil,
                    confidence: .high,
                    reason: "test",
                    diagnostic: nil
                )
            }
        )
    )
}

private func diagnosticCodes(in summary: SessionSummary) -> [CatalogEntryDiagnosticCode] {
    summary.health.diagnostics.map(\.code)
}
