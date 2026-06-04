import Foundation
import Testing
@testable import SessionDeckCore

@Test("Codex catalog adapter extracts bounded metadata from candidate session files")
func codexCatalogAdapterExtractsBoundedMetadataFromCandidateFiles() throws {
    let fixtureRoot = try makeCatalogFixtureRoot(name: "minimal")
    defer {
        try? fixtureRoot.cleanup()
    }
    let store = TempCodexSessionStore(tempRoot: fixtureRoot)
    let source = try store.source(label: "Codex default", profile: "default")
    let transcript = try store.writeTranscript(
        """
        {"timestamp":"2026-01-01T00:00:00Z","type":"session_meta","payload":{"id":"session-1","title":"Catalog Metadata","cwd":"/tmp/SessionDeck","project":"SessionDeck","source":"codex-cli"}}
        {"timestamp":"2026-01-01T00:00:05Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Do not leak this body."}]}}

        """,
        source: source,
        sessionID: "session-1",
        placement: .project("SessionDeck"),
        timestamp: "2026-01-01T00:00:00Z"
    )
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let adapter = CodexSessionCatalogAdapter(
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
            files: [
                CandidateSessionFile(
                    sourceID: sourceID,
                    relativePath: "2026/01/01/rollout-2026-01-01T00-00-00Z-session-1.jsonl",
                    absolutePath: transcript.url.path,
                    byteSize: Int64((try String(contentsOf: transcript.url, encoding: .utf8)).utf8.count),
                    modifiedAt: Date(timeIntervalSince1970: 1_767_225_605),
                    confidence: .high,
                    reason: "test",
                    diagnostic: nil
                ),
            ]
        ),
        scanLimits: CodexCatalogScanLimits(maximumBytes: 512, maximumLines: 8)
    )

    let sessions = try adapter.listSessions(sourceID: nil)

    let summary = try #require(sessions.first)
    #expect(sessions.count == 1)
    #expect(summary.id == SessionID(rawValue: "session-1"))
    #expect(summary.sourceID == sourceID)
    #expect(summary.sourceLabel.displayName == "Codex default")
    #expect(summary.title == "Catalog Metadata")
    #expect(summary.projectHint == CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"))
    #expect(summary.sessionPath == transcript.url.path)
    #expect(summary.fileSize.byteCount > 0)
    #expect(summary.activity.createdAtEpochSeconds == 1_767_225_600)
    #expect(summary.activity.lastActivityEpochSeconds == 1_767_225_605)
    #expect(summary.health.parseStatus == .complete)
}

private func makeCatalogFixtureRoot(name: String) throws -> FixtureTempRoot {
    try FixtureTempRoot(
        parentDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionDeckCodexSessionCatalogAdapterTests", isDirectory: true),
        name: name,
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
}
