public enum SessionDeckCompositionRoot {
    public static func makeAppShellViewModel() -> AppShellViewModel {
        let useCase = AppShellUseCase(
            launchConfigurationProvider: PlaceholderLaunchConfigurationProvider()
        )

        return useCase.makeViewModel()
    }
}
