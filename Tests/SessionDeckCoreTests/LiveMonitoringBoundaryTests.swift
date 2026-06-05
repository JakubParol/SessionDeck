import Testing
@testable import SessionDeckCore

@Test("live source change event preserves source session and path identity")
func liveSourceChangeEventPreservesIdentity() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let sessionID = SessionID(rawValue: "session-123")
    let event = LiveSourceChangeEvent(
        sourceID: sourceID,
        affectedPath: "/tmp/sessiondeck/.codex/sessions/2026/06/05/session-123.jsonl",
        sessionID: sessionID,
        kind: .modified
    )

    #expect(event.identity == LiveRefreshIdentity.session(sessionID, sourceID: sourceID))
    #expect(event.affectedPath == "/tmp/sessiondeck/.codex/sessions/2026/06/05/session-123.jsonl")
    #expect(event.kind == .modified)
}

@Test("watcher degraded state models missing deleted permission and unsupported paths")
func watcherDegradedStateModelsTypedFailures() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let missing = LiveSourceWatcherDegradedState(
        sourceID: sourceID,
        path: "/tmp/sessiondeck/missing",
        reason: .missingPath
    )
    let deleted = LiveSourceWatcherDegradedState(
        sourceID: sourceID,
        path: "/tmp/sessiondeck/deleted.jsonl",
        reason: .deletedPath
    )
    let permissionDenied = LiveSourceWatcherDegradedState(
        sourceID: sourceID,
        path: "/tmp/sessiondeck/private",
        reason: .permissionDenied
    )
    let unsupported = LiveSourceWatcherDegradedState(
        sourceID: nil,
        path: "/tmp/sessiondeck/event",
        reason: .unsupportedEvent
    )

    #expect(missing.reason.code == "live_monitoring.missing_path")
    #expect(deleted.reason.code == "live_monitoring.deleted_path")
    #expect(permissionDenied.reason.code == "live_monitoring.permission_denied")
    #expect(unsupported.reason.code == "live_monitoring.unsupported_event")
}

@Test("live refresh request preserves scope trigger reason and event count")
func liveRefreshRequestPreservesScopeTriggerAndCount() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let sessionID = SessionID(rawValue: "session-123")
    let request = LiveRefreshRequest(
        scope: .session(sessionID, sourceID: sourceID),
        trigger: .sourceChange,
        eventCount: 3
    )

    #expect(request.scope == .session(sessionID, sourceID: sourceID))
    #expect(request.trigger == .sourceChange)
    #expect(request.eventCount == 3)
}

@Test("live refresh request can represent reconciliation startup and debounced triggers")
func liveRefreshRequestRepresentsReconciliationStartupAndDebouncedTriggers() {
    let sourceID = SessionSourceID(rawValue: "codex-default")

    #expect(
        LiveRefreshRequest(scope: .allSources, trigger: .appStartup, eventCount: 1).trigger == .appStartup
    )
    #expect(
        LiveRefreshRequest(scope: .source(sourceID), trigger: .debouncedSourceChange, eventCount: 4).trigger
            == .debouncedSourceChange
    )
    #expect(
        LiveRefreshRequest(scope: .allSources, trigger: .reconciliation, eventCount: 1).trigger == .reconciliation
    )
}

@Test("monitoring state exposes current running stale degraded and stopped states")
func monitoringStateExposesRefreshLifecycle() {
    let sourceID = SessionSourceID(rawValue: "codex-default")
    let request = LiveRefreshRequest(scope: .source(sourceID), trigger: .manualRefresh, eventCount: 1)
    let failure = LiveMonitoringFailure(
        sourceID: sourceID,
        reason: .reconciliationFailed,
        message: "candidate enumeration failed"
    )

    #expect(LiveMonitoringState.current(sourceID: sourceID) == .current(sourceID: sourceID))
    #expect(LiveMonitoringState.refreshPending(request) == .refreshPending(request))
    #expect(LiveMonitoringState.refreshRunning(request) == .refreshRunning(request))
    #expect(LiveMonitoringState.reconciling(sourceID: sourceID, trigger: .reconciliation) == .reconciling(
        sourceID: sourceID,
        trigger: .reconciliation
    ))
    #expect(LiveMonitoringState.stale(sourceID: sourceID, reason: .missedChangeRecovered) == .stale(
        sourceID: sourceID,
        reason: .missedChangeRecovered
    ))
    #expect(LiveMonitoringState.degraded(failure) == .degraded(failure))
    #expect(LiveMonitoringState.stopped == .stopped)
}

@Test("monitoring failures expose typed diagnostic codes")
func monitoringFailuresExposeTypedCodes() {
    #expect(LiveMonitoringFailureReason.watcherSetupFailed.code == "live_monitoring.watcher_setup_failed")
    #expect(LiveMonitoringFailureReason.sourceMissing.code == "live_monitoring.source_missing")
    #expect(LiveMonitoringFailureReason.permissionDenied.code == "live_monitoring.permission_denied")
    #expect(LiveMonitoringFailureReason.reconciliationFailed.code == "live_monitoring.reconciliation_failed")
}
