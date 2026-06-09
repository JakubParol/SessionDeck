import Testing
@testable import SessionDeckCore

@Test("composition root exposes read-only source discovery in the app shell")
func compositionRootExposesReadOnlySourceDiscoveryState() {
    let viewModel = SessionDeckCompositionRoot.makeAppShellViewModel()

    #expect(viewModel.title == "SessionDeck")
    #expect(viewModel.subtitle == "Local-first session viewer")
    #expect(viewModel.statusMessage == "Ready to refresh read-only local session sources.")
    #expect(viewModel.sourceDiscoverySummary == .placeholder)
    #expect(viewModel.catalogSummary == .placeholder)
    #expect(viewModel.safetyPolicy.readsRealAgentStores == true)
    #expect(viewModel.safetyPolicy.permitsNetworkCalls == false)
    #expect(viewModel.safetyPolicy.permitsCommandExecution == false)
    #expect(viewModel.safetyPolicy.permitsSessionMutation == false)
}
