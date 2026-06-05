import Foundation
import Testing

@Test("transcript detail view renders application-owned diagnostic rows")
func transcriptDetailViewRendersApplicationOwnedDiagnosticRows() throws {
    let source = try String(contentsOf: transcriptDetailViewPath(), encoding: .utf8)

    #expect(source.contains("state.diagnosticRows"))
    #expect(source.contains("diagnosticIcon(for: row.severity)"))
    #expect(!source.contains("CodexTranscriptJSONEvent"))
    #expect(!source.contains("JSONSerialization"))
    #expect(!source.contains("FileHandle"))
}

private func transcriptDetailViewPath() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/SessionDeckApp/Presentation/AppShellTranscriptDetailView.swift")
}
