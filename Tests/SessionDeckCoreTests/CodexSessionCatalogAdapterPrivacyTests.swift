import Foundation
import Testing
@testable import SessionDeckCore

@Test("Codex catalog adapter sanitizes permission denied candidate diagnostics")
func codexCatalogAdapterSanitizesPermissionDeniedCandidateDiagnostics() throws {
    let fixtureRoot = try makePrivacyCatalogFixtureRoot(name: "permission-denied-candidate")
    defer {
        try? fixtureRoot.cleanup()
    }
    let store = TempCodexSessionStore(tempRoot: fixtureRoot)
    let source = try store.source(label: "Codex default", profile: "default")
    let transcript = try store.writeTranscript(
        #"{"type":"session_meta","payload":{"title":"Do not leak this body"}}"#,
        source: source,
        sessionID: "permission-denied-candidate",
        placement: .project("SessionDeck"),
        timestamp: "2026-01-01T00:06:00Z"
    )
    let adapter = try makePrivacyCatalogAdapter(
        source: source,
        transcript: transcript,
        diagnostic: CandidateSessionFileDiagnostic(
            code: .codexCandidateFileUnreadable,
            severity: .warning,
            allowsDiscoveryToContinue: true,
            message: "Permission denied while reading /private/source/session.jsonl with token secret"
        )
    )

    let summary = try #require(try adapter.listSessions(sourceID: nil).first)
    let diagnostic = try #require(summary.health.diagnostics.first)

    #expect(summary.health.parseStatus == .unreadable(reason: "Candidate transcript file could not be read."))
    #expect(diagnostic.code == .permissionDenied)
    #expect(diagnostic.message.contains("/private") == false)
    #expect(diagnostic.message.localizedCaseInsensitiveContains("token") == false)
    #expect(diagnostic.message.localizedCaseInsensitiveContains("secret") == false)
    #expect(diagnostic.message.contains("Do not leak this body") == false)
}

private func makePrivacyCatalogFixtureRoot(name: String) throws -> FixtureTempRoot {
    try FixtureTempRoot(
        parentDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionDeckCodexSessionCatalogAdapterPrivacyTests", isDirectory: true),
        name: name,
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
}

private func makePrivacyCatalogAdapter(
    source: TempCodexSessionSource,
    transcript: TempCodexSessionFile,
    diagnostic: CandidateSessionFileDiagnostic
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
            files: [
                CandidateSessionFile(
                    sourceID: sourceID,
                    relativePath: transcript.url.lastPathComponent,
                    absolutePath: transcript.url.path,
                    byteSize: Int64((try String(contentsOf: transcript.url, encoding: .utf8)).utf8.count),
                    modifiedAt: nil,
                    confidence: .high,
                    reason: "test",
                    diagnostic: diagnostic
                ),
            ]
        )
    )
}
