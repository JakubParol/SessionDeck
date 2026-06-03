import Foundation
import Testing
@testable import SessionDeckCore

@Test("default Codex source discovery reports an available temp HOME sessions root")
func defaultCodexSourceDiscoveryReportsAvailableTempHomeRoot() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "available")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    let sessionsRoot = homeDirectory
        .appending(path: ".codex", directoryHint: .isDirectory)
        .appending(path: "sessions", directoryHint: .isDirectory)
    let transcriptURL = sessionsRoot
        .appending(path: "2026/06/03", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-03T06-00-00-test.jsonl")
    try FileManager.default.createDirectory(
        at: transcriptURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    let sources = try adapter.discoverSources()

    #expect(sources.count == 1)
    let source = try #require(sources.first)
    #expect(source.id == DefaultCodexSourceDiscoveryAdapter.sourceID)
    #expect(source.displayName == "Codex default")
    #expect(source.kind == .codex)
    #expect(source.locationDescription == sessionsRoot.standardizedFileURL.path)
    #expect(source.availability == .available)
    #expect(source.isEnabled == true)
    #expect(source.diagnostic == nil)
    #expect(source.counts == SessionSourceCounts(sessionDirectoryCount: 1, transcriptFileCount: 1))
}

@Test("default Codex source discovery reports a missing diagnostic without crashing")
func defaultCodexSourceDiscoveryReportsMissingTempHomeRoot() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "missing")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    let sources = try adapter.discoverSources()

    let source = try #require(sources.first)
    #expect(source.availability == .missing)
    #expect(source.isEnabled == false)
    #expect(source.diagnostic?.code == "codex.sessions_root_missing")
    #expect(source.locationDescription.hasPrefix(homeDirectory.path))
    #expect(source.locationDescription.contains(NSHomeDirectory()) == false)
    #expect(source.counts == .empty)
}

@Test("default Codex source discovery performs no source-root writes")
func defaultCodexSourceDiscoveryDoesNotMutateSourceRoot() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "read-only")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    let sessionsRoot = homeDirectory
        .appending(path: ".codex", directoryHint: .isDirectory)
        .appending(path: "sessions", directoryHint: .isDirectory)
    let transcriptURL = sessionsRoot
        .appending(path: "2026/06/03", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-03T06-00-00-read-only.jsonl")
    try FileManager.default.createDirectory(
        at: transcriptURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"type":"response_item"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)

    let before = try relativeDirectorySnapshot(at: sessionsRoot)
    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    _ = try adapter.discoverSources()

    let after = try relativeDirectorySnapshot(at: sessionsRoot)
    #expect(after == before)
}

private func makeDiscoveryFixtureRoot(name: String) throws -> FixtureTempRoot {
    try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-source-discovery-\(name)-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
}

private func relativeDirectorySnapshot(at root: URL) throws -> [String] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    let rootPath = root.standardizedFileURL.path
    var entries: [String] = []
    for case let itemURL as URL in enumerator {
        let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        let type = values.isDirectory == true ? "dir" : "file"
        let path = itemURL.standardizedFileURL.path
        entries.append("\(type):\(path.replacingOccurrences(of: "\(rootPath)/", with: ""))")
    }
    return entries.sorted()
}
