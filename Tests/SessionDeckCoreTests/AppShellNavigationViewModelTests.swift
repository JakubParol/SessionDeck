import Foundation
import Testing
@testable import SessionDeckCore

@Test("navigation tree exposes required stable top-level sections when empty")
func navigationTreeExposesRequiredStableTopLevelSectionsWhenEmpty() {
    let snapshot = CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_299_900),
        sources: [],
        sessions: []
    )

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)

    #expect(summary.sectionNodes.map(\.id) == [
        "all-chats",
        "projects",
        "non-project-chats",
        "sources",
        "recently-active",
        "diagnostics",
    ])
    #expect(summary.projectsNode.title == "Projects")
    #expect(summary.nonProjectChatsNode.title == "Non-project Chats")
    #expect(summary.sourcesNode.title == "Sources / Profiles")
    #expect(summary.recentlyActiveNode.title == "Recently Active")
    #expect(summary.sectionNodes.allSatisfy { $0.count == 0 })
}

@Test("navigation summary keeps problem sessions in all chats and diagnostic categories")
func navigationSummaryKeepsProblemSessionsVisibleInDiagnostics() {
    let snapshot = CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_300_000),
        sources: [navigationSource()],
        sessions: [
            navigationSession(id: "healthy"),
            navigationSession(
                id: "missing-metadata",
                health: CatalogEntryHealth(parseStatus: .missingMetadata)
            ),
            navigationSession(
                id: "permission-denied",
                health: CatalogEntryHealth(
                    parseStatus: .unreadable(reason: "Permission denied."),
                    diagnostics: [
                        CatalogEntryDiagnostic(
                            code: .permissionDenied,
                            severity: .error,
                            message: "Transcript file permission denied."
                        ),
                    ]
                )
            ),
            navigationSession(
                id: "malformed-metadata",
                health: CatalogEntryHealth(
                    parseStatus: .malformed(reason: "Malformed catalog metadata.")
                )
            ),
            navigationSession(
                id: "parse-warning",
                health: CatalogEntryHealth(
                    parseStatus: .complete,
                    diagnostics: [
                        CatalogEntryDiagnostic(
                            code: .unknownEventShape,
                            severity: .warning,
                            message: "Unknown transcript event shape."
                        ),
                    ]
                )
            ),
            navigationSession(
                id: "unknown-source",
                fallbackReasons: [.unknownSource]
            ),
            navigationSession(
                id: "ambiguous-project",
                fallbackReasons: [.ambiguousProject]
            ),
            navigationSession(
                id: "missing-path",
                sessionPath: "",
                fallbackReasons: [.missingPath]
            ),
        ]
    )

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)
    let problemSessions = summary.problemSessionsNode
    let countsByCategory = Dictionary(
        uniqueKeysWithValues: problemSessions.children.compactMap { node in
            node.problemCategory.map { ($0, node.count) }
        }
    )

    #expect(summary.allChatsNode.count == 8)
    #expect(summary.allChatsNode.sessionIDs.map(\.rawValue).contains("permission-denied"))
    #expect(problemSessions.title == "Problem Sessions")
    #expect(problemSessions.count == 7)
    #expect(countsByCategory[.missingPath] == 1)
    #expect(countsByCategory[.permissionDenied] == 1)
    #expect(countsByCategory[.missingMetadata] == 1)
    #expect(countsByCategory[.malformedMetadata] == 1)
    #expect(countsByCategory[.parseWarning] == 1)
    #expect(countsByCategory[.unknownSource] == 1)
    #expect(countsByCategory[.ambiguousProject] == 1)
}

@Test("navigation nodes expose concise count labels for app shell rendering")
func navigationNodesExposeConciseCountLabels() {
    let snapshot = CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_300_100),
        sources: [navigationSource()],
        sessions: [
            navigationSession(id: "healthy"),
            navigationSession(id: "missing-path", sessionPath: "", fallbackReasons: [.missingPath]),
        ]
    )

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)

    #expect(summary.allChatsNode.countLabel == "2 sessions")
    #expect(summary.problemSessionsNode.countLabel == "1 session")
    #expect(summary.problemSessionsNode.children.first?.countLabel == "1 session")
}

@Test("navigation maps unreadable permission diagnostics to permission denied")
func navigationMapsUnreadablePermissionDiagnosticsToPermissionDenied() {
    let snapshot = CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_300_200),
        sources: [navigationSource()],
        sessions: [
            navigationSession(
                id: "candidate-permission",
                health: CatalogEntryHealth(
                    parseStatus: .unreadable(reason: "Candidate transcript file could not be read."),
                    diagnostics: [
                        CatalogEntryDiagnostic(
                            code: .unreadableFile,
                            severity: .error,
                            message: "Permission denied while reading candidate transcript."
                        ),
                    ]
                )
            ),
        ]
    )

    let categories = AppShellNavigationSummary.make(snapshot: snapshot)
        .problemSessionsNode
        .children
        .compactMap(\.problemCategory)

    #expect(categories == [.permissionDenied])
}

private func navigationSource() -> SessionSourceSummary {
    SessionSourceSummary(
        id: SessionSourceID(rawValue: "codex-navigation"),
        displayName: "Codex navigation",
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 8)
    )
}

private func navigationSession(
    id: String,
    sessionPath: String? = nil,
    fallbackReasons: [CatalogSessionFallbackReason] = [],
    health: CatalogEntryHealth = CatalogEntryHealth(parseStatus: .complete)
) -> SessionSummary {
    let sourceID = SessionSourceID(rawValue: "codex-navigation")
    return SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: sourceID,
        sourceLabel: CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex navigation",
            profileName: nil
        ),
        title: "Session \(id)",
        projectHint: CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
        sessionPath: sessionPath ?? "/tmp/sessiondeck/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: 1),
        fileSize: CatalogFileSize(byteCount: 128),
        fallbackReasons: fallbackReasons,
        health: health
    )
}
