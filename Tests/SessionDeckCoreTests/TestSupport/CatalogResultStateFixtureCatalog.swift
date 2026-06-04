import Foundation
import SessionDeckCore

enum CatalogResultStateFixtureCatalog {
    static let sourceID = SessionSourceID(rawValue: "catalog-result-state-source")
    static let noMatchQuery = CatalogQueryRequest(searchText: "not-present")

    static var emptySnapshot: CatalogSnapshot {
        snapshot(sessions: [])
    }

    static var healthySnapshot: CatalogSnapshot {
        snapshot(sessions: [
            session(id: "healthy-session", title: "Healthy Session")
        ])
    }

    static var warningSnapshot: CatalogSnapshot {
        snapshot(
            sessions: [
                session(id: "warning-session", title: "Warning Session")
            ],
            sourceWarnings: [
                CatalogSnapshotSourceWarning(
                    sourceID: sourceID,
                    displayName: "Synthetic Catalog Result State",
                    message: "Source metadata is incomplete."
                )
            ]
        )
    }

    static var failureSnapshot: CatalogSnapshot {
        snapshot(
            sessions: [],
            refreshErrors: [
                CatalogSnapshotRefreshError(
                    sourceID: sourceID,
                    displayName: "Synthetic Catalog Result State",
                    message: "Catalog extraction failed."
                )
            ]
        )
    }

    static var mixedSnapshot: CatalogSnapshot {
        snapshot(
            sessions: [
                session(id: "healthy-mixed-session", title: "Healthy Mixed Session")
            ],
            refreshErrors: [
                CatalogSnapshotRefreshError(
                    sourceID: sourceID,
                    displayName: "Synthetic Catalog Result State",
                    message: "Catalog extraction failed."
                )
            ]
        )
    }

    private static func snapshot(
        sessions: [SessionSummary],
        sourceWarnings: [CatalogSnapshotSourceWarning] = [],
        refreshErrors: [CatalogSnapshotRefreshError] = []
    ) -> CatalogSnapshot {
        CatalogSnapshot(
            refreshedAt: Date(timeIntervalSince1970: 1_770_200_300),
            sources: [source],
            sessions: sessions,
            sourceWarnings: sourceWarnings,
            refreshErrors: refreshErrors
        )
    }

    private static var source: SessionSourceSummary {
        SessionSourceSummary(
            id: sourceID,
            displayName: "Synthetic Catalog Result State",
            kind: .codex,
            locationDescription: "Synthetic fixture source",
            isEnabled: true,
            availability: .available,
            counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 1)
        )
    }

    private static func session(id: String, title: String) -> SessionSummary {
        SessionSummary(
            id: SessionID(rawValue: id),
            identity: CatalogSessionIdentity(rawValue: id),
            sourceID: sourceID,
            sourceLabel: CatalogSourceLabel(
                sourceID: sourceID.rawValue,
                displayName: "Synthetic Catalog Result State",
                profileName: "fixture"
            ),
            title: title,
            projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
            sessionPath: "/tmp/sessiondeck/\(id).jsonl",
            activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: 1_770_200_300),
            fileSize: CatalogFileSize(byteCount: 512),
            metadata: CatalogSessionMetadata(modelName: "gpt-fixture", agentProfileName: "fixture"),
            health: CatalogEntryHealth(parseStatus: .complete)
        )
    }
}
