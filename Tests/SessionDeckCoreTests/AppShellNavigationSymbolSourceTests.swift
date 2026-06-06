import Foundation
import Testing

@Test("navigation view avoids unavailable diagnostic document symbol")
func navigationViewAvoidsUnavailableDiagnosticDocumentSymbol() throws {
    let source = try String(contentsOf: appShellNavigationViewPath(), encoding: .utf8)

    #expect(!source.contains("doc.badge.exclamationmark"))
    #expect(source.contains("exclamationmark.triangle"))
}

private func appShellNavigationViewPath() -> URL {
    repositoryRoot()
        .appending(path: "Sources/SessionDeckApp/Presentation/AppShellNavigationView.swift")
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
