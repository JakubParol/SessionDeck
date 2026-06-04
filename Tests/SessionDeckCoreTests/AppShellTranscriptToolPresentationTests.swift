import Testing
@testable import SessionDeckCore

@Test("selected transcript tool rows expose collapsed default metadata without raw output text")
func selectedTranscriptToolRowsExposeCollapsedDefaultMetadata() {
    let row = AppShellTranscriptSegmentRow.make(
        segment: TranscriptSegment(
            id: "tool-output",
            kind: .toolOutput(callID: "call-1"),
            text: "large raw output that should stay hidden while collapsed",
            order: TranscriptSegmentOrder(index: 0),
            source: transcriptToolSource(lineNumber: 4),
            timestampDescription: nil,
            toolMetadata: TranscriptToolMetadata(
                displayLabel: "exec_command",
                status: "failed",
                bodyAvailability: .available,
                characterCount: 54,
                byteCount: 54,
                lineCount: 1
            )
        )
    )

    #expect(row.text == "Tool output from exec_command")
    #expect(row.toolPresentation == AppShellTranscriptToolPresentation(
        displayLabel: "exec_command",
        metadataSummary: "failed - 54 characters - 1 line",
        expandedText: "large raw output that should stay hidden while collapsed",
        isCollapsedByDefault: true
    ))
}

private func transcriptToolSource(lineNumber: Int) -> TranscriptSegmentSourceReference {
    TranscriptSegmentSourceReference(
        sourceID: SessionSourceID(rawValue: "fixture"),
        relativePath: "selected-session.jsonl",
        lineNumber: lineNumber
    )
}
