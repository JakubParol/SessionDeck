extension AppShellSelectedTranscriptDetailState {
    static func metadataRows(
        for session: SessionSummary
    ) -> [AppShellSelectedTranscriptMetadataRow] {
        [
            AppShellSelectedTranscriptMetadataRow(
                id: "title",
                title: "Title",
                value: titleLabel(for: session.title ?? ""),
                isFallback: session.title?.isEmpty ?? true
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "source",
                title: "Source",
                value: sourceLabel(sourceLabel: session.sourceLabel, metadata: session.metadata),
                isFallback: session.sourceLabel.displayName.isEmpty
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "project",
                title: "Project",
                value: projectLabel(for: session.projectHint),
                isFallback: session.projectHint.cwdPath == nil || session.projectHint.displayName.isEmpty
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "path",
                title: "Path",
                value: pathLabel(for: session.sessionPath),
                isFallback: session.sessionPath.isEmpty
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "created",
                title: "Created",
                value: timestampLabel(
                    for: session.activity.createdAtEpochSeconds,
                    fallback: "Created time unavailable"
                ),
                isFallback: session.activity.createdAtEpochSeconds == nil
            ),
            AppShellSelectedTranscriptMetadataRow(
                id: "last-activity",
                title: "Last Activity",
                value: timestampLabel(
                    for: session.activity.lastActivityEpochSeconds,
                    fallback: "Last activity unavailable"
                ),
                isFallback: session.activity.lastActivityEpochSeconds == nil
            ),
        ]
    }

    static func titleLabel(for title: String) -> String {
        title.isEmpty ? "Untitled session" : title
    }

    static func sourceLabel(
        sourceLabel: CatalogSourceLabel,
        metadata: CatalogSessionMetadata
    ) -> String {
        let sourceDisplayName = sourceLabel.displayName
        guard sourceDisplayName.isEmpty == false else {
            return "Unknown source"
        }

        let profileName = sourceLabel.profileName ?? metadata.agentProfileName
        guard let profileName, profileName.isEmpty == false else {
            return sourceDisplayName
        }

        return "\(sourceDisplayName) / \(profileName)"
    }

    static func projectLabel(for projectHint: CatalogProjectHint) -> String {
        guard projectHint.displayName.isEmpty == false else {
            return "Project unavailable"
        }

        return projectHint.displayName
    }

    static func pathLabel(for sessionPath: String) -> String {
        sessionPath.isEmpty ? "Path unavailable" : sessionPath
    }

    static func timestampLabel(for epochSeconds: Int64?, fallback: String) -> String {
        guard let epochSeconds else {
            return fallback
        }

        return "\(epochSeconds)"
    }
}
