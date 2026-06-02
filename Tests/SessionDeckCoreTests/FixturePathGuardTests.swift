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
