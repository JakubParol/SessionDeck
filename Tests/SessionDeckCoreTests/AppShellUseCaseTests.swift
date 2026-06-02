import Testing
@testable import SessionDeckCore

private struct FakeLaunchConfigurationProvider: LaunchConfigurationProviding {
    let configuration: AppShellLaunchConfiguration

    func loadConfiguration() -> AppShellLaunchConfiguration {
        configuration
    }
}

@Test("application use case builds the shell view model from an injected launch configuration provider")
func appShellUseCaseUsesInjectedProvider() {
    let useCase = AppShellUseCase(
        launchConfigurationProvider: FakeLaunchConfigurationProvider(
            configuration: AppShellLaunchConfiguration(
                title: "Fake SessionDeck",
                subtitle: "Injected application state",
                statusMessage: "Loaded from a fake provider.",
                configuredSourceCount: 2,
                safetyPolicy: LaunchSafetyPolicy(
                    readsRealAgentStores: false,
                    permitsNetworkCalls: false,
                    permitsCommandExecution: false,
                    permitsSessionMutation: false
                )
            )
        )
    )

    let viewModel = useCase.makeViewModel()

    #expect(viewModel.title == "Fake SessionDeck")
    #expect(viewModel.subtitle == "Injected application state")
    #expect(viewModel.statusMessage == "Loaded from a fake provider.")
    #expect(viewModel.configuredSourceCount == 2)
    #expect(viewModel.safetyPolicy.readsRealAgentStores == false)
    #expect(viewModel.safetyPolicy.permitsNetworkCalls == false)
    #expect(viewModel.safetyPolicy.permitsCommandExecution == false)
    #expect(viewModel.safetyPolicy.permitsSessionMutation == false)
}
