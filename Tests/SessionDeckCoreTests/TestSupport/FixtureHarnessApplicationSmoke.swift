import Foundation
import SessionDeckCore

final class FixtureHarnessApplicationSmoke {
    private let parentDirectory: URL
    private let store: TempCodexSessionStore
    private var sources: [FixtureHarnessApplicationSource] = []

    var rootPath: String {
        store.rootURL.path
    }

    init(name: String) throws {
        parentDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SessionDeckFixtureHarnessApplicationSmoke", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        let pathGuard = FixturePathGuard(
            forbiddenHomeDirectories: [FileManager.default.homeDirectoryForCurrentUser]
        )
        let factory = TempCodexSessionStoreFactory(parentDirectory: parentDirectory, pathGuard: pathGuard)
        store = try factory.makeStore(name: "store")
    }

    func cleanup() throws {
        try store.cleanup()
        if FileManager.default.fileExists(atPath: parentDirectory.path) {
            try FileManager.default.removeItem(at: parentDirectory)
        }
    }

    func codexSource(label: String, profile: String) throws -> FixtureHarnessApplicationSource {
        let tempSource = try store.source(label: label, profile: profile)
        let safeLabel = try TempCodexSessionStore.safePathComponent(label)
        let safeProfile = try TempCodexSessionStore.safePathComponent(profile)
        let source = FixtureHarnessApplicationSource(
            tempSource: tempSource,
            id: SessionSourceID(rawValue: "\(safeLabel)-\(safeProfile)")
        )
        if !sources.contains(where: { $0.id == source.id }) {
            sources.append(source)
        }
        return source
    }

    func installProjectSession(
        _ fixtureID: CodexTranscriptFixtureID,
        source: FixtureHarnessApplicationSource,
        sessionID: String,
        projectName: String,
        timestamp: String
    ) throws -> FixtureHarnessApplicationSession {
        try applicationSession(
            from: store.installProjectSession(
                fixtureID,
                source: source.tempSource,
                sessionID: sessionID,
                projectName: projectName,
                timestamp: timestamp
            )
        )
    }

    func installNonProjectChat(
        _ fixtureID: CodexTranscriptFixtureID,
        source: FixtureHarnessApplicationSource,
        sessionID: String,
        timestamp: String
    ) throws -> FixtureHarnessApplicationSession {
        try applicationSession(
            from: store.installNonProjectChat(
                fixtureID,
                source: source.tempSource,
                sessionID: sessionID,
                timestamp: timestamp
            )
        )
    }

    func installGeneratedLargeProjectSession(
        source: FixtureHarnessApplicationSource,
        sessionID: String,
        projectName: String,
        options: GeneratedCodexTranscriptOptions,
        timestamp: String
    ) throws -> FixtureHarnessApplicationSession {
        try applicationSession(
            from: store.generateLargeProjectTranscript(
                source: source.tempSource,
                sessionID: sessionID,
                projectName: projectName,
                timestamp: timestamp,
                options: options
            )
        )
    }

    func makeApplicationComposition() throws -> SessionDeckApplicationComposition {
        let sourceSummaries = sources.map { source in
            SessionSourceSummary(
                id: source.id,
                displayName: "\(source.tempSource.label) (\(source.tempSource.profile))",
                kind: .codex,
                locationDescription: source.tempSource.sessionsRootURL.path,
                isEnabled: true
            )
        }
        let sessionFiles = store.sessionFiles
        let sessionSummaries = try sessionFiles.map(sessionSummary)
        let extractionResultsBySourceID = Dictionary(
            uniqueKeysWithValues: Dictionary(grouping: sessionSummaries, by: \.sourceID).map { sourceID, sessions in
                (
                    sourceID,
                    CatalogSourceExtractionResult(sourceID: sourceID, sessions: sessions)
                )
            }
        )
        let transcriptPreviews = try sessionFiles.map(transcriptPreview)
        let transcriptResults = transcriptPreviews.map { preview in
            TranscriptDecodeResult(
                sessionID: preview.sessionID,
                title: preview.title,
                segments: preview.segments,
                diagnostics: [],
                isPartial: preview.isTruncated
            )
        }
        let discoverSessionSources = DiscoverSessionSourcesUseCase(
            sourceDiscovery: FakeSourceDiscoveryPort(sources: sourceSummaries)
        )
        let appShellUseCase = AppShellUseCase(
            launchConfigurationProvider: FixtureHarnessLaunchConfigurationProvider(
                configuredSourceCount: sourceSummaries.count
            ),
            discoverSessionSources: discoverSessionSources
        )

        return SessionDeckApplicationComposition(
            appShellUseCase: appShellUseCase,
            appShellViewModel: appShellUseCase.makeViewModel(),
            discoverSessionSources: discoverSessionSources,
            enumerateCandidateSessionFiles: EnumerateCandidateSessionFilesUseCase(
                candidateFileEnumeration: FakeCandidateSessionFileEnumerationPort(files: [])
            ),
            listSessions: ListSessionsUseCase(
                sessionCatalog: FakeSessionCatalogPort(sessions: sessionSummaries)
            ),
            refreshCatalogSnapshot: RefreshCatalogSnapshotUseCase(
                sourceDiscovery: FakeSourceDiscoveryPort(sources: sourceSummaries),
                metadataExtraction: FakeCatalogMetadataExtractionPort(resultsBySourceID: extractionResultsBySourceID)
            ),
            loadTranscriptPreview: LoadTranscriptPreviewUseCase(
                transcriptLoading: FakeTranscriptLoadingPort(previews: transcriptPreviews)
            ),
            loadTranscriptSegments: LoadTranscriptSegmentsUseCase(
                transcriptDecoding: FakeTranscriptDecodingPort(results: transcriptResults)
            ),
            loadSelectedTranscript: LoadSelectedTranscriptUseCase(
                selectedTranscriptLoading: FakeSelectedTranscriptLoadingPort(
                    results: Dictionary(uniqueKeysWithValues: transcriptResults.map { ($0.sessionID, $0) })
                )
            )
        )
    }

    private func applicationSession(
        from sessionFile: TempCodexSessionFile
    ) throws -> FixtureHarnessApplicationSession {
        FixtureHarnessApplicationSession(id: SessionID(rawValue: sessionFile.sessionID), file: sessionFile)
    }

    private func sessionSummary(from sessionFile: TempCodexSessionFile) throws -> SessionSummary {
        let metadata = try readMetadata(from: sessionFile)
        let sourceID = sourceID(for: sessionFile.source)
        return SessionSummary(
            id: SessionID(rawValue: sessionFile.sessionID),
            sourceID: sourceID,
            sourceLabel: CatalogSourceLabel(
                sourceID: sourceID.rawValue,
                displayName: sessionFile.source.label,
                profileName: sessionFile.source.profile
            ),
            title: metadata.title,
            fallbackTitle: "Session \(sessionFile.sessionID)",
            projectHint: metadata.project.map {
                CatalogProjectHint(cwdPath: metadata.cwd, displayName: $0)
            } ?? .unavailable,
            sessionPath: sessionFile.url.path,
            activity: CatalogActivityTimestamps(
                createdAtEpochSeconds: nil,
                lastActivityEpochSeconds: epochSeconds(from: metadata.timestamp)
            ),
            fileSize: CatalogFileSize(byteCount: byteCount(for: sessionFile.url)),
            metadata: CatalogSessionMetadata(modelName: nil, agentProfileName: sessionFile.source.profile),
            health: CatalogEntryHealth(parseStatus: metadata.project == nil ? .missingMetadata : .complete)
        )
    }

    private func transcriptPreview(from sessionFile: TempCodexSessionFile) throws -> TranscriptPreview {
        let metadata = try readMetadata(from: sessionFile)
        let allSegments = try transcriptSegments(from: sessionFile)
        let previewSegments = Array(allSegments.prefix(3))
        return TranscriptPreview(
            sessionID: SessionID(rawValue: sessionFile.sessionID),
            title: metadata.title ?? "Synthetic session",
            segments: previewSegments,
            isTruncated: allSegments.count > previewSegments.count
        )
    }

    private func sourceID(for source: TempCodexSessionSource) -> SessionSourceID {
        sources.first { $0.tempSource == source }?.id ?? SessionSourceID(rawValue: source.label)
    }

    private func readMetadata(from sessionFile: TempCodexSessionFile) throws -> FixtureHarnessMetadata {
        let lines = try sessionLines(from: sessionFile)
        let events = lines.compactMap(jsonObject)
        let metadataPayload = events.first { $0["type"] as? String == "session_meta" }?["payload"] as? [String: Any]
        let firstText = events.compactMap(textPayload).first
        return FixtureHarnessMetadata(
            timestamp: events.first?["timestamp"] as? String,
            title: metadataPayload?["title"] as? String,
            project: metadataPayload?["project"] as? String,
            cwd: metadataPayload?["cwd"] as? String,
            firstText: firstText
        )
    }

    private func byteCount(for url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private func epochSeconds(from timestamp: String?) -> Int64? {
        guard let timestamp, let date = ISO8601DateFormatter().date(from: timestamp) else {
            return nil
        }

        return Int64(date.timeIntervalSince1970)
    }

    private func transcriptSegments(from sessionFile: TempCodexSessionFile) throws -> [TranscriptSegment] {
        try sessionLines(from: sessionFile).enumerated().compactMap { index, line in
            guard
                let event = jsonObject(from: line),
                let payload = event["payload"] as? [String: Any],
                event["type"] as? String == "response_item"
            else {
                return nil
            }

            let role = segmentRole(for: payload)
            let text = textPayload(from: event) ?? payload["name"] as? String ?? "Synthetic tool event"
            return TranscriptSegment(
                id: "\(sessionFile.sessionID)-segment-\(index)",
                role: role,
                text: text,
                timestampDescription: event["timestamp"] as? String
            )
        }
    }

    private func sessionLines(from sessionFile: TempCodexSessionFile) throws -> [String] {
        try String(contentsOf: sessionFile.url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func jsonObject(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func textPayload(from event: [String: Any]) -> String? {
        guard let payload = event["payload"] as? [String: Any] else {
            return nil
        }
        if let output = payload["output"] as? String {
            return output
        }
        guard
            let content = payload["content"] as? [[String: Any]],
            let firstContent = content.first
        else {
            return nil
        }
        return firstContent["text"] as? String
    }

    private func segmentRole(for payload: [String: Any]) -> TranscriptSegmentRole {
        switch (payload["type"] as? String, payload["role"] as? String) {
        case ("message", "user"):
            return .user
        case ("message", "assistant"):
            return .assistant
        case ("function_call", _), ("function_call_output", _):
            return .tool
        default:
            return .diagnostic
        }
    }
}
