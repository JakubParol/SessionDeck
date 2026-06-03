import Foundation
import Testing

@Test("temp Codex store factory creates project and non-project session layouts")
func tempCodexStoreFactoryCreatesProjectAndNonProjectLayouts() throws {
    let fixture = try makeFactoryFixture(name: "layout")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }

    let primarySource = try fixture.store.source(label: "codex-cli", profile: "naomi")
    let appSource = try fixture.store.source(label: "codex app", profile: "default")

    let firstProject = try fixture.store.installProjectSession(
        .projectSession,
        source: primarySource,
        sessionID: "00000000-0000-4000-8000-000000000101",
        projectName: "AlphaProject",
        timestamp: "2026-01-02T03:04:05Z"
    )
    let secondProject = try fixture.store.installProjectSession(
        .unknownEvent,
        source: primarySource,
        sessionID: "00000000-0000-4000-8000-000000000102",
        projectName: "BetaProject",
        timestamp: "2026-01-02T03:04:06Z"
    )
    let nonProjectChat = try fixture.store.installNonProjectChat(
        .nonProjectChat,
        source: appSource,
        sessionID: "00000000-0000-4000-8000-000000000103",
        timestamp: "2026-01-03T00:00:00Z"
    )

    #expect(FileManager.default.fileExists(atPath: firstProject.url.path))
    #expect(FileManager.default.fileExists(atPath: secondProject.url.path))
    #expect(FileManager.default.fileExists(atPath: nonProjectChat.url.path))
    #expect(firstProject.url.path.contains("/sources/codex-cli/naomi/.codex/sessions/2026/01/02/"))
    #expect(nonProjectChat.url.path.contains("/sources/codex-app/default/.codex/sessions/2026/01/03/"))
    let firstProjectEvent = try sessionMetadataEvent(in: firstProject)
    let secondProjectPayload = try sessionMetadataPayload(in: secondProject)
    let nonProjectPayload = try sessionMetadataPayload(in: nonProjectChat)
    #expect(firstProjectEvent.timestamp == "2026-01-02T03:04:05Z")
    #expect(firstProjectEvent.payload["id"] as? String == "00000000-0000-4000-8000-000000000101")
    #expect(firstProjectEvent.payload["project"] as? String == "AlphaProject")
    #expect(firstProjectEvent.payload["source"] as? String == "codex-cli")
    #expect(secondProjectPayload["id"] as? String == "00000000-0000-4000-8000-000000000102")
    #expect(secondProjectPayload["project"] as? String == "BetaProject")
    #expect(nonProjectPayload["project"] is NSNull)
    #expect(nonProjectPayload["cwd"] is NSNull)
    #expect(fixture.store.sessionFiles.map(\.placement) == [
        .project("AlphaProject"),
        .project("BetaProject"),
        .nonProjectChat,
    ])
}

@Test("temp Codex store factory keeps missing metadata sessions visible")
func tempCodexStoreFactoryKeepsMissingMetadataSessionsVisible() throws {
    let fixture = try makeFactoryFixture(name: "missing-metadata")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }

    let source = try fixture.store.source(label: "codex-cli", profile: "missing")
    let missingMetadataSession = try fixture.store.installMissingMetadataSession(
        .missingMetadata,
        source: source,
        sessionID: "00000000-0000-4000-8000-000000000201",
        timestamp: "2026-01-04T00:00:00Z"
    )

    let content = try String(contentsOf: missingMetadataSession.url, encoding: .utf8)
    let payload = try sessionMetadataPayload(in: missingMetadataSession)
    #expect(FileManager.default.fileExists(atPath: missingMetadataSession.url.path))
    #expect(!content.contains("\"cwd\""))
    #expect(!content.contains("\"project\""))
    #expect(payload["id"] as? String == "00000000-0000-4000-8000-000000000201")
    #expect(payload["source"] as? String == "codex-cli")
    #expect(fixture.store.sessionFiles == [missingMetadataSession])
}

@Test("temp Codex store factory writes inline and checked-in fixture transcripts")
func tempCodexStoreFactoryWritesInlineAndCheckedInFixtureTranscripts() throws {
    let fixture = try makeFactoryFixture(name: "write")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }

    let source = try fixture.store.source(label: "codex-cli", profile: "writer")
    let fixtureSession = try fixture.store.installProjectSession(
        .projectSession,
        source: source,
        sessionID: "00000000-0000-4000-8000-000000000301",
        projectName: "FixtureProject",
        timestamp: "2026-01-05T00:00:00Z"
    )
    let inlineSession = try fixture.store.writeTranscript(
        "{\"type\":\"session_meta\",\"payload\":{\"id\":\"inline\"}}\n",
        source: source,
        sessionID: "inline-session",
        placement: .project("InlineProject"),
        timestamp: "2026-01-05T00:00:01Z"
    )

    let copiedContent = try String(contentsOf: fixtureSession.url, encoding: .utf8)
    let inlineContent = try String(contentsOf: inlineSession.url, encoding: .utf8)
    let copiedPayload = try sessionMetadataPayload(in: fixtureSession)
    #expect(copiedPayload["id"] as? String == "00000000-0000-4000-8000-000000000301")
    #expect(copiedPayload["project"] as? String == "FixtureProject")
    #expect(copiedContent.contains("Review the synthetic fixture state."))
    #expect(inlineContent.contains("\"id\":\"inline\""))
    #expect(inlineSession.url.lastPathComponent == "rollout-2026-01-05T00-00-01Z-inline-session.jsonl")
}

