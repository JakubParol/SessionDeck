import Foundation
import SessionDeckCore

enum SourceProfileNavigationFixtureCatalog {
    static let cliSourceID = SessionSourceID(rawValue: "codex-cli")
    static let appSourceID = SessionSourceID(rawValue: "codex-app")
    static let automationSourceID = SessionSourceID(rawValue: "automation-runner")
    static let unknownSourceID = SessionSourceID(rawValue: "unknown-source-fixture")

    static func snapshot() -> CatalogSnapshot {
        CatalogSnapshot(
            refreshedAt: Date(timeIntervalSince1970: 1_770_400_000),
            sources: sources(),
            sessions: sessions()
        )
    }

    static func sources() -> [SessionSourceSummary] {
        [
            source(id: cliSourceID, displayName: "Codex"),
            source(id: appSourceID, displayName: "Codex"),
            source(id: automationSourceID, displayName: "Automation"),
            source(id: unknownSourceID, displayName: "Unknown Source"),
        ]
    }

    static func sessions() -> [SessionSummary] {
        [
            session(
                id: "cli-sessiondeck-default",
                sourceID: cliSourceID,
                sourceDisplayName: "Codex",
                profileName: "default",
                projectName: "SessionDeck",
                cwdPath: "/tmp/sessiondeck-fixtures/projects/SessionDeck",
                lastActivity: 50
            ),
            session(
                id: "cli-cracker-default",
                sourceID: cliSourceID,
                sourceDisplayName: "Codex",
                profileName: "default",
                projectName: "CrackerAi",
                cwdPath: "/tmp/sessiondeck-fixtures/projects/CrackerAi",
                lastActivity: 40
            ),
            session(
                id: "app-sessiondeck-viewer",
                sourceID: appSourceID,
                sourceDisplayName: "Codex",
                profileName: "viewer",
                projectName: "SessionDeck",
                cwdPath: "/tmp/sessiondeck-fixtures/projects/SessionDeck",
                lastActivity: 30
            ),
            session(
                id: "automation-sessiondeck",
                sourceID: automationSourceID,
                sourceDisplayName: "Automation",
                profileName: "nightly",
                projectName: "SessionDeck",
                cwdPath: "/tmp/sessiondeck-fixtures/projects/SessionDeck",
                lastActivity: 20
            ),
            session(
                id: "unknown-non-project",
                sourceID: unknownSourceID,
                sourceDisplayName: "",
                profileName: nil,
                projectName: nil,
                cwdPath: nil,
                lastActivity: 10,
                fallbackReasons: [.unknownSource]
            ),
        ]
    }

    private static func source(id: SessionSourceID, displayName: String) -> SessionSourceSummary {
        SessionSourceSummary(
            id: id,
            displayName: displayName,
            kind: .codex,
            locationDescription: "/tmp/sessiondeck-fixtures/sources/\(id.rawValue)",
            isEnabled: true,
            availability: .available,
            counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
        )
    }

    private static func session(
        id: String,
        sourceID: SessionSourceID,
        sourceDisplayName: String,
        profileName: String?,
        projectName: String?,
        cwdPath: String?,
        lastActivity: Int64,
        fallbackReasons: [CatalogSessionFallbackReason] = []
    ) -> SessionSummary {
        SessionSummary(
            id: SessionID(rawValue: id),
            sourceID: sourceID,
            sourceLabel: CatalogSourceLabel(
                sourceID: sourceDisplayName.isEmpty ? "" : sourceID.rawValue,
                displayName: sourceDisplayName,
                profileName: profileName
            ),
            title: "Fixture \(id)",
            projectHint: projectName.map {
                CatalogProjectHint(cwdPath: cwdPath, displayName: $0)
            } ?? .unavailable,
            sessionPath: "/tmp/sessiondeck-fixtures/sessions/\(id).jsonl",
            activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: lastActivity),
            fileSize: CatalogFileSize(byteCount: 128),
            metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: profileName),
            fallbackReasons: fallbackReasons,
            health: CatalogEntryHealth(parseStatus: .complete)
        )
    }
}
