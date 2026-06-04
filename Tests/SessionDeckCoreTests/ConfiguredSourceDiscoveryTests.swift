import Foundation
import Testing
@testable import SessionDeckCore

@Test("configured source discovery returns metadata for each enabled temp root")
func configuredSourceDiscoveryReturnsMetadataForEachEnabledTempRoot() throws {
    let fixtureRoot = try makeConfiguredDiscoveryFixtureRoot(name: "metadata")
    defer {
        try? fixtureRoot.cleanup()
    }

    let firstRoot = fixtureRoot.url
        .appending(path: "sources/primary/.codex/sessions", directoryHint: .isDirectory)
    let secondRoot = fixtureRoot.url
        .appending(path: "sources/secondary/.codex/sessions", directoryHint: .isDirectory)
    try installTranscript(at: firstRoot, day: "03", name: "primary")
    try installTranscript(at: secondRoot, day: "04", name: "secondary")

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-primary"),
                displayName: "Codex primary",
                kind: .codex,
                rootPath: firstRoot.path,
                isEnabled: true
            ),
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-secondary"),
                displayName: "Codex secondary",
                kind: .codex,
                rootPath: secondRoot.path,
                isEnabled: true
            ),
        ]
    )

    let sources = try adapter.discoverSources()

    #expect(sources.map(\.id.rawValue) == ["codex-primary", "codex-secondary"])
    #expect(sources.map(\.displayName) == ["Codex primary", "Codex secondary"])
    #expect(sources.map(\.kind) == [.codex, .codex])
    #expect(sources.map(\.locationDescription) == [
        firstRoot.standardizedFileURL.path,
        secondRoot.standardizedFileURL.path,
    ])
    #expect(sources.allSatisfy { $0.isEnabled })
    #expect(sources.allSatisfy { $0.availability == .available })
    #expect(sources.map(\.counts) == [
        SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1),
        SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1),
    ])
}

@Test("configured source discovery reports duplicate equivalent paths as non-fatal diagnostics")
func configuredSourceDiscoveryReportsDuplicateEquivalentPaths() throws {
    let fixtureRoot = try makeConfiguredDiscoveryFixtureRoot(name: "duplicates")
    defer {
        try? fixtureRoot.cleanup()
    }

    let sessionsRoot = fixtureRoot.url
        .appending(path: "sources/primary/.codex/sessions", directoryHint: .isDirectory)
    let equivalentRoot = URL(fileURLWithPath: "\(sessionsRoot.path)/../sessions", isDirectory: true)
    try installTranscript(at: sessionsRoot, day: "05", name: "duplicate")

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-primary"),
                displayName: "Codex primary",
                kind: .codex,
                rootPath: sessionsRoot.path,
                isEnabled: true
            ),
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-duplicate"),
                displayName: "Codex duplicate",
                kind: .codex,
                rootPath: equivalentRoot.path,
                isEnabled: true
            ),
        ]
    )

    let sources = try adapter.discoverSources()

    #expect(sources.count == 2)
    let primary = try #require(sources.first)
    let duplicate = try #require(sources.last)
    #expect(primary.availability == .available)
    #expect(primary.counts == SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1))
    #expect(duplicate.id.rawValue == "codex-duplicate")
    #expect(duplicate.availability == .duplicate)
    #expect(duplicate.isEnabled == true)
    #expect(duplicate.locationDescription == sessionsRoot.standardizedFileURL.path)
    #expect(duplicate.diagnostic?.code == .sourceRootDuplicate)
    #expect(duplicate.counts == .empty)
}

@Test("configured source discovery suppresses candidate files when duplicate source is requested directly")
func configuredSourceDiscoverySuppressesCandidateFilesWhenDuplicateSourceIsRequestedDirectly() throws {
    let fixtureRoot = try makeConfiguredDiscoveryFixtureRoot(name: "duplicate-candidate-filter")
    defer {
        try? fixtureRoot.cleanup()
    }

    let sessionsRoot = fixtureRoot.url
        .appending(path: "sources/primary/.codex/sessions", directoryHint: .isDirectory)
    let equivalentRoot = URL(fileURLWithPath: "\(sessionsRoot.path)/../sessions", isDirectory: true)
    try installTranscript(at: sessionsRoot, day: "11", name: "duplicate-filter")

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-primary"),
                displayName: "Codex primary",
                kind: .codex,
                rootPath: sessionsRoot.path,
                isEnabled: true
            ),
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-duplicate"),
                displayName: "Codex duplicate",
                kind: .codex,
                rootPath: equivalentRoot.path,
                isEnabled: true
            ),
        ]
    )

    let files = try adapter.enumerateCandidateFiles(sourceID: SessionSourceID(rawValue: "codex-duplicate"))

    #expect(files.isEmpty)
}

