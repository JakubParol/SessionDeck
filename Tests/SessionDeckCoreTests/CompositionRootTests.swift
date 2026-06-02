import Testing
@testable import SessionDeckCore

@Test("composition root wires every placeholder-safe application dependency")
func compositionRootWiresPlaceholderSafeApplicationDependencies() throws {
    let composition = SessionDeckCompositionRoot.makeApplicationComposition()

    #expect(composition.appShellViewModel.title == "SessionDeck")
    #expect(composition.appShellViewModel.configuredSourceCount == 0)
    #expect(composition.appShellViewModel.safetyPolicy == .placeholderSafe)

    let sources = try composition.discoverSessionSources.discoverSources()
    #expect(sources.isEmpty)

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
