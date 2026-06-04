import Foundation
import Testing
@testable import SessionDeckCore

@Test("selected Codex transcript adapter decodes checked-in fixture paths through the read model")
func selectedCodexTranscriptAdapterDecodesFixturePath() throws {
    let sessionID = SessionID(rawValue: "selected-minimal")
    let fixtureURL = try CodexTranscriptFixtureManifest.fixtureURL(for: .minimalConversationTurns)
    let session = makeCodexSelectedTranscriptSession(id: sessionID, path: fixtureURL.path)
    let useCase = LoadSelectedTranscriptUseCase(
        selectedTranscriptLoading: CodexSelectedTranscriptLoadingAdapter()
    )

    let readModel = try useCase.loadTranscript(for: session)

    #expect(readModel.sessionID == sessionID)
    #expect(readModel.title == "Minimal Conversation Turns")
    #expect(readModel.sourceID == SessionSourceID(rawValue: "codex-fixture"))
    #expect(readModel.sessionPath == fixtureURL.path)
    #expect(readModel.segments.map(\.kind) == [.userMessage, .assistantMessage])
    #expect(readModel.segments.map(\.source.relativePath) == ["minimal-conversation-turns.jsonl", "minimal-conversation-turns.jsonl"])
    #expect(readModel.diagnostics.isEmpty)
}

@Test("selected Codex transcript adapter maps missing fixture paths to typed errors")
func selectedCodexTranscriptAdapterMapsMissingPathsToTypedErrors() throws {
    let sessionID = SessionID(rawValue: "selected-missing")
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jsonl")
        .path
    let session = makeCodexSelectedTranscriptSession(id: sessionID, path: missingPath)
    let useCase = LoadSelectedTranscriptUseCase(
        selectedTranscriptLoading: CodexSelectedTranscriptLoadingAdapter()
    )

    #expect(throws: SelectedTranscriptLoadingError.transcriptMissing(sessionID)) {
        try useCase.loadTranscript(for: session)
    }
}

@Test("selected Codex transcript adapter maps unreadable fixture paths to typed errors")
func selectedCodexTranscriptAdapterMapsUnreadablePathsToTypedErrors() throws {
    let sessionID = SessionID(rawValue: "selected-unreadable")
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }
    let session = makeCodexSelectedTranscriptSession(id: sessionID, path: directoryURL.path)
    let useCase = LoadSelectedTranscriptUseCase(
        selectedTranscriptLoading: CodexSelectedTranscriptLoadingAdapter()
    )

    #expect(throws: SelectedTranscriptLoadingError.transcriptUnreadable(sessionID)) {
        try useCase.loadTranscript(for: session)
    }
}

private func makeCodexSelectedTranscriptSession(id: SessionID, path: String) -> SessionSummary {
    let sourceID = SessionSourceID(rawValue: "codex-fixture")
    return SessionSummary(
        id: id,
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex fixture",
            profileName: "Fixture"
        ),
        title: "Selected fixture",
        projectHint: CatalogProjectHint.unavailable,
        sessionPath: path,
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: 1, lastActivityEpochSeconds: 2),
        fileSize: CatalogFileSize(byteCount: 128),
        health: CatalogEntryHealth(parseStatus: .complete)
    )
}
