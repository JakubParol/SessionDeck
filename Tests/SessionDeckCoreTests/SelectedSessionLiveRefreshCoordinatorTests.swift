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
