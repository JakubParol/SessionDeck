import Foundation
import Testing

@Test("generated transcript fixture uses explicit event count and temp store path")
func generatedTranscriptFixtureUsesExplicitEventCountAndTempStorePath() throws {
    let fixture = try makeGeneratedFixture(name: "large-transcript")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }
    let source = try fixture.store.source(label: "codex-cli", profile: "large")

    let sessionFile = try fixture.store.generateLargeProjectTranscript(
        source: source,
        sessionID: "large-session",
        projectName: "LargeProject",
        options: GeneratedCodexTranscriptOptions(eventCount: 8, toolOutputByteCount: 128)
    )

    let content = try String(contentsOf: sessionFile.url, encoding: .utf8)
    let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
    #expect(lines.count == 9)
    #expect(sessionFile.url.path.hasPrefix(fixture.store.rootURL.path))
    #expect(content.contains("\"project\":\"LargeProject\""))
    #expect(content.contains("\"call_id\":\"call-large-output\""))
}

@Test("large tool output event is deterministic and byte sized")
func largeToolOutputEventIsDeterministicAndByteSized() throws {
    let first = try GeneratedCodexTranscriptFixtures.largeToolOutputEvent(outputByteCount: 4096)
    let second = try GeneratedCodexTranscriptFixtures.largeToolOutputEvent(outputByteCount: 4096)

    #expect(first == second)
    let event = try jsonObject(from: first)
    let payload = try #require(event["payload"] as? [String: Any])
    let output = try #require(payload["output"] as? String)
    #expect(output.utf8.count == 4096)
    #expect(output.hasPrefix("0123456789abcdef"))
}

@Test("generated fixture cleanup removes generated large files")
func generatedFixtureCleanupRemovesGeneratedLargeFiles() throws {
    let fixture = try makeGeneratedFixture(name: "cleanup")
    let source = try fixture.store.source(label: "codex-cli", profile: "cleanup")
    let sessionFile = try fixture.store.generateLargeProjectTranscript(
        source: source,
        sessionID: "cleanup-large-session",
        projectName: "CleanupLargeProject",
        options: GeneratedCodexTranscriptOptions(eventCount: 3, toolOutputByteCount: 2048)
    )

    #expect(FileManager.default.fileExists(atPath: sessionFile.url.path))
    try fixture.store.cleanup()
    #expect(!FileManager.default.fileExists(atPath: sessionFile.url.path))

    try fixture.cleanupParent()
}

private func makeGeneratedFixture(name: String) throws -> GeneratedCodexFixtureTestFixture {
    let parentDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("SessionDeckGeneratedCodexTranscriptFixturesTests", isDirectory: true)
        .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    let pathGuard = FixturePathGuard(
        forbiddenHomeDirectories: [URL(fileURLWithPath: "/Users/jakubparol", isDirectory: true)]
    )
    let factory = TempCodexSessionStoreFactory(parentDirectory: parentDirectory, pathGuard: pathGuard)
    let store = try factory.makeStore(name: "store")

    return GeneratedCodexFixtureTestFixture(parentDirectory: parentDirectory, store: store)
}

private struct GeneratedCodexFixtureTestFixture {
    let parentDirectory: URL
    let store: TempCodexSessionStore

    func cleanupParent() throws {
        if FileManager.default.fileExists(atPath: parentDirectory.path) {
            try FileManager.default.removeItem(at: parentDirectory)
        }
    }
}

private func jsonObject(from line: String) throws -> [String: Any] {
    let data = Data(line.utf8)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
