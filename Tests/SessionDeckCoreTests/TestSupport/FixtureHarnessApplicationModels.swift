import SessionDeckCore

struct FixtureHarnessLaunchConfigurationProvider: LaunchConfigurationProviding {
    let configuredSourceCount: Int

    func loadConfiguration() -> AppShellLaunchConfiguration {
        AppShellLaunchConfiguration(
            title: "SessionDeck",
            subtitle: "Synthetic fixture application smoke",
            statusMessage: "Fixture-backed application composition.",
            configuredSourceCount: configuredSourceCount,
            safetyPolicy: .placeholderSafe
        )
    }
}

struct FixtureHarnessApplicationSource: Equatable {
    let tempSource: TempCodexSessionSource
    let id: SessionSourceID
}

struct FixtureHarnessApplicationSession: Equatable {
    let id: SessionID
    let file: TempCodexSessionFile
}

struct FixtureHarnessMetadata {
    let timestamp: String?
    let title: String?
    let project: String?
    let cwd: String?
    let firstText: String?
}
