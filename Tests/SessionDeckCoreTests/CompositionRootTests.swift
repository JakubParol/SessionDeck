import Foundation
import Testing
@testable import SessionDeckCore

@Test("composition root wires default source discovery without presentation IO")
func compositionRootWiresDefaultSourceDiscoveryWithoutPresentationIO() throws {
    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-composition-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    let composition = SessionDeckCompositionRoot.makeApplicationComposition(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: fixtureRoot.url)
    )

    #expect(composition.appShellViewModel.title == "SessionDeck")
    #expect(composition.appShellViewModel.configuredSourceCount == 0)
    #expect(composition.appShellViewModel.safetyPolicy == .placeholderSafe)

    let sources = try composition.discoverSessionSources.discoverSources()
    #expect(sources.map(\.id) == [DefaultCodexSourceDiscoveryAdapter.sourceID])
    #expect(sources.first?.availability == .missing)

    let sessions = try composition.listSessions.listSessions()
    #expect(sessions.isEmpty)

    let missingSessionID = SessionID(rawValue: "placeholder-missing")
    do {
        _ = try composition.loadTranscriptPreview.loadPreview(sessionID: missingSessionID)
        Issue.record("Placeholder transcript loading must not synthesize or read transcript content")
    } catch let error as PlaceholderTranscriptLoadingError {
        #expect(error == .previewUnavailable(missingSessionID))
    }
}