@Test("temp Codex store factory rejects writes outside generated root")
func tempCodexStoreFactoryRejectsWritesOutsideGeneratedRoot() throws {
    let fixture = try makeFactoryFixture(name: "unsafe")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }

    do {
        _ = try fixture.store.writeTranscript("unsafe", relativePath: "../outside.jsonl")
        Issue.record("Expected relative parent traversal to be rejected")
    } catch let error as TempCodexSessionStoreError {
        #expect(error == .pathEscapesTempRoot("../outside.jsonl"))
    }

    do {
        _ = try fixture.store.writeTranscript("unsafe", relativePath: "/tmp/outside.jsonl")
        Issue.record("Expected absolute destination to be rejected")
    } catch let error as TempCodexSessionStoreError {
        #expect(error == .pathEscapesTempRoot("/tmp/outside.jsonl"))
    }
}

@Test("temp Codex store factory rejects symlink redirected writes")
func tempCodexStoreFactoryRejectsSymlinkRedirectedWrites() throws {
    let fixture = try makeFactoryFixture(name: "symlink")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }
    let outsideDirectory = fixture.parentDirectory.appendingPathComponent("outside", isDirectory: true)
    let linkedDirectory = fixture.store.rootURL.appendingPathComponent("linked", isDirectory: true)

    try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: outsideDirectory)

    do {
        _ = try fixture.store.writeTranscript("unsafe", relativePath: "linked/session.jsonl")
        Issue.record("Expected symlink-redirected destination to be rejected")
    } catch let error as TempCodexSessionStoreError {
        #expect(error == .pathEscapesTempRoot(outsideDirectory.path))
    }
}

@Test("temp Codex store factory rejects symlink redirected source roots")
func tempCodexStoreFactoryRejectsSymlinkRedirectedSourceRoots() throws {
    let fixture = try makeFactoryFixture(name: "source-symlink")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }
    let sourcesDirectory = fixture.store.rootURL.appendingPathComponent("sources", isDirectory: true)
    let outsideDirectory = fixture.parentDirectory.appendingPathComponent("outside-source", isDirectory: true)
    let linkedSource = sourcesDirectory.appendingPathComponent("codex-cli", isDirectory: true)

    try FileManager.default.createDirectory(at: sourcesDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: outsideDirectory)

    do {
        _ = try fixture.store.source(label: "codex-cli", profile: "escaped")
        Issue.record("Expected symlink-redirected source root to be rejected")
    } catch let error as TempCodexSessionStoreError {
        #expect(error == .pathEscapesTempRoot(outsideDirectory.path))
    }
}

@Test("temp Codex store cleanup removes only generated root")
func tempCodexStoreCleanupRemovesOnlyGeneratedRoot() throws {
    let fixture = try makeFactoryFixture(name: "cleanup")
    let outsideFile = fixture.parentDirectory.appendingPathComponent("outside.txt", isDirectory: false)
    try "outside".write(to: outsideFile, atomically: true, encoding: .utf8)

    let source = try fixture.store.source(label: "codex-cli", profile: "cleanup")
    _ = try fixture.store.installProjectSession(
        .projectSession,
        source: source,
        sessionID: "cleanup-session",
        projectName: "CleanupProject"
    )

    #expect(FileManager.default.fileExists(atPath: fixture.store.rootURL.path))
    try fixture.store.cleanup()
    #expect(!FileManager.default.fileExists(atPath: fixture.store.rootURL.path))
    #expect(FileManager.default.fileExists(atPath: outsideFile.path))

    try fixture.cleanupParent()
}

private func makeFactoryFixture(name: String) throws -> TempCodexStoreFactoryTestFixture {
    let parentDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("SessionDeckTempCodexSessionStoreFactoryTests", isDirectory: true)
        .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    let pathGuard = FixturePathGuard(
        forbiddenHomeDirectories: [URL(fileURLWithPath: "/Users/jakubparol", isDirectory: true)]
    )
    let factory = TempCodexSessionStoreFactory(parentDirectory: parentDirectory, pathGuard: pathGuard)
    let store = try factory.makeStore(name: "store")

    return TempCodexStoreFactoryTestFixture(parentDirectory: parentDirectory, store: store)
}

private struct TempCodexStoreFactoryTestFixture {
    let parentDirectory: URL
    let store: TempCodexSessionStore

    func cleanupParent() throws {
        if FileManager.default.fileExists(atPath: parentDirectory.path) {
            try FileManager.default.removeItem(at: parentDirectory)
        }
    }
}

private func sessionMetadataEvent(in sessionFile: TempCodexSessionFile) throws -> (
    timestamp: String?,
    payload: [String: Any]
) {
    let content = try String(contentsOf: sessionFile.url, encoding: .utf8)
    let firstLine = try #require(content.split(separator: "\n").first)
    let data = Data(firstLine.utf8)
    let event = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let payload = try #require(event["payload"] as? [String: Any])
    return (event["timestamp"] as? String, payload)
}

private func sessionMetadataPayload(in sessionFile: TempCodexSessionFile) throws -> [String: Any] {
    try sessionMetadataEvent(in: sessionFile).payload
}
