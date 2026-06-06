import Foundation
import Testing

@Test("app shell view renders application-owned source health rows")
func appShellViewRendersApplicationOwnedSourceHealthRows() throws {
    let source = try String(
        contentsOf: repositoryRoot()
            .appending(path: "Sources/SessionDeckApp/Presentation/AppShellView.swift"),
        encoding: .utf8
    )

    #expect(source.contains("viewModel.sourceDiscoverySummary.sourceHealthRows.isEmpty == false"))
    #expect(source.contains("ForEach(viewModel.sourceDiscoverySummary.sourceHealthRows"))
    #expect(source.contains("sourceHealthIcon(for: row.severity)"))
    #expect(source.contains("Text(row.statusLabel)"))
    #expect(source.contains("Text(row.detail)"))
    #expect(source.contains("Text(row.location)"))
    #expect(!source.contains("FileManager.default"))
}

@Test("app shell renders application-owned monitoring health rows")
func appShellViewRendersApplicationOwnedMonitoringHealthRows() throws {
    let appShellSource = try String(
        contentsOf: repositoryRoot()
            .appending(path: "Sources/SessionDeckApp/Presentation/AppShellView.swift"),
        encoding: .utf8
    )
    let monitoringSource = try String(
        contentsOf: repositoryRoot()
            .appending(path: "Sources/SessionDeckApp/Presentation/AppShellMonitoringHealthView.swift"),
        encoding: .utf8
    )

    #expect(appShellSource.contains("AppShellMonitoringHealthView(summary: viewModel.monitoringHealthSummary)"))
    #expect(monitoringSource.contains("ForEach(summary.rows)"))
    #expect(monitoringSource.contains("Text(row.title)"))
    #expect(monitoringSource.contains("Text(row.detail)"))
    #expect(monitoringSource.contains("Text(diagnosticCode)"))
    #expect(!monitoringSource.contains("FileManager.default"))
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