@Test("configured source discovery reports symlink-equivalent paths as duplicates")
func configuredSourceDiscoveryReportsSymlinkEquivalentPathsAsDuplicates() throws {
    let fixtureRoot = try makeConfiguredDiscoveryFixtureRoot(name: "symlink-duplicates")
    defer {
        try? fixtureRoot.cleanup()
    }

    let sessionsRoot = fixtureRoot.url
        .appending(path: "sources/primary/.codex/sessions", directoryHint: .isDirectory)
    let symlinkRoot = fixtureRoot.url
        .appending(path: "sources/symlink-sessions", directoryHint: .isDirectory)
    try installTranscript(at: sessionsRoot, day: "08", name: "symlink")
    try FileManager.default.createDirectory(
        at: symlinkRoot.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.createSymbolicLink(
        atPath: symlinkRoot.path,
        withDestinationPath: sessionsRoot.path
    )

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-primary"),
                displayName: "Codex primary",
                kind: .codex,
                rootPath: sessionsRoot.path,
                isEnabled: true
            ),
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-symlink"),
                displayName: "Codex symlink",
                kind: .codex,
                rootPath: symlinkRoot.path,
                isEnabled: true
            ),
        ]
    )

    let sources = try adapter.discoverSources()

    let duplicate = try #require(sources.last)
    #expect(duplicate.availability == .duplicate)
    #expect(duplicate.diagnostic?.code == .sourceRootDuplicate)
    #expect(duplicate.locationDescription == symlinkRoot.standardizedFileURL.path)
}

@Test("configured source discovery reports unsupported kinds and continues with supported sources")
func configuredSourceDiscoveryReportsUnsupportedKindsAndContinues() throws {
    let fixtureRoot = try makeConfiguredDiscoveryFixtureRoot(name: "unsupported")
    defer {
        try? fixtureRoot.cleanup()
    }

    let unsupportedRoot = fixtureRoot.url
        .appending(path: "sources/unsupported", directoryHint: .isDirectory)
    let codexRoot = fixtureRoot.url
        .appending(path: "sources/codex/.codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: unsupportedRoot, withIntermediateDirectories: true)
    try installTranscript(at: codexRoot, day: "06", name: "supported")

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "generic-local"),
                displayName: "Generic local root",
                kind: .other("generic-local"),
                rootPath: unsupportedRoot.path,
                isEnabled: true
            ),
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-supported"),
                displayName: "Codex supported",
                kind: .codex,
                rootPath: codexRoot.path,
                isEnabled: true
            ),
        ]
    )

    let sources = try adapter.discoverSources()

    #expect(sources.count == 2)
    let unsupported = try #require(sources.first)
    let supported = try #require(sources.last)
    #expect(unsupported.availability == .unsupported)
    #expect(unsupported.isEnabled == true)
    #expect(unsupported.diagnostic?.code == .sourceKindUnsupported)
    #expect(unsupported.counts == .empty)
    #expect(supported.id.rawValue == "codex-supported")
    #expect(supported.availability == .available)
    #expect(supported.counts == SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1))
}

@Test("configured source discovery reports disabled roots without inspecting them")
func configuredSourceDiscoveryReportsDisabledRootsWithoutInspectingThem() throws {
    let fixtureRoot = try makeConfiguredDiscoveryFixtureRoot(name: "disabled")
    defer {
        try? fixtureRoot.cleanup()
    }

    let disabledRoot = fixtureRoot.url
        .appending(path: "sources/disabled/.codex/sessions", directoryHint: .isDirectory)
    try installTranscript(at: disabledRoot, day: "07", name: "disabled")

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-disabled"),
                displayName: "Codex disabled",
                kind: .codex,
                rootPath: disabledRoot.path,
                isEnabled: false
            ),
        ]
    )

    let sources = try adapter.discoverSources()

    let disabled = try #require(sources.first)
    #expect(disabled.id.rawValue == "codex-disabled")
    #expect(disabled.availability == .disabled)
    #expect(disabled.isEnabled == false)
    #expect(disabled.diagnostic?.code == .sourceRootDisabled)
    #expect(disabled.counts == .empty)
}

@Test("configured source discovery reports permission denied roots distinctly")
func configuredSourceDiscoveryReportsPermissionDeniedRootsDistinctly() throws {
    let adapter = DefaultCodexSourceDiscoveryAdapter(
        fileSystem: FakeCodexSourceFileSystem(
            directoryExists: true,
            isReadableDirectory: false,
            countsResult: .success(SessionSourceCounts(sessionBucketDirectoryCount: 0, transcriptFileCount: 0))
        ),
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-denied"),
                displayName: "Codex denied",
                kind: .codex,
                rootPath: "/tmp/sessiondeck-denied/.codex/sessions",
                isEnabled: true
            ),
        ]
    )

    let source = try #require(try adapter.discoverSources().first)

    #expect(source.availability == .inaccessible)
    #expect(source.isEnabled == true)
    #expect(source.diagnostic?.code == .codexSessionsRootPermissionDenied)
    #expect(source.diagnostic?.severity == .error)
    #expect(source.diagnostic?.allowsDiscoveryToContinue == true)
    #expect(source.counts == .empty)
}

