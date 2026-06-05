import Foundation
import Testing
@testable import SessionDeckCore

@Test("Codex decoder bounds large tool output while preserving total size metadata")
func codexDecoderBoundsLargeToolOutputWhilePreservingTotalSizeMetadata() throws {
    let result = try decodeFixture(.boundedReadTruncated, sessionID: "bounded-output-session")
    let segment = try #require(result.orderedSegments.first)
    let metadata = try #require(segment.toolMetadata)

    #expect(segment.kind == .toolOutput(callID: "call_synthetic_bounded_001"))
    #expect(metadata.bodyAvailability == .truncated)
    #expect(segment.text.count == 240)
    #expect(metadata.characterCount == 619)
    #expect(metadata.byteCount == 619)
    #expect(metadata.lineCount == 1)
    #expect(segment.text.hasPrefix("synthetic bounded-read payload"))
    let fullCount = try fullOutputCharacterCount()
    #expect(segment.text.count < fullCount)
}

@Test("Codex decoder leaves small complete tool output untruncated")
func codexDecoderLeavesSmallCompleteToolOutputUntruncated() throws {
    let result = try decodeFixture(.toolActivityMixed, sessionID: "small-output-session")
    let segment = try #require(result.orderedSegments.first { $0.kind == .toolOutput(callID: "call_tool_activity_001") })
    let metadata = try #require(segment.toolMetadata)

    #expect(segment.text == "synthetic tool output")
    #expect(metadata.bodyAvailability == .available)
    #expect(metadata.characterCount == 21)
    #expect(metadata.byteCount == 21)
    #expect(metadata.lineCount == 1)
}

@Test("Codex decoder clamps negative output bounds to empty truncated detail")
func codexDecoderClampsNegativeOutputBoundsToEmptyTruncatedDetail() throws {
    let result = try decodeFixture(
        .boundedReadTruncated,
        sessionID: "negative-bound-session",
        maximumToolBodyCharacters: -1
    )
    let segment = try #require(result.orderedSegments.first)
    let metadata = try #require(segment.toolMetadata)

    #expect(segment.text == "")
    #expect(metadata.bodyAvailability == .truncated)
    #expect(metadata.characterCount == 619)
}

private func decodeFixture(
    _ fixtureID: CodexTranscriptFixtureID,
    sessionID rawSessionID: String,
    maximumToolBodyCharacters: Int = 240
) throws -> TranscriptDecodeResult {
    let sessionID = SessionID(rawValue: rawSessionID)
    let file = CodexTranscriptFile(
        sessionID: sessionID,
        fileURL: try CodexTranscriptFixtureManifest.fixtureURL(for: fixtureID),
        source: TranscriptSegmentSourceReference(
            sourceID: SessionSourceID(rawValue: "codex-fixture"),
            relativePath: try CodexTranscriptFixtureManifest.fixture(for: fixtureID).filename,
            lineNumber: nil
        ),
        fallbackTitle: "Fallback title"
    )

    return try CodexTranscriptDecodingAdapter(
        files: [file],
        maximumToolBodyCharacters: maximumToolBodyCharacters
    ).loadTranscript(sessionID: sessionID)
}

private func fullOutputCharacterCount() throws -> Int {
    let fixture = try CodexTranscriptFixtureManifest.readFixture(.boundedReadTruncated)
    let outputPrefix = "\"output\":\""
    let outputSuffix = "\"}}"
    let line = try #require(fixture.split(separator: "\n").last.map(String.init))
    let outputStart = try #require(line.range(of: outputPrefix)?.upperBound)
    let outputEnd = try #require(line.range(of: outputSuffix, options: .backwards)?.lowerBound)
    return String(line[outputStart..<outputEnd]).count
}
