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
    let secondTranscriptURL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-04T06-00-00-test.jsonl")
    try FileManager.default.createDirectory(
        at: transcriptURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: secondTranscriptURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)
    try #"{"type":"session_meta"}"#.write(to: secondTranscriptURL, atomically: true, encoding: .utf8)

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
    #expect(source.counts == SessionSourceCounts(sessionBucketDirectoryCount: 2, transcriptFileCount: 2))
}

@Test("default Codex source discovery treats non-candidate JSONL as empty")
func defaultCodexSourceDiscoveryTreatsNonCandidateJSONLAsEmpty() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "non-candidate-empty")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    let sessionsRoot = homeDirectory
        .appending(path: ".codex", directoryHint: .isDirectory)
        .appending(path: "sessions", directoryHint: .isDirectory)
    let scratchJSONL = sessionsRoot.appending(path: "scratch.jsonl")
    let nonRolloutJSONL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "not-a-codex-rollout.jsonl")
    try FileManager.default.createDirectory(
        at: nonRolloutJSONL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"not":"a-codex-session"}"#.write(to: scratchJSONL, atomically: true, encoding: .utf8)
    try #"{"not":"a-codex-rollout"}"#.write(to: nonRolloutJSONL, atomically: true, encoding: .utf8)

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    let source = try #require(try adapter.discoverSources().first)

    #expect(source.availability == .available)
    #expect(source.diagnostic?.code == .codexSessionsRootEmpty)
    #expect(source.counts == .empty)
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
    #expect(source.isEnabled == true)
    #expect(source.diagnostic?.code == .codexSessionsRootMissing)
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

@Test("default Codex source discovery enumerates conservative candidate files with bounded metadata")
func defaultCodexSourceDiscoveryEnumeratesCandidateFiles() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "candidate-files")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    let sessionsRoot = homeDirectory
        .appending(path: ".codex", directoryHint: .isDirectory)
        .appending(path: "sessions", directoryHint: .isDirectory)
    let candidateURL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-04T10-00-00-test.jsonl")
    let unrelatedJSONL = sessionsRoot.appending(path: "scratch.jsonl")
    let unrelatedDateBucketJSONL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "not-a-codex-rollout.jsonl")
    let unrelatedText = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "notes.txt")
    try FileManager.default.createDirectory(
        at: candidateURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"type":"session_meta"}"#.write(to: candidateURL, atomically: true, encoding: .utf8)
    try #"{"not":"a-codex-session"}"#.write(to: unrelatedJSONL, atomically: true, encoding: .utf8)
    try #"{"not":"a-codex-rollout"}"#.write(to: unrelatedDateBucketJSONL, atomically: true, encoding: .utf8)
    try "notes".write(to: unrelatedText, atomically: true, encoding: .utf8)

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    let files = try adapter.enumerateCandidateFiles(sourceID: nil)

    let candidate = try #require(files.first)
    #expect(files.count == 1)
    #expect(candidate.sourceID == DefaultCodexSourceDiscoveryAdapter.sourceID)
    #expect(candidate.relativePath == "2026/06/04/rollout-2026-06-04T10-00-00-test.jsonl")
    #expect(candidate.absolutePath == candidateURL.standardizedFileURL.path)
    #expect(candidate.byteSize == Int64(#"{"type":"session_meta"}"#.utf8.count))
    #expect(candidate.modifiedAt != nil)
    #expect(candidate.confidence == .high)
    #expect(candidate.reason == "codex.sessions.date-bucket-jsonl")
    #expect(candidate.diagnostic == nil)
}

@Test("default Codex source discovery records unreadable candidate diagnostics and continues")
func defaultCodexSourceDiscoveryRecordsUnreadableCandidateDiagnosticsAndContinues() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "unreadable-candidates")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    let sessionsRoot = homeDirectory
        .appending(path: ".codex", directoryHint: .isDirectory)
        .appending(path: "sessions", directoryHint: .isDirectory)
    let readableURL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-04T10-00-00-readable.jsonl")
    let unreadableURL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-04T10-01-00-unreadable.jsonl")
    try FileManager.default.createDirectory(
        at: readableURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"type":"session_meta"}"#.write(to: readableURL, atomically: true, encoding: .utf8)
    try #"{"type":"session_meta"}"#.write(to: unreadableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadableURL.path)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: unreadableURL.path)
    }

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    let files = try adapter.enumerateCandidateFiles(sourceID: nil)

    #expect(files.map(\.relativePath) == [
        "2026/06/04/rollout-2026-06-04T10-00-00-readable.jsonl",
        "2026/06/04/rollout-2026-06-04T10-01-00-unreadable.jsonl",
    ])
    #expect(files.first?.diagnostic == nil)
    #expect(files.last?.diagnostic?.code == .codexCandidateFileUnreadable)
}

@Test("default Codex source discovery skips candidate symlinks that escape the source root")
func defaultCodexSourceDiscoverySkipsCandidateSymlinksThatEscapeSourceRoot() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "escaping-symlink")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    let sessionsRoot = homeDirectory
        .appending(path: ".codex", directoryHint: .isDirectory)
        .appending(path: "sessions", directoryHint: .isDirectory)
    let outsideRoot = fixtureRoot.url.appending(path: "outside", directoryHint: .isDirectory)
    let outsideFile = outsideRoot.appending(path: "outside.jsonl")
    let symlinkURL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-04T10-02-00-escape.jsonl")
    try FileManager.default.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
        at: symlinkURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"type":"session_meta"}"#.write(to: outsideFile, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(atPath: symlinkURL.path, withDestinationPath: outsideFile.path)

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    let files = try adapter.enumerateCandidateFiles(sourceID: nil)

    #expect(files.isEmpty)
}

@Test("default Codex source discovery records large candidate file metadata without parsing")
func defaultCodexSourceDiscoveryRecordsLargeCandidateFileMetadataWithoutParsing() throws {
    let fixtureRoot = try makeDiscoveryFixtureRoot(name: "large-candidate")
    defer {
        try? fixtureRoot.cleanup()
    }

    let homeDirectory = fixtureRoot.url.appending(path: "home", directoryHint: .isDirectory)
    let sessionsRoot = homeDirectory
        .appending(path: ".codex", directoryHint: .isDirectory)
        .appending(path: "sessions", directoryHint: .isDirectory)
    let candidateURL = sessionsRoot
        .appending(path: "2026/06/04", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-04T10-03-00-large.jsonl")
    try FileManager.default.createDirectory(
        at: candidateURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let largePayload = Data(repeating: 0x7B, count: 1_048_576)
    try largePayload.write(to: candidateURL)

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: homeDirectory)
    )

    let files = try adapter.enumerateCandidateFiles(sourceID: nil)

    let candidate = try #require(files.first)
    #expect(files.count == 1)
    #expect(candidate.relativePath == "2026/06/04/rollout-2026-06-04T10-03-00-large.jsonl")
    #expect(candidate.byteSize == 1_048_576)
    #expect(candidate.diagnostic == nil)
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
