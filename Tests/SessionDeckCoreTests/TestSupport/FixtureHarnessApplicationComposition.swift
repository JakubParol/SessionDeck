import SessionDeckCore

extension FixtureHarnessApplicationSmoke {
    func makeApplicationComposition() throws -> SessionDeckApplicationComposition {
        let sourceSummaries = sources.map { source in
            SessionSourceSummary(
                id: source.id,
                displayName: "\(source.tempSource.label) (\(source.tempSource.profile))",
                kind: .codex,
                locationDescription: source.tempSource.sessionsRootURL.path,
                isEnabled: true
            )
        }
        let sessionFiles = store.sessionFiles
        let sessionSummaries = try sessionFiles.map(sessionSummary)
        let extractionResultsBySourceID = Dictionary(
            uniqueKeysWithValues: Dictionary(grouping: sessionSummaries, by: \.sourceID).map { sourceID, sessions in
                (sourceID, CatalogSourceExtractionResult(sourceID: sourceID, sessions: sessions))
            }
        )
        let transcriptPreviews = try sessionFiles.map(transcriptPreview)
        let transcriptResults = transcriptPreviews.map(transcriptDecodeResult)
        let discoverSessionSources = DiscoverSessionSourcesUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(sources: sourceSummaries)
        )
        let refreshCatalogSnapshot = RefreshCatalogSnapshotUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(sources: sourceSummaries),
            metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: extractionResultsBySourceID)
        )
        let loadSelectedTranscript = LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: FakeSelectedTranscriptLoadingPort(
                results: transcriptResultsBySessionID(transcriptResults)
            )
        )
        let candidateEnumeration = FakeCandidateSessionFileEnumerationPort(files: [])
        let sourceChangeObservation = FakeLiveSourceChangeObservationPort()
        let liveRefreshPipeline = LiveRefreshPipelineCoordinator(
            sourceChangeObservation: sourceChangeObservation,
            reconciliation: ReconcileSessionSourcesUseCase(candidateEnumeration: candidateEnumeration),
            timerScheduler: FakeLiveRefreshTimerScheduler(),
            debounceInterval: 0.25,
            reconciliationInterval: 30
        ) { _ in }
        let appShellUseCase = AppShellUseCase(
            launchConfigurationProvider: FixtureHarnessLaunchConfigurationProvider(
                configuredSourceCount: sourceSummaries.count
            ),
            discoverSessionSources: discoverSessionSources,
            refreshCatalogSnapshot: refreshCatalogSnapshot,
            loadSelectedTranscript: loadSelectedTranscript
        )

        return SessionDeckApplicationComposition(
            appShellUseCase: appShellUseCase,
            appShellViewModel: appShellUseCase.makeViewModel(),
            discoverSessionSources: discoverSessionSources,
            enumerateCandidateSessionFiles: EnumerateCandidateSessionFilesUseCase(
                candidateFileEnumeration: candidateEnumeration
            ),
            listSessions: ListSessionsUseCase(
                sessionCatalog: FakeSessionCatalogPort(sessions: sessionSummaries)
            ),
            refreshCatalogSnapshot: refreshCatalogSnapshot,
            loadTranscriptPreview: LoadTranscriptPreviewUseCase(
                transcriptLoading: FakeTranscriptLoadingPort(previews: transcriptPreviews)
            ),
            loadTranscriptSegments: LoadTranscriptSegmentsUseCase(
                transcriptDecoding: FakeTranscriptDecodingPort(results: transcriptResults)
            ),
            loadSelectedTranscript: loadSelectedTranscript,
            sourceChangeObservation: sourceChangeObservation,
            liveRefreshPipeline: liveRefreshPipeline
        )
    }

    private func transcriptDecodeResult(_ preview: TranscriptPreview) -> TranscriptDecodeResult {
        TranscriptDecodeResult(
            sessionID: preview.sessionID,
            title: preview.title,
            segments: preview.segments,
            diagnostics: [],
            isPartial: preview.isTruncated
        )
    }

    private func transcriptResultsBySessionID(
        _ results: [TranscriptDecodeResult]
    ) -> [SessionID: TranscriptDecodeResult] {
        Dictionary(uniqueKeysWithValues: results.map { ($0.sessionID, $0) })
    }
}
