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

@Test("navigation tree groups populated catalog sessions by project source and recency")
func navigationTreeGroupsPopulatedCatalogSessionsByProjectSourceAndRecency() {
    let codexSourceID = SessionSourceID(rawValue: "codex-local")
    let hermesSourceID = SessionSourceID(rawValue: "hermes-local")
    let codexLabel = CatalogSourceLabel(
        sourceID: codexSourceID.rawValue,
        displayName: "Codex",
        profileName: "Naomi"
    )
    let hermesLabel = CatalogSourceLabel(
        sourceID: hermesSourceID.rawValue,
        displayName: "Hermes",
        profileName: "Jim"
    )
    let snapshot = CatalogSnapshot(
        refreshedAt: Date(timeIntervalSince1970: 1_770_300_050),
        sources: [
            navigationSource(id: codexSourceID, displayName: "Codex"),
            navigationSource(id: hermesSourceID, displayName: "Hermes"),
        ],
        sessions: [
            navigationSession(
                id: "alpha-new",
                sourceID: codexSourceID,
                sourceLabel: codexLabel,
                projectHint: CatalogProjectHint(cwdPath: "/tmp/work/Alpha", displayName: "Alpha"),
                lastActivity: 30
            ),
            navigationSession(
                id: "alpha-old",
                sourceID: codexSourceID,
                sourceLabel: codexLabel,
                projectHint: CatalogProjectHint(cwdPath: "/tmp/work/Alpha", displayName: "Alpha"),
                lastActivity: 10
            ),
            navigationSession(
                id: "loose-chat",
                sourceID: codexSourceID,
                sourceLabel: codexLabel,
                projectHint: .unavailable,
                lastActivity: 20
            ),
            navigationSession(
                id: "beta-chat",
                sourceID: hermesSourceID,
                sourceLabel: hermesLabel,
                projectHint: CatalogProjectHint(cwdPath: "/tmp/work/Beta", displayName: "Beta"),
                lastActivity: 40
            ),
        ]
    )

    let summary = AppShellNavigationSummary.make(snapshot: snapshot)

    #expect(summary.projectsNode.count == 3)
    #expect(summary.projectsNode.children.map(\.title) == ["Alpha", "Beta"])
    #expect(summary.projectsNode.children.map(\.count) == [2, 1])
    #expect(summary.nonProjectChatsNode.count == 1)
    #expect(summary.nonProjectChatsNode.sessionIDs.map(\.rawValue) == ["loose-chat"])
    #expect(summary.sourcesNode.count == 4)
    #expect(summary.sourcesNode.children.map(\.title) == ["Codex", "Hermes"])
    #expect(summary.sourcesNode.children.map(\.count) == [3, 1])
    #expect(summary.sourcesNode.children.flatMap(\.children).map(\.title) == ["Naomi", "Jim"])
    #expect(summary.sourcesNode.children.flatMap(\.children).map(\.count) == [3, 1])
    #expect(summary.recentlyActiveNode.sessionIDs.map(\.rawValue) == [
        "beta-chat",
        "alpha-new",
        "loose-chat",
        "alpha-old",
    ])
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

@Test("navigation nodes expose catalog selection scopes and source profile metadata")
func navigationNodesExposeCatalogSelectionScopesAndSourceProfileMetadata() {
    let sourceID = SessionSourceID(rawValue: "codex-source")
    let sourceMetadata = SourceProfileSourceNavigationMetadata(
        stableID: "source.codex-source",
        sourceID: sourceID,
        displayName: "Codex Source",
        isFallback: false
    )
    let profileMetadata = SourceProfileProfileNavigationMetadata(
        stableID: "source.codex-source.profile.default",
        sourceID: sourceID,
        sourceStableID: sourceMetadata.stableID,
        displayName: "default",
        isFallback: false
    )
    let sessionID = SessionID(rawValue: "source-profile-session")

    let sourceNode = AppShellNavigationNode(
        id: "sources.source.codex-source",
        title: "Codex Source",
        count: 1,
        sessionIDs: [sessionID],
        catalogScope: .source(sourceMetadata),
        sourceProfileMetadata: .source(sourceMetadata)
    )
    let profileNode = AppShellNavigationNode(
        id: "sources.source.codex-source.profile.default",
        title: "default",
        count: 1,
        sessionIDs: [sessionID],
        catalogScope: .profile(profileMetadata),
        sourceProfileMetadata: .profile(profileMetadata)
    )
    let diagnosticNode = AppShellNavigationNode(
        id: "diagnostics.problem-sessions.parseWarning",
        title: "Parse warning",
        count: 1,
        sessionIDs: [sessionID]
    )

    #expect(sourceNode.catalogScope == .source(sourceMetadata))
    #expect(sourceNode.sourceProfileMetadata == .source(sourceMetadata))
    #expect(profileNode.catalogScope == .profile(profileMetadata))
    #expect(profileNode.sourceProfileMetadata == .profile(profileMetadata))
    #expect(diagnosticNode.catalogScope == .sessionIDs([sessionID]))
    #expect(diagnosticNode.sourceProfileMetadata == nil)
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

private func navigationSource(
    id: SessionSourceID = SessionSourceID(rawValue: "codex-navigation"),
    displayName: String = "Codex navigation"
) -> SessionSourceSummary {
    SessionSourceSummary(
        id: id,
        displayName: displayName,
        kind: .codex,
        locationDescription: "/tmp/sessiondeck/.codex/sessions",
        isEnabled: true,
        availability: .available,
        counts: SessionSourceCounts(sessionBucketDirectoryCount: 1, transcriptFileCount: 8)
    )
}

private func navigationSession(
    id: String,
    sourceID: SessionSourceID = SessionSourceID(rawValue: "codex-navigation"),
    sourceLabel: CatalogSourceLabel? = nil,
    projectHint: CatalogProjectHint = CatalogProjectHint(cwdPath: "/tmp/SessionDeck", displayName: "SessionDeck"),
    lastActivity: Int64 = 1,
    sessionPath: String? = nil,
    fallbackReasons: [CatalogSessionFallbackReason] = [],
    health: CatalogEntryHealth = CatalogEntryHealth(parseStatus: .complete)
) -> SessionSummary {
    return SessionSummary(
        id: SessionID(rawValue: id),
        sourceID: sourceID,
        sourceLabel: sourceLabel ?? CatalogSourceLabel(
            sourceID: sourceID.rawValue,
            displayName: "Codex navigation",
            profileName: nil
        ),
        title: "Session \(id)",
        projectHint: projectHint,
        sessionPath: sessionPath ?? "/tmp/sessiondeck/\(id).jsonl",
        activity: CatalogActivityTimestamps(createdAtEpochSeconds: nil, lastActivityEpochSeconds: lastActivity),
        fileSize: CatalogFileSize(byteCount: 128),
        fallbackReasons: fallbackReasons,
        health: health
    )
}
