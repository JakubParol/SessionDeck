import Testing
@testable import SessionDeckCore

@Test("composition root preserves the safe placeholder app shell")
func compositionRootUsesSafePlaceholderState() {
    let viewModel = SessionDeckCompositionRoot.makeAppShellViewModel()

    #expect(viewModel.title == "SessionDeck")
    #expect(viewModel.subtitle == "Local-first session viewer scaffold")
    #expect(viewModel.statusMessage == "Placeholder app shell only. Session catalog is not implemented yet.")
    #expect(viewModel.configuredSourceCount == 0)
    #expect(viewModel.safetyPolicy.readsRealAgentStores == false)
    #expect(viewModel.safetyPolicy.permitsNetworkCalls == false)
    #expect(viewModel.safetyPolicy.permitsCommandExecution == false)
    #expect(viewModel.safetyPolicy.permitsSessionMutation == false)
}
