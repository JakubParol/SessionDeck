import Foundation
import Testing

@Test("tool transcript row renders application-owned bounded details and diagnostics")
func toolTranscriptRowRendersApplicationOwnedBoundedDetailsAndDiagnostics() throws {
    let source = try String(contentsOf: toolTranscriptRowViewPath(), encoding: .utf8)

    #expect(source.contains("presentation.detailSummary"))
    #expect(source.contains("presentation.diagnosticMessages"))
    #expect(source.contains("ForEach(presentation.diagnosticMessages"))
    #expect(source.contains("systemImage: \"exclamationmark.triangle\""))
}

private func toolTranscriptRowViewPath() -> URL {
    repositoryRoot()
        .appending(path: "Sources/SessionDeckApp/Presentation/AppShellToolTranscriptRowView.swift")
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
