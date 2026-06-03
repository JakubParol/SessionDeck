import Foundation

extension TempCodexSessionStore {
    @discardableResult
    func installProjectSession(
        _ fixtureID: CodexTranscriptFixtureID,
        source: TempCodexSessionSource,
        sessionID: String,
        projectName: String,
        timestamp: String = "2026-01-01T00:00:00Z"
    ) throws -> TempCodexSessionFile {
        try installSession(
            fixtureID,
            source: source,
            sessionID: sessionID,
            placement: .project(projectName),
            timestamp: timestamp
        )
    }

    @discardableResult
    func installNonProjectChat(
        _ fixtureID: CodexTranscriptFixtureID,
        source: TempCodexSessionSource,
        sessionID: String,
        timestamp: String = "2026-01-01T00:00:00Z"
    ) throws -> TempCodexSessionFile {
        try installSession(
            fixtureID,
            source: source,
            sessionID: sessionID,
            placement: .nonProjectChat,
            timestamp: timestamp
        )
    }

    @discardableResult
    func installMissingMetadataSession(
        _ fixtureID: CodexTranscriptFixtureID,
        source: TempCodexSessionSource,
        sessionID: String,
        timestamp: String = "2026-01-01T00:00:00Z"
    ) throws -> TempCodexSessionFile {
        try installSession(
            fixtureID,
            source: source,
            sessionID: sessionID,
            placement: .missingMetadata,
            timestamp: timestamp
        )
    }

    private func installSession(
        _ fixtureID: CodexTranscriptFixtureID,
        source: TempCodexSessionSource,
        sessionID: String,
        placement: TempCodexSessionPlacement,
        timestamp: String
    ) throws -> TempCodexSessionFile {
        let content = try TempCodexSessionMetadataRewriter.rewriteFirstSessionMetadataLine(
            in: CodexTranscriptFixtureManifest.readFixture(fixtureID),
            metadata: sessionMetadata(source: source, sessionID: sessionID, placement: placement, timestamp: timestamp)
        )
        return try writeTranscript(
            content,
            source: source,
            sessionID: sessionID,
            placement: placement,
            timestamp: timestamp
        )
    }

    private func sessionMetadata(
        source: TempCodexSessionSource,
        sessionID: String,
        placement: TempCodexSessionPlacement,
        timestamp: String
    ) throws -> TempCodexSessionMetadata {
        switch placement {
        case .project(let projectName):
            let safeProjectName = try Self.safePathComponent(projectName)
            return TempCodexSessionMetadata(
                sessionID: sessionID,
                timestamp: timestamp,
                title: "Synthetic \(projectName) Session",
                project: projectName,
                cwd: rootURL.appendingPathComponent("projects/\(safeProjectName)", isDirectory: true).path,
                source: source.label,
                omitProjectAndCwd: false
            )
        case .nonProjectChat:
            return TempCodexSessionMetadata(
                sessionID: sessionID,
                timestamp: timestamp,
                title: "Synthetic Non Project Chat",
                project: nil,
                cwd: nil,
                source: source.label,
                omitProjectAndCwd: false
            )
        case .missingMetadata:
            return TempCodexSessionMetadata(
                sessionID: sessionID,
                timestamp: timestamp,
                title: "Synthetic Missing Metadata Session",
                project: nil,
                cwd: nil,
                source: source.label,
                omitProjectAndCwd: true
            )
        }
    }
}
