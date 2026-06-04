import Testing
@testable import SessionDeckCore

@Test("composition root exposes read-only source discovery in the app shell")
func compositionRootExposesReadOnlySourceDiscoveryState() {
    let viewModel = SessionDeckCompositionRoot.makeAppShellViewModel()

    #expect(viewModel.title == "SessionDeck")
    #expect(viewModel.subtitle == "Local-first session viewer scaffold")
    #expect(viewModel.statusMessage == "Read-only source discovery is active. Session catalog is not implemented yet.")
    #expect(viewModel.configuredSourceCount == 1)
    #expect(viewModel.safetyPolicy.readsRealAgentStores == true)
    #expect(viewModel.safetyPolicy.permitsNetworkCalls == false)
    #expect(viewModel.safetyPolicy.permitsCommandExecution == false)
    #expect(viewModel.safetyPolicy.permitsSessionMutation == false)
}
