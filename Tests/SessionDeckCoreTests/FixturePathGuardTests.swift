import Foundation
import Testing

@Test("fixture path guard rejects a real codex root")
func fixturePathGuardRejectsRealCodexRoot() throws {
    let pathGuard = FixturePathGuard(
        forbiddenHomeDirectories: [URL(fileURLWithPath: "/Users/jakubparol", isDirectory: true)]
    )

    do {
        _ = try pathGuard.validateFixtureRoot(
            URL(fileURLWithPath: "/Users/jakubparol/.codex", isDirectory: true)
        )
        Issue.record("Expected the guard to reject the real .codex root")
    } catch let error as FixturePathGuardError {
        #expect(error == .forbiddenRealSessionStore("/Users/jakubparol/.codex"))
    }
}

@Test("fixture path guard rejects a real hermes descendant")
func fixturePathGuardRejectsRealHermesDescendant() throws {
    let pathGuard = FixturePathGuard(
        forbiddenHomeDirectories: [URL(fileURLWithPath: "/Users/jakubparol", isDirectory: true)]
    )

    do {
        _ = try pathGuard.validateFixtureRoot(
            URL(fileURLWithPath: "/Users/jakubparol/.hermes/sessions", isDirectory: true)
        )
        Issue.record("Expected the guard to reject a real .hermes descendant")
    } catch let error as FixturePathGuardError {
        #expect(error == .forbiddenRealSessionStore("/Users/jakubparol/.hermes/sessions"))
    }
}

@Test("fixture path guard rejects a symlink-equivalent codex root")
func fixturePathGuardRejectsSymlinkEquivalentCodexRoot() throws {
    let fileManager = FileManager.default
    let parentDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("SessionDeckFixturePathGuardTests", isDirectory: true)
        .appendingPathComponent("symlink-\(UUID().uuidString)", isDirectory: true)
    let forbiddenHome = parentDirectory.appendingPathComponent("RealHome", isDirectory: true)
    let linkedHome = parentDirectory.appendingPathComponent("LinkedHome", isDirectory: true)

    try fileManager.createDirectory(
        at: forbiddenHome.appendingPathComponent(".codex", isDirectory: true),
        withIntermediateDirectories: true
    )
    try fileManager.createSymbolicLink(at: linkedHome, withDestinationURL: forbiddenHome)
    defer {
        try? fileManager.removeItem(at: parentDirectory)
    }

    let pathGuard = FixturePathGuard(forbiddenHomeDirectories: [forbiddenHome])

    do {
        _ = try pathGuard.validateFixtureRoot(linkedHome.appendingPathComponent(".codex", isDirectory: true))
        Issue.record("Expected the guard to reject a symlink-equivalent .codex root")
    } catch let error as FixturePathGuardError {
        #expect(error == .forbiddenRealSessionStore(forbiddenHome.appendingPathComponent(".codex").path))
    }
}

@Test("fixture path guard rejects a case-equivalent hermes descendant")
func fixturePathGuardRejectsCaseEquivalentHermesDescendant() throws {
    let fileManager = FileManager.default
    let parentDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("SessionDeckFixturePathGuardTests", isDirectory: true)
        .appendingPathComponent("case-\(UUID().uuidString)", isDirectory: true)
    let forbiddenHome = parentDirectory.appendingPathComponent("RealHome", isDirectory: true)
    let caseEquivalentHome = URL(fileURLWithPath: forbiddenHome.path.lowercased(), isDirectory: true)

    try fileManager.createDirectory(
        at: forbiddenHome.appendingPathComponent(".hermes", isDirectory: true),
        withIntermediateDirectories: true
    )
    defer {
        try? fileManager.removeItem(at: parentDirectory)
    }

    let pathGuard = FixturePathGuard(forbiddenHomeDirectories: [forbiddenHome])

    do {
        _ = try pathGuard.validateFixtureRoot(
            caseEquivalentHome.appendingPathComponent(".hermes/sessions", isDirectory: true)
        )
        Issue.record("Expected the guard to reject a case-equivalent .hermes descendant")
    } catch let error as FixturePathGuardError {
        if case let .forbiddenRealSessionStore(path) = error {
            #expect(path.lowercased() == forbiddenHome.appendingPathComponent(".hermes/sessions").path.lowercased())
        } else {
            Issue.record("Expected a forbidden real session store error")
        }
    }
}

@Test("fixture temp root helper accepts a generated temp fixture root")
func fixtureTempRootAcceptsGeneratedTempRoot() throws {
    let parentDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("SessionDeckFixturePathGuardTests", isDirectory: true)
    let pathGuard = FixturePathGuard(
        forbiddenHomeDirectories: [URL(fileURLWithPath: "/Users/jakubparol", isDirectory: true)]
    )

    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: parentDirectory,
        name: "accepted-\(UUID().uuidString)",
        pathGuard: pathGuard
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    #expect(FileManager.default.fileExists(atPath: fixtureRoot.url.path))
}