@Test("configured source discovery reports unreadable roots distinctly from permission denied")
func configuredSourceDiscoveryReportsUnreadableRootsDistinctly() throws {
    let adapter = DefaultCodexSourceDiscoveryAdapter(
        fileSystem: FakeCodexSourceFileSystem(
            directoryExists: true,
            isReadableDirectory: true,
            countsResult: .failure(FakeCodexSourceFileSystemError.unreadableDirectory)
        ),
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-unreadable"),
                displayName: "Codex unreadable",
                kind: .codex,
                rootPath: "/tmp/sessiondeck-unreadable/.codex/sessions",
                isEnabled: true
            ),
        ]
    )

    let source = try #require(try adapter.discoverSources().first)

    #expect(source.availability == .inaccessible)
    #expect(source.isEnabled == true)
    #expect(source.diagnostic?.code == .codexSessionsRootUnreadable)
    #expect(source.diagnostic?.severity == .error)
    #expect(source.diagnostic?.allowsDiscoveryToContinue == true)
    #expect(source.counts == .empty)
}

@Test("configured source discovery reports empty readable roots as available")
func configuredSourceDiscoveryReportsEmptyReadableRootsAsAvailable() throws {
    let adapter = DefaultCodexSourceDiscoveryAdapter(
        fileSystem: FakeCodexSourceFileSystem(
            directoryExists: true,
            isReadableDirectory: true,
            countsResult: .success(.empty)
        ),
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-empty"),
                displayName: "Codex empty",
                kind: .codex,
                rootPath: "/tmp/sessiondeck-empty/.codex/sessions",
                isEnabled: true
            ),
        ]
    )

    let source = try #require(try adapter.discoverSources().first)

    #expect(source.availability == .available)
    #expect(source.isEnabled == true)
    #expect(source.diagnostic?.code == .codexSessionsRootEmpty)
    #expect(source.diagnostic?.severity == .info)
    #expect(source.diagnostic?.allowsDiscoveryToContinue == true)
    #expect(source.counts == .empty)
}

@Test("configured source discovery enumerates candidate files for a requested source only")
func configuredSourceDiscoveryEnumeratesCandidateFilesForRequestedSourceOnly() throws {
    let fixtureRoot = try makeConfiguredDiscoveryFixtureRoot(name: "candidate-filter")
    defer {
        try? fixtureRoot.cleanup()
    }

    let firstRoot = fixtureRoot.url
        .appending(path: "sources/primary/.codex/sessions", directoryHint: .isDirectory)
    let secondRoot = fixtureRoot.url
        .appending(path: "sources/secondary/.codex/sessions", directoryHint: .isDirectory)
    try installTranscript(at: firstRoot, day: "09", name: "primary")
    try installTranscript(at: secondRoot, day: "10", name: "secondary")

    let adapter = DefaultCodexSourceDiscoveryAdapter(
        sourceDefinitions: [
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-primary"),
                displayName: "Codex primary",
                kind: .codex,
                rootPath: firstRoot.path,
                isEnabled: true
            ),
            LocalSessionSourceDefinition(
                id: SessionSourceID(rawValue: "codex-secondary"),
                displayName: "Codex secondary",
                kind: .codex,
                rootPath: secondRoot.path,
                isEnabled: true
            ),
        ]
    )

    let files = try adapter.enumerateCandidateFiles(sourceID: SessionSourceID(rawValue: "codex-secondary"))

    #expect(files.map(\.sourceID.rawValue) == ["codex-secondary"])
    #expect(files.map(\.relativePath) == ["2026/06/10/rollout-2026-06-10T06-00-00-secondary.jsonl"])
}

private func makeConfiguredDiscoveryFixtureRoot(name: String) throws -> FixtureTempRoot {
    try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-configured-source-\(name)-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
}

private func installTranscript(at sessionsRoot: URL, day: String, name: String) throws {
    let transcriptURL = sessionsRoot
        .appending(path: "2026/06/\(day)", directoryHint: .isDirectory)
        .appending(path: "rollout-2026-06-\(day)T06-00-00-\(name).jsonl")
    try FileManager.default.createDirectory(
        at: transcriptURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try #"{"type":"session_meta"}"#.write(to: transcriptURL, atomically: true, encoding: .utf8)
}

private struct FakeCodexSourceFileSystem: CodexSourceFileSystemChecking {
    let directoryExists: Bool
    let isReadableDirectory: Bool
    let countsResult: Result<SessionSourceCounts, Error>

    func directoryExists(at url: URL) -> Bool {
        directoryExists
    }

    func isReadableDirectory(at url: URL) -> Bool {
        isReadableDirectory
    }

    func sourceCounts(at sessionsRoot: URL) throws -> SessionSourceCounts {
        try countsResult.get()
    }

    func candidateFiles(at sessionsRoot: URL, sourceID: SessionSourceID) throws -> [CandidateSessionFile] {
        []
    }
}

private enum FakeCodexSourceFileSystemError: Error {
    case unreadableDirectory
}
