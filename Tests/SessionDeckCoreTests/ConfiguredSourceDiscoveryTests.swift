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
    #expect(duplicate.isEnabled == false)
    #expect(duplicate.locationDescription == sessionsRoot.standardizedFileURL.path)
    #expect(duplicate.diagnostic?.code == "source_root_duplicate")
    #expect(duplicate.counts == .empty)
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
    #expect(unsupported.isEnabled == false)
    #expect(unsupported.diagnostic?.code == "source_kind_unsupported")
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
    #expect(disabled.diagnostic?.code == "source_root_disabled")
    #expect(disabled.counts == .empty)
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
