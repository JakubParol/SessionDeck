import Foundation
import Testing
@testable import SessionDeckCore

@Test("selected session refresh policy matches current selected session by session id")
func selectedSessionRefreshPolicyMatchesCurrentSessionID() {
    let selectedSession = selectedLiveRefreshSession()
    let request = LiveRefreshRequest(
        scope: .session(selectedSession.id, sourceID: selectedSession.sourceID),
        trigger: .debouncedSourceChange,
        eventCount: 1
    )

    #expect(SelectedSessionLiveRefreshPolicy.shouldRefreshSelectedSession(
        selectedSession,
        for: request
    ))
}

@Test("selected session refresh policy matches current selected session by path")
func selectedSessionRefreshPolicyMatchesCurrentSessionPath() {
    let selectedSession = selectedLiveRefreshSession()
    let request = LiveRefreshRequest(
        scope: .path("/tmp/sessiondeck-fixture/.codex/sessions/selected.jsonl", sourceID: selectedSession.sourceID),
        trigger: .debouncedSourceChange,
        eventCount: 1
    )

    #expect(SelectedSessionLiveRefreshPolicy.shouldRefreshSelectedSession(
        selectedSession,
        for: request
    ))
}

@Test("selected session refresh policy ignores non selected session changes")
func selectedSessionRefreshPolicyIgnoresNonSelectedSessionChanges() {
    let selectedSession = selectedLiveRefreshSession()
    let request = LiveRefreshRequest(
        scope: .session(SessionID(rawValue: "other-session"), sourceID: selectedSession.sourceID),
        trigger: .debouncedSourceChange,
        eventCount: 1
    )

    #expect(SelectedSessionLiveRefreshPolicy.shouldRefreshSelectedSession(
        selectedSession,
        for: request
    ) == false)
}

@Test("selected session coordinator preserves previous content while applying refreshed read model")
func selectedSessionCoordinatorPreservesPreviousContentWhileApplyingRefresh() {
    let selectedSession = selectedLiveRefreshSession()
    let previousModel = selectedReadModel(
        selectedSession,
        title: "Selected transcript",
        segments: [selectedSegment(id: "line-1", text: "Already readable", order: 0)]
    )
    let refreshedResult = selectedDecodeResult(
        sessionID: selectedSession.id,
        title: "Selected transcript",
        segments: [
            selectedSegment(id: "line-1", text: "Already readable", order: 0),
            selectedSegment(id: "line-2", text: "Appended turn", order: 1),
        ]
    )
    var recordedStates: [SelectedSessionLiveRefreshState] = []
    let coordinator = SelectedSessionLiveRefreshCoordinator(
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: RecordingSelectedTranscriptLoadingPort(results: [
                selectedSession.id: refreshedResult,
            ])
        ),
        stateRecorder: { state in
            recordedStates.append(state)
        }
    )

    let finalState = coordinator.handle(
        LiveRefreshRequest(
            scope: .session(selectedSession.id, sourceID: selectedSession.sourceID),
            trigger: .debouncedSourceChange,
            eventCount: 1
        ),
        selectedSession: selectedSession,
        currentReadModel: previousModel
    )

    #expect(recordedStates.first == .refreshing(previous: previousModel))
    #expect(finalState == .loaded(SelectedTranscriptReadModel(session: selectedSession, decodeResult: refreshedResult)))
    #expect(coordinator.state == finalState)
}

@Test("selected session coordinator ignores non selected refresh without loading transcript")
func selectedSessionCoordinatorIgnoresNonSelectedRefreshWithoutLoading() {
    let selectedSession = selectedLiveRefreshSession()
    let previousModel = selectedReadModel(
        selectedSession,
        title: "Selected transcript",
        segments: [selectedSegment(id: "line-1", text: "Already readable", order: 0)]
    )
    let loadingPort = RecordingSelectedTranscriptLoadingPort(results: [
        selectedSession.id: selectedDecodeResult(
            sessionID: selectedSession.id,
            title: "Should not load",
            segments: [selectedSegment(id: "line-2", text: "Unexpected", order: 1)]
        ),
    ])
    let coordinator = SelectedSessionLiveRefreshCoordinator(
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(selectedTranscriptLoading: loadingPort)
    )

    let finalState = coordinator.handle(
        LiveRefreshRequest(
            scope: .session(SessionID(rawValue: "other-session"), sourceID: selectedSession.sourceID),
            trigger: .debouncedSourceChange,
            eventCount: 1
        ),
        selectedSession: selectedSession,
        currentReadModel: previousModel
    )

    #expect(finalState == .ignored(previous: previousModel))
    #expect(loadingPort.loadCount == 0)
}

