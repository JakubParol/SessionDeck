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
    let sourceID = defaultCatalogSourceID()
    let adapter = try makeCatalogAdapter(
        source: source,
        transcript: transcript,
        modifiedAt: Date(timeIntervalSince1970: 1_767_225_605),
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

@Test("Codex catalog adapter ignores byte-limit truncation after metadata")
func codexCatalogAdapterIgnoresByteLimitTruncationAfterMetadata() throws {
    let fixtureRoot = try makeCatalogFixtureRoot(name: "large-output")
    defer {
        try? fixtureRoot.cleanup()
    }
    let store = TempCodexSessionStore(tempRoot: fixtureRoot)
    let source = try store.source(label: "Codex default", profile: "default")
    let transcript = try store.writeTranscript(
        """
        {"timestamp":"2026-01-01T00:00:00Z","type":"session_meta","payload":{"id":"large-session","title":"Large Output Catalog","cwd":"/tmp/SessionDeck","project":"SessionDeck","source":"codex-cli"}}
        {"timestamp":"2026-01-01T00:00:01Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call-large","output":"\(String(repeating: "x", count: 4096))"}}

        """,
        source: source,
        sessionID: "large-session",
        placement: .project("SessionDeck"),
        timestamp: "2026-01-01T00:00:00Z"
    )
    let adapter = try makeCatalogAdapter(
        source: source,
        transcript: transcript,
        scanLimits: CodexCatalogScanLimits(maximumBytes: 256, maximumLines: 8)
    )

    let summary = try #require(try adapter.listSessions(sourceID: nil).first)

    #expect(summary.id == SessionID(rawValue: "large-session"))
    #expect(summary.displayTitle == "Large Output Catalog")
    #expect(summary.health.parseStatus == .complete)
    #expect(summary.displayTitle.contains(String(repeating: "x", count: 16)) == false)
}

@Test("Codex catalog adapter reports genuine malformed lines inside scan bounds")
func codexCatalogAdapterReportsMalformedLinesInsideScanBounds() throws {
    let fixtureRoot = try makeCatalogFixtureRoot(name: "malformed")
    defer {
        try? fixtureRoot.cleanup()
    }
    let store = TempCodexSessionStore(tempRoot: fixtureRoot)
    let source = try store.source(label: "Codex default", profile: "default")
    let transcript = try store.writeTranscript(
        """
        {"timestamp":"2026-01-01T00:00:00Z","type":"session_meta","payload":{"id":"malformed-session","title":"Malformed Catalog","cwd":"/tmp/SessionDeck","project":"SessionDeck","source":"codex-cli"}}
        {this line is genuinely malformed
        {"timestamp":"2026-01-01T00:00:02Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[]}}

        """,
        source: source,
        sessionID: "malformed-session",
        placement: .project("SessionDeck"),
        timestamp: "2026-01-01T00:00:00Z"
    )
    let adapter = try makeCatalogAdapter(source: source, transcript: transcript)

    let summary = try #require(try adapter.listSessions(sourceID: nil).first)

    #expect(summary.id == SessionID(rawValue: "malformed-session"))
    #expect(summary.health.parseStatus == .malformed(reason: "Encountered malformed JSONL while scanning bounded catalog metadata."))
    #expect(summary.health.allowsListing)
}

@Test("Codex catalog adapter reports exact-limit malformed final lines")
func codexCatalogAdapterReportsExactLimitMalformedFinalLines() throws {
    let fixtureRoot = try makeCatalogFixtureRoot(name: "exact-limit-malformed")
    defer {
        try? fixtureRoot.cleanup()
    }
    let store = TempCodexSessionStore(tempRoot: fixtureRoot)
    let source = try store.source(label: "Codex default", profile: "default")
    let content = """
    {"timestamp":"2026-01-01T00:00:00Z","type":"session_meta","payload":{"id":"exact-limit","title":"Exact Limit","cwd":"/tmp/SessionDeck","project":"SessionDeck","source":"codex-cli"}}
    {this final line is malformed
    """
    let transcript = try store.writeTranscript(
        content,
        source: source,
        sessionID: "exact-limit",
        placement: .project("SessionDeck"),
        timestamp: "2026-01-01T00:00:00Z"
    )
    let adapter = try makeCatalogAdapter(
        source: source,
        transcript: transcript,
        scanLimits: CodexCatalogScanLimits(maximumBytes: content.utf8.count, maximumLines: 8)
    )

    let summary = try #require(try adapter.listSessions(sourceID: nil).first)

    #expect(summary.health.parseStatus == .malformed(reason: "Encountered malformed JSONL while scanning bounded catalog metadata."))
}

@Test("Codex catalog adapter keeps missing-metadata sessions visible without mutating fixtures")
func codexCatalogAdapterKeepsMissingMetadataSessionsVisibleWithoutMutation() throws {
    let fixtureRoot = try makeCatalogFixtureRoot(name: "missing-metadata")
    defer {
        try? fixtureRoot.cleanup()
    }
    let store = TempCodexSessionStore(tempRoot: fixtureRoot)
    let source = try store.source(label: "Codex default", profile: "default")
    let transcript = try store.writeTranscript(
        """
        {"timestamp":"2026-01-01T00:03:00Z","type":"session_meta","payload":{"id":"missing-meta","title":"Missing Metadata Catalog","source":"codex-cli"}}
        {"timestamp":"2026-01-01T00:03:01Z","type":"synthetic_unknown_event","payload":{"note":"unknown events are tolerated"}}

        """,
        source: source,
        sessionID: "missing-meta",
        placement: .missingMetadata,
        timestamp: "2026-01-01T00:03:00Z"
    )
    let before = try String(contentsOf: transcript.url, encoding: .utf8)
    let adapter = try makeCatalogAdapter(source: source, transcript: transcript)

    let summary = try #require(try adapter.listSessions(sourceID: nil).first)
    let after = try String(contentsOf: transcript.url, encoding: .utf8)

    #expect(summary.id == SessionID(rawValue: "missing-meta"))
    #expect(summary.projectHint == .unavailable)
    #expect(summary.health.parseStatus == .missingMetadata)
    #expect(summary.activity.createdAtEpochSeconds == 1_767_225_780)
    #expect(after == before)
}

private func makeCatalogFixtureRoot(name: String) throws -> FixtureTempRoot {
    try FixtureTempRoot(
        parentDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionDeckCodexSessionCatalogAdapterTests", isDirectory: true),
        name: name,
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
}

private func makeCatalogAdapter(
    source: TempCodexSessionSource,
    transcript: TempCodexSessionFile,
    modifiedAt: Date? = nil,
    scanLimits: CodexCatalogScanLimits = CodexCatalogScanLimits()
) throws -> CodexSessionCatalogAdapter {
    let sourceID = defaultCatalogSourceID()
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
            files: [
                CandidateSessionFile(
                    sourceID: sourceID,
                    relativePath: transcript.url.lastPathComponent,
                    absolutePath: transcript.url.path,
                    byteSize: Int64((try String(contentsOf: transcript.url, encoding: .utf8)).utf8.count),
                    modifiedAt: modifiedAt,
                    confidence: .high,
                    reason: "test",
                    diagnostic: nil
                ),
            ]
        ),
        scanLimits: scanLimits
    )
}

private func defaultCatalogSourceID() -> SessionSourceID {
    SessionSourceID(rawValue: "codex-default")
}
