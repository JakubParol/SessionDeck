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

@Test("selected Codex transcript adapter loads generated large transcript with bounded output")
func selectedCodexTranscriptAdapterLoadsGeneratedLargeTranscriptWithBoundedOutput() throws {
    let fixture = try makeSelectedLargeTranscriptFixture(name: "selected-large")
    defer {
        try? fixture.store.cleanup()
        try? fixture.cleanupParent()
    }
    let source = try fixture.store.source(label: "codex-cli", profile: "selected-large")
    let sessionFile = try fixture.store.generateLargeProjectTranscript(
        source: source,
        sessionID: "selected-large-session",
        projectName: "SelectedLargeProject",
        options: GeneratedCodexTranscriptOptions(eventCount: 32, toolOutputByteCount: 20_000)
    )
    try fixture.store.appendGeneratedLine(.assistantMessage(index: 999), to: sessionFile)
    let session = makeCodexSelectedTranscriptSession(
        id: SessionID(rawValue: sessionFile.sessionID),
        path: sessionFile.url.path
    )
    let useCase = LoadSelectedTranscriptUseCase(
        selectedTranscriptLoading: CodexSelectedTranscriptLoadingAdapter()
    )

    let readModel = try useCase.loadTranscript(for: session)
    let orderedSegments = readModel.segments
    let toolOutput = try #require(orderedSegments.first { segment in
        segment.kind == .toolOutput(callID: "call-large-output")
    })
    let toolMetadata = try #require(toolOutput.toolMetadata)
    let toolOutputIndex = try #require(orderedSegments.firstIndex(of: toolOutput))

    #expect(readModel.title == "Synthetic SelectedLargeProject Large Transcript")
    #expect(orderedSegments.count == 33)
    #expect(orderedSegments[toolOutputIndex - 1].text == "Synthetic generated assistant event 30")
    #expect(orderedSegments[toolOutputIndex + 1].text == "Synthetic generated assistant event 999")
    #expect(toolOutput.text.count == CodexTranscriptDecodingAdapter.defaultMaximumToolBodyCharacters)
    #expect(toolMetadata.bodyAvailability == .truncated)
    #expect(toolMetadata.characterCount == 20_000)
    #expect(toolMetadata.byteCount == 20_000)

    let row = AppShellTranscriptSegmentRow.make(segment: toolOutput)
    let toolPresentation = try #require(row.toolPresentation)
    #expect(row.text == "Tool output")
    #expect(toolPresentation.isCollapsedByDefault)
    #expect(toolPresentation.expandedText == toolOutput.text)
    #expect(toolPresentation.expandedText.count == CodexTranscriptDecodingAdapter.defaultMaximumToolBodyCharacters)
    #expect(toolPresentation.detailSummary == "Showing 240 of 20,000 characters")
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

private func makeSelectedLargeTranscriptFixture(name: String) throws -> SelectedLargeTranscriptFixture {
    let parentDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("SessionDeckSelectedLargeTranscriptTests", isDirectory: true)
        .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    let pathGuard = FixturePathGuard(
        forbiddenHomeDirectories: [URL(fileURLWithPath: "/Users/jakubparol", isDirectory: true)]
    )
    let factory = TempCodexSessionStoreFactory(parentDirectory: parentDirectory, pathGuard: pathGuard)
    let store = try factory.makeStore(name: "store")

    return SelectedLargeTranscriptFixture(parentDirectory: parentDirectory, store: store)
}

private struct SelectedLargeTranscriptFixture {
    let parentDirectory: URL
    let store: TempCodexSessionStore

    func cleanupParent() throws {
        if FileManager.default.fileExists(atPath: parentDirectory.path) {
            try FileManager.default.removeItem(at: parentDirectory)
        }
    }
}