@Test("selected session coordinator replaces unchanged content without duplicate rows")
func selectedSessionCoordinatorReplacesUnchangedContentWithoutDuplicates() throws {
    let selectedSession = selectedLiveRefreshSession()
    let unchangedSegment = selectedSegment(id: "line-1", text: "Already readable", order: 0)
    let previousModel = selectedReadModel(
        selectedSession,
        title: "Selected transcript",
        segments: [unchangedSegment]
    )
    let refreshedResult = selectedDecodeResult(
        sessionID: selectedSession.id,
        title: "Selected transcript",
        segments: [unchangedSegment]
    )
    let coordinator = SelectedSessionLiveRefreshCoordinator(
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: RecordingSelectedTranscriptLoadingPort(results: [
                selectedSession.id: refreshedResult,
            ])
        )
    )

    let finalState = coordinator.handle(
        LiveRefreshRequest(
            scope: .path(selectedSession.sessionPath, sourceID: selectedSession.sourceID),
            trigger: .debouncedSourceChange,
            eventCount: 2
        ),
        selectedSession: selectedSession,
        currentReadModel: previousModel
    )
    let readModel = try #require(finalState.loadedReadModel)

    #expect(readModel.segments.map(\.id) == ["line-1"])
}

@Test("selected session coordinator preserves refreshed diagnostics in loaded read model")
func selectedSessionCoordinatorPreservesRefreshedDiagnostics() throws {
    let selectedSession = selectedLiveRefreshSession()
    let diagnostic = TranscriptDecodeDiagnostic(
        code: "codex_jsonl.unknown_event",
        severity: .warning,
        message: "Unsupported Codex event.",
        source: TranscriptSegmentSourceReference(
            sourceID: selectedSession.sourceID,
            relativePath: "selected.jsonl",
            lineNumber: 2
        ),
        allowsDecodingToContinue: true
    )
    let refreshedResult = TranscriptDecodeResult(
        sessionID: selectedSession.id,
        title: "Selected transcript",
        segments: [selectedSegment(id: "line-1", text: "Already readable", order: 0)],
        diagnostics: [diagnostic],
        isPartial: false
    )
    let coordinator = SelectedSessionLiveRefreshCoordinator(
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: RecordingSelectedTranscriptLoadingPort(results: [
                selectedSession.id: refreshedResult,
            ])
        )
    )

    let finalState = coordinator.handle(
        LiveRefreshRequest(
            scope: .session(selectedSession.id, sourceID: selectedSession.sourceID),
            trigger: .debouncedSourceChange,
            eventCount: 1
        ),
        selectedSession: selectedSession,
        currentReadModel: nil
    )
    let readModel = try #require(finalState.loadedReadModel)

    #expect(readModel.diagnostics == [diagnostic])
}

@Test("selected session coordinator keeps previous content when refresh loading fails")
func selectedSessionCoordinatorKeepsPreviousContentWhenRefreshFails() throws {
    let selectedSession = selectedLiveRefreshSession()
    let previousModel = selectedReadModel(
        selectedSession,
        title: "Selected transcript",
        segments: [selectedSegment(id: "line-1", text: "Already readable", order: 0)]
    )
    let coordinator = SelectedSessionLiveRefreshCoordinator(
        loadSelectedTranscript: LoadSelectedTranscriptUseCase(
            selectedTranscriptLoading: FailingSelectedTranscriptLoadingPort()
        )
    )

    let finalState = coordinator.handle(
        LiveRefreshRequest(
            scope: .session(selectedSession.id, sourceID: selectedSession.sourceID),
            trigger: .debouncedSourceChange,
            eventCount: 1
        ),
        selectedSession: selectedSession,
        currentReadModel: previousModel
    )

    #expect(finalState.previousReadModel == previousModel)
}

private func selectedLiveRefreshSession() -> SessionSummary {
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    return SessionSummary(
        id: SessionID(rawValue: "selected-session"),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex fixture",
            profileName: "Fixture"
        ),
        title: "Selected fixture",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/sessiondeck", displayName: "SessionDeck"),
        sessionPath: "/tmp/sessiondeck-fixture/.codex/sessions/selected.jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
