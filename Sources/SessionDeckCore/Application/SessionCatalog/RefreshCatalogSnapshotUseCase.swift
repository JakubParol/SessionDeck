import Foundation

public protocol CatalogRefreshClock: Sendable {
    func now() -> Date
}

public struct SystemCatalogRefreshClock: CatalogRefreshClock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public protocol CatalogMetadataExtractionPort: Sendable {
    func extractSessions(source: SessionSourceSummary) throws -> CatalogSourceExtractionResult
}

public struct CatalogSourceExtractionResult: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let sessions: [SessionSummary]
    public let warnings: [CatalogSnapshotSourceWarning]

    public init(
        sourceID: SessionSourceID,
        sessions: [SessionSummary],
        warnings: [CatalogSnapshotSourceWarning] = []
    ) {
        self.sourceID = sourceID
        self.sessions = sessions
        self.warnings = warnings
    }
}

public struct CatalogSnapshotCounts: Equatable, Sendable {
    public let totalEntries: Int
    public let healthyEntries: Int
    public let diagnosticEntries: Int

    public init(totalEntries: Int, healthyEntries: Int, diagnosticEntries: Int) {
        self.totalEntries = totalEntries
        self.healthyEntries = healthyEntries
        self.diagnosticEntries = diagnosticEntries
    }
}

public enum CatalogSnapshotDiagnosticCode: String, Equatable, Sendable {
    case duplicateSessionIdentity = "catalog_snapshot.duplicate_session_identity"
}

public enum CatalogSnapshotDiagnosticSeverity: Equatable, Sendable {
    case warning
    case error
}

public struct CatalogSnapshotDiagnostic: Equatable, Sendable {
    public let code: CatalogSnapshotDiagnosticCode
    public let severity: CatalogSnapshotDiagnosticSeverity
    public let identity: CatalogSessionIdentity
    public let sessionIDs: [SessionID]
    public let message: String

    public init(
        code: CatalogSnapshotDiagnosticCode,
        severity: CatalogSnapshotDiagnosticSeverity,
        identity: CatalogSessionIdentity,
        sessionIDs: [SessionID],
        message: String
    ) {
        self.code = code
        self.severity = severity
        self.identity = identity
        self.sessionIDs = sessionIDs
        self.message = message
    }
}

public struct CatalogSnapshotSourceWarning: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let displayName: String
    public let message: String

    public init(sourceID: SessionSourceID, displayName: String, message: String) {
        self.sourceID = sourceID
        self.displayName = displayName
        self.message = message
    }
}

public struct CatalogSnapshotRefreshError: Equatable, Sendable {
    public let sourceID: SessionSourceID
    public let displayName: String
    public let message: String

    public init(sourceID: SessionSourceID, displayName: String, message: String) {
        self.sourceID = sourceID
        self.displayName = displayName
        self.message = message
    }
}

public struct CatalogSnapshot: Equatable, Sendable {
    public let refreshedAt: Date
    public let sources: [SessionSourceSummary]
    public let sessions: [SessionSummary]
    public let counts: CatalogSnapshotCounts
    public let diagnostics: [CatalogSnapshotDiagnostic]
    public let sourceWarnings: [CatalogSnapshotSourceWarning]
    public let refreshErrors: [CatalogSnapshotRefreshError]

    public init(
        refreshedAt: Date,
        sources: [SessionSourceSummary],
        sessions: [SessionSummary],
        diagnostics: [CatalogSnapshotDiagnostic] = [],
        sourceWarnings: [CatalogSnapshotSourceWarning] = [],
        refreshErrors: [CatalogSnapshotRefreshError] = []
    ) {
        self.refreshedAt = refreshedAt
        self.sources = sources
        self.sessions = sessions
        self.diagnostics = diagnostics
        self.counts = CatalogSnapshotCounts(
            totalEntries: sessions.count,
            healthyEntries: sessions.filter { $0.isHealthyCatalogEntry && diagnostics.doesNotReference($0.id) }.count,
            diagnosticEntries: sessions.filter { $0.isHealthyCatalogEntry == false || diagnostics.references($0.id) }.count
        )
        self.sourceWarnings = sourceWarnings
        self.refreshErrors = refreshErrors
    }
}

public struct RefreshCatalogSnapshotUseCase: Sendable {
    private let sourceDiscovery: any SourceDiscoveryPort
    private let metadataExtraction: any CatalogMetadataExtractionPort
    private let clock: any CatalogRefreshClock

    public init(
        sourceDiscovery: any SourceDiscoveryPort,
        metadataExtraction: any CatalogMetadataExtractionPort,
        clock: any CatalogRefreshClock = SystemCatalogRefreshClock()
    ) {
        self.sourceDiscovery = sourceDiscovery
        self.metadataExtraction = metadataExtraction
        self.clock = clock
    }

    public func refreshSnapshot() throws -> CatalogSnapshot {
        let sources = try sourceDiscovery.discoverSources()
        var sessions: [SessionSummary] = []
        var sourceWarnings = sources.compactMap(\.catalogSnapshotWarning)
        var refreshErrors: [CatalogSnapshotRefreshError] = []

        for source in sources where source.availability == .available && source.isEnabled {
            do {
                let result = try metadataExtraction.extractSessions(source: source)
                sessions.append(contentsOf: result.sessions)
                sourceWarnings.append(contentsOf: result.warnings)
            } catch {
                refreshErrors.append(
                    CatalogSnapshotRefreshError(
                        sourceID: source.id,
                        displayName: source.displayName,
                        message: error.catalogSnapshotMessage
                    )
                )
            }
        }

        return CatalogSnapshot(
            refreshedAt: clock.now(),
            sources: sources,
            sessions: SessionCatalogOrdering.sort(sessions),
            diagnostics: Self.duplicateIdentityDiagnostics(for: sessions),
            sourceWarnings: sourceWarnings,
            refreshErrors: refreshErrors
        )
    }

    private static func duplicateIdentityDiagnostics(for sessions: [SessionSummary]) -> [CatalogSnapshotDiagnostic] {
        Dictionary(grouping: sessions, by: \.identity)
            .filter { $0.value.count > 1 }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { identity, sessions in
                let sessionIDs = sessions
                    .map(\.id)
                    .sorted { $0.rawValue < $1.rawValue }

                return CatalogSnapshotDiagnostic(
                    code: .duplicateSessionIdentity,
                    severity: .warning,
                    identity: identity,
                    sessionIDs: sessionIDs,
                    message: "Duplicate session identity \(identity.rawValue) appears in \(sessionIDs.count) catalog entries."
                )
            }
    }
}

private extension Error {
    var catalogSnapshotMessage: String {
        if let localizedError = self as? LocalizedError,
           let errorDescription = localizedError.errorDescription,
           errorDescription.isEmpty == false {
            return errorDescription
        }

        return String(describing: self)
    }
}

private extension SessionSummary {
    var isHealthyCatalogEntry: Bool {
        health.parseStatus == .complete && health.diagnostics.isEmpty
    }
}

private extension [CatalogSnapshotDiagnostic] {
    func references(_ sessionID: SessionID) -> Bool {
        contains { $0.sessionIDs.contains(sessionID) }
    }

    func doesNotReference(_ sessionID: SessionID) -> Bool {
        references(sessionID) == false
    }
}

private extension SessionSourceSummary {
    var catalogSnapshotWarning: CatalogSnapshotSourceWarning? {
        guard let diagnostic else {
            return nil
        }

        return CatalogSnapshotSourceWarning(
            sourceID: id,
            displayName: displayName,
            message: diagnostic.message
        )
    }
}
