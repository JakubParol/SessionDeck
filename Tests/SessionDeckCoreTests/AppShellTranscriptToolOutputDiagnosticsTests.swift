import Testing
@testable import SessionDeckCore

@Test("tool output presentation reports displayed and total size")
func toolOutputPresentationReportsDisplayedAndTotalSize() throws {
    let row = AppShellTranscriptSegmentRow.make(
        segment: toolOutputSegment(
            text: "synthetic output",
            availability: .available,
            characterCount: 16,
            byteCount: 16,
            lineCount: 1
        )
    )

    let presentation = try #require(row.toolPresentation)
    #expect(presentation.detailSummary == "Showing 16 of 16 characters")
    #expect(presentation.diagnosticMessages.isEmpty)
}

@Test("truncated tool output presentation reports partial bounded content")
func truncatedToolOutputPresentationReportsPartialBoundedContent() throws {
    let row = AppShellTranscriptSegmentRow.make(
        segment: toolOutputSegment(
            text: "bounded preview",
            availability: .truncated,
            characterCount: 2_048,
            byteCount: 2_048,
            lineCount: 80
        )
    )

    let presentation = try #require(row.toolPresentation)
    #expect(presentation.detailSummary == "Showing 15 of 2,048 characters")
    #expect(presentation.diagnosticMessages == [
        "Partial output shown: configured display bound reached.",
    ])
}

@Test("tool output presentation does not invent unknown total size")
func toolOutputPresentationDoesNotInventUnknownTotalSize() throws {
    let row = AppShellTranscriptSegmentRow.make(
        segment: toolOutputSegment(
            text: "bounded preview",
            availability: .available,
            characterCount: nil,
            byteCount: nil,
            lineCount: nil
        )
    )

    let presentation = try #require(row.toolPresentation)
    #expect(presentation.detailSummary == "Showing bounded output; total size unknown")
    #expect(presentation.diagnosticMessages == [
        "Output size metadata unavailable.",
    ])
}

@Test("omitted tool output presentation exposes unavailable body diagnostic")
func omittedToolOutputPresentationExposesUnavailableBodyDiagnostic() throws {
    let row = AppShellTranscriptSegmentRow.make(
        segment: toolOutputSegment(
            text: "Tool output payload unavailable.",
            availability: .omitted,
            characterCount: nil,
            byteCount: nil,
            lineCount: nil
        )
    )

    let presentation = try #require(row.toolPresentation)
    #expect(presentation.detailSummary == "Tool output body unavailable")
    #expect(presentation.diagnosticMessages == [
        "Tool output body unavailable.",
        "Output size metadata unavailable.",
    ])
}

private func toolOutputSegment(
    text: String,
    availability: TranscriptToolBodyAvailability,
    characterCount: Int?,
    byteCount: Int?,
    lineCount: Int?
) -> TranscriptSegment {
    TranscriptSegment(
        id: "tool-output-\(availability)",
        kind: .toolOutput(callID: "call-1"),
        text: text,
        order: TranscriptSegmentOrder(index: 0),
        source: TranscriptSegmentSourceReference(
            sourceID: SessionSourceID(rawValue: "fixture"),
            relativePath: "tool-output.jsonl",
            lineNumber: 2
        ),
        timestampDescription: nil,
        toolMetadata: TranscriptToolMetadata(
            displayLabel: "exec_command",
            status: nil,
            bodyAvailability: availability,
            characterCount: characterCount,
            byteCount: byteCount,
            lineCount: lineCount
        )
    )
}
