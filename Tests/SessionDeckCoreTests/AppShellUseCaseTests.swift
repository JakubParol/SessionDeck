import Foundation
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

@Test("app shell use case renders launch source discovery summary from application DTOs")
func appShellUseCaseRendersLaunchSourceDiscoverySummary() {
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    let useCase = AppShellUseCase(
        launchConfigurationProvider: fakeLaunchConfigurationProvider(),
        discoverSessionSources: DiscoverSessionSourcesUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(
                sources: [
                    SessionSourceSummary(
                        id: sourceID,
                        displayName: "Codex fixture",
                        kind: .codex,
                        locationDescription: "/tmp/sessiondeck-fixture/.codex/sessions",
                        isEnabled: true,
                        availability: .available,
                        counts: SessionSourceCounts(sessionBucketDirectoryCount: 2, transcriptFileCount: 3)
                    ),
                ]
            )
        )
    )

    let viewModel = useCase.makeViewModel()

    #expect(viewModel.sourceDiscoverySummary.configuredSourceCount == 1)
    #expect(viewModel.sourceDiscoverySummary.availableSourceCount == 1)
    #expect(viewModel.sourceDiscoverySummary.candidateFileCount == 3)
    #expect(viewModel.sourceDiscoverySummary.warningCount == 0)
    #expect(viewModel.sourceDiscoverySummary.errorCount == 0)
    #expect(viewModel.sourceDiscoverySummary.statusMessage == "Source discovery found 1 available source(s).")
}

@Test("composition root reports missing default source without reading real home data")
func appShellUseCaseReportsMissingDefaultSourceWithTempHome() throws {
    let fixtureRoot = try FixtureTempRoot(
        parentDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        name: "sessiondeck-missing-source-\(UUID().uuidString)",
        pathGuard: FixturePathGuard(forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser])
    )
    defer {
        try? fixtureRoot.cleanup()
    }

    let composition = SessionDeckCompositionRoot.makeApplicationComposition(
        homeDirectoryProvider: StaticHomeDirectoryProvider(homeDirectoryURL: fixtureRoot.url)
    )

    let summary = composition.appShellViewModel.sourceDiscoverySummary
    #expect(summary.configuredSourceCount == 1)
    #expect(summary.availableSourceCount == 0)
    #expect(summary.candidateFileCount == 0)
    #expect(summary.warningCount == 1)
    #expect(summary.errorCount == 0)
    #expect(summary.statusMessage == "Source discovery completed with warnings.")
}

@Test("refresh view model reruns source discovery through the application use case")
func refreshViewModelRerunsSourceDiscovery() {
    let sourceID = SessionSourceID(rawValue: "codex-refresh")
    let sourceDiscovery = CountingSourceDiscoveryPort(
        responses: [
            [
                SessionSourceSummary(
                    id: sourceID,
                    displayName: "Codex refresh",
                    kind: .codex,
                    locationDescription: "/tmp/sessiondeck-refresh/.codex/sessions",
                    isEnabled: true,
                    availability: .missing,
                    diagnostic: SessionSourceDiagnostic(
                        code: .codexSessionsRootMissing,
                        message: "Configured Codex sessions root was not found."
                    )
                ),
            ],
            [
                SessionSourceSummary(
                    id: sourceID,
                    displayName: "Codex refresh",
                    kind: .codex,
                    locationDescription: "/tmp/sessiondeck-refresh/.codex/sessions",
                    isEnabled: true,
                    availability: .available,
                    counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 2)
                ),
            ],
        ]
    )
    let useCase = AppShellUseCase(
        launchConfigurationProvider: fakeLaunchConfigurationProvider(),
        discoverSessionSources: DiscoverSessionSourcesUseCase(sourceDiscovery: sourceDiscovery)
    )

    let initialViewModel = useCase.makeViewModel()
    let refreshedViewModel = useCase.refreshViewModel()

    #expect(sourceDiscovery.callCount == 2)
    #expect(initialViewModel.sourceDiscoverySummary.availableSourceCount == 0)
    #expect(refreshedViewModel.sourceDiscoverySummary.availableSourceCount == 1)
    #expect(refreshedViewModel.sourceDiscoverySummary.candidateFileCount == 2)
}

