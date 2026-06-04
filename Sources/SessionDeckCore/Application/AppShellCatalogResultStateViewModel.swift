import Foundation

public enum AppShellCatalogResultState: Equatable, Sendable {
    case notRun
    case empty
    case matches
    case noMatches
    case warning
    case failure
}

public struct AppShellCatalogDiagnosticSummary: Equatable, Sendable {
    public static let none = AppShellCatalogDiagnosticSummary(
        entryDiagnosticCount: 0,
        sourceWarningCount: 0,
        sourceFailureCount: 0,
        primaryMessage: nil
    )

    public let entryDiagnosticCount: Int
    public let sourceWarningCount: Int
    public let sourceFailureCount: Int
    public let primaryMessage: String?

    public init(
        entryDiagnosticCount: Int,
        sourceWarningCount: Int,
        sourceFailureCount: Int,
        primaryMessage: String?
    ) {
        self.entryDiagnosticCount = entryDiagnosticCount
        self.sourceWarningCount = sourceWarningCount
        self.sourceFailureCount = sourceFailureCount
        self.primaryMessage = primaryMessage
    }

    public var hasDiagnostics: Bool {
        entryDiagnosticCount > 0 || sourceWarningCount > 0 || sourceFailureCount > 0
    }
}

public struct AppShellCatalogEmptyState: Equatable, Sendable {
    public let title: String
    public let detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }
}
