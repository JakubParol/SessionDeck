import Testing
@testable import SessionDeckCore

@Test("bounded output fixture coverage represents complete truncated missing and unsupported cases")
func boundedOutputFixtureCoverageRepresentsCompleteTruncatedMissingAndUnsupportedCases() throws {
    let fixtures = CodexTranscriptFixtureManifest.fixtures
    let fixtureCategories = Dictionary(uniqueKeysWithValues: fixtures.map { ($0.id, $0.categories) })

    #expect(fixtureCategories[.toolActivityMixed]?.contains("tool-output") == true)
    #expect(fixtureCategories[.boundedReadTruncated]?.contains("large-output") == true)
    #expect(fixtureCategories[.toolPayloadDegraded]?.contains("missing-metadata") == true)
    #expect(fixtureCategories[.toolPayloadDegraded]?.contains("unknown-tool-payload") == true)
    #expect(fixtureCategories[.malformedLine]?.contains("malformed-line") == true)
    #expect(fixtureCategories[.unknownEvent]?.contains("unknown-event") == true)
}

@Test("bounded output fixture row exposes local partial diagnostic")
func boundedOutputFixtureRowExposesLocalPartialDiagnostic() throws {
    let sessionID = SessionID(rawValue: "bounded-fixture-row")
    let file = CodexTranscriptFile(
        sessionID: sessionID,
        fileURL: try CodexTranscriptFixtureManifest.fixtureURL(for: .boundedReadTruncated),
        source: TranscriptSegmentSourceReference(
            sourceID: SessionSourceID(rawValue: "codex-fixture"),
            relativePath: try CodexTranscriptFixtureManifest.fixture(for: .boundedReadTruncated).filename,
            lineNumber: nil
        ),
        fallbackTitle: "Fallback title"
    )
    let result = try CodexTranscriptDecodingAdapter(files: [file]).loadTranscript(sessionID: sessionID)
    let row = try #require(result.orderedSegments.first.map(AppShellTranscriptSegmentRow.make(segment:)))
    let presentation = try #require(row.toolPresentation)

    #expect(presentation.detailSummary == "Showing 240 of 619 characters")
    #expect(presentation.diagnosticMessages == [
        "Partial output shown: configured display bound reached.",
    ])
    #expect(row.text == "Tool output")
}