@Test("app shell use case maps catalog snapshot DTOs into display rows")
func appShellUseCaseMapsCatalogSnapshotRows() {
    let sourceID = SessionSourceID(rawValue: "codex-catalog")
    let diagnosticSession = SessionSummary(
        id: SessionID(rawValue: "diagnostic-session"),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex catalog",
            profileName: "naomi"
        ),
        title: nil,
        fallbackTitle: "Recovered session",
        projectHint: CatalogProjectHint(cwdPath: nil, displayName: "Non-project Chat"),
        sessionPath: "/tmp/sessiondeck/diagnostic.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: nil),
        fileSize: CatalogFileSize(byteCount: 2_048),
        metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: nil),
        health: CatalogEntryHealth(
            parseStatus: .missingMetadata,
            diagnostics: [
                CatalogEntryDiagnostic(
                    code: .missingMetadata,
                    severity: .warning,
                    message: "Session metadata was incomplete."
                )
            ]
        )
    )
    let useCase = AppShellUseCase(
        launchConfigurationProvider: fakeLaunchConfigurationProvider(),
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(
                sources: [catalogSource(id: sourceID, displayName: "Codex catalog")]
            ),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [
                sourceID: CatalogSourceExtractionResult(sourceID: sourceID, sessions: [diagnosticSession])
            ]),
            clock: FixedCatalogRefreshClock(now: Date(timeIntervalSince1970: 1_770_100_000))
        )
    )

    let catalogSummary = useCase.makeViewModel().catalogSummary

    #expect(catalogSummary.totalCount == 1)
    #expect(catalogSummary.healthyCount == 0)
    #expect(catalogSummary.diagnosticCount == 1)
    #expect(catalogSummary.statusMessage == "Catalog shows 1 entry with diagnostics.")
    #expect(catalogSummary.rows == [
        AppShellCatalogRow(
            id: SessionID(rawValue: "diagnostic-session"),
            title: "Recovered session",
            sourceLabel: "Codex catalog / naomi",
            projectHint: "Non-project Chat",
            lastActivityLabel: "Last activity unknown",
            sizeLabel: "2 KB",
            statusLabel: "Missing metadata",
            diagnosticSummary: "Session metadata was incomplete.",
            severity: .warning
        )
    ])
}

@Test("app shell use case marks catalog refresh failure state")
func appShellUseCaseMarksCatalogRefreshFailureState() {
    let useCase = AppShellUseCase(
        launchConfigurationProvider: fakeLaunchConfigurationProvider(),
        refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
            sourceDiscovery: ThrowingSourceDiscoveryPort(),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: [:])
        )
    )

    let viewModel = useCase.makeViewModel()

    #expect(viewModel.catalogSummary.sourceFailureCount == 1)
    #expect(viewModel.catalogSummary.statusMessage == "Catalog refresh failed before rows could be built.")
    #expect(viewModel.refreshState == .failed("Catalog refresh failed before rows could be built."))
}


private func fakeLaunchConfigurationProvider() -> FakeLaunchConfigurationProvider {
    FakeLaunchConfigurationProvider(
        configuration: AppShellLaunchConfiguration(
            title: "Fake SessionDeck",
            subtitle: "Injected application state",
            statusMessage: "Loaded from a fake provider.",
            configuredSourceCount: 0,
            safetyPolicy: .placeholderSafe
        )
    )
}

private func catalogSource(id: SessionSourceID, displayName: String) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: displayName,
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
    )
}

private final class CountingSourceDiscoveryPort: SourceDiscoveryPort, @unchecked Sendable {
    private let responses: [[SessionSourceSummary]]
    private var responseIndex = 0
    private(set) var callCount = 0

    init(responses: [[SessionSourceSummary]]) {
        self.responses = responses
    }

    func discoverSources() throws -> [SessionSourceSummary] {
        defer {
            callCount += 1
            responseIndex += 1
        }

        return responses[min(responseIndex, responses.count - 1)]
    }
}

private struct ThrowingSourceDiscoveryPort: SourceDiscoveryPort {
    func discoverSources() throws -> [SessionSourceSummary] {
        throw CatalogRefreshFailure.synthetic
    }
}

private enum CatalogRefreshFailure: Error {
    case synthetic
}
