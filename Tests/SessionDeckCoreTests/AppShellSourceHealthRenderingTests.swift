import Foundation
import Testing

@Test("app shell view renders application-owned diagnostics summary")
func appShellViewRendersApplicationOwnedDiagnosticsSummary() throws {
    let source = try String(
        contentsOf: repositoryRoot()
            .appending(path: "Sources/SessionDeckApp/Presentation/AppShellView.swift"),
        encoding: .utf8
    )
    let diagnosticsSource = try String(
        contentsOf: repositoryRoot()
            .appending(path: "Sources/SessionDeckApp/Presentation/AppShellDiagnosticsSummaryView.swift"),
        encoding: .utf8
    )

    #expect(source.contains("AppShellDiagnosticsSummaryView(summary: viewModel.diagnosticsSummary)"))
    #expect(diagnosticsSource.contains("ForEach(summary.rows)"))
    #expect(diagnosticsSource.contains("Text(row.title)"))
    #expect(diagnosticsSource.contains("Text(row.detail)"))
    #expect(diagnosticsSource.contains("Text(row.recoveryGuidance)"))
    #expect(diagnosticsSource.contains("Text(diagnosticCode)"))
    #expect(!source.contains("FileManager.default"))
}

@Test("app shell diagnostics summary replaces separate monitoring and source diagnostic lists")
func appShellDiagnosticsSummaryReplacesSeparateMonitoringAndSourceDiagnosticLists() throws {
    let source = try String(
        contentsOf: repositoryRoot()
            .appending(path: "Sources/SessionDeckApp/Presentation/AppShellView.swift"),
        encoding: .utf8
    )

    #expect(!source.contains("AppShellMonitoringHealthView(summary: viewModel.monitoringHealthSummary)"))
    #expect(!source.contains("sourceHealthRows"))
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
