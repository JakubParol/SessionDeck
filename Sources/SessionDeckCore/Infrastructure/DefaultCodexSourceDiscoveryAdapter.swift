import Foundation

public protocol HomeDirectoryProviding: Sendable {
    func homeDirectory() -> URL
}

public struct EnvironmentHomeDirectoryProvider: HomeDirectoryProviding, Sendable {
    public init() {}

    public func homeDirectory() -> URL {
        if let homePath = ProcessInfo.processInfo.environment["HOME"], !homePath.isEmpty {
            return URL(fileURLWithPath: homePath, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }
}

public protocol CodexSourceFileSystemChecking: Sendable {
    func directoryExists(at url: URL) -> Bool
    func sourceCounts(at sessionsRoot: URL) throws -> SessionSourceCounts
}

public struct FoundationCodexSourceFileSystem: CodexSourceFileSystemChecking, @unchecked Sendable {
    private let fileManager: FileManager
    private let maximumTranscriptCount: Int

    public init(fileManager: FileManager = .default, maximumTranscriptCount: Int = 10_000) {
        self.fileManager = fileManager
        self.maximumTranscriptCount = maximumTranscriptCount
    }

    public func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    public func sourceCounts(at sessionsRoot: URL) throws -> SessionSourceCounts {
        guard let enumerator = fileManager.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .empty
        }

        var transcriptFileCount = 0
        var sessionBucketDirectoryPaths: Set<String> = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true && fileURL.pathExtension == "jsonl" {
                transcriptFileCount += 1
                sessionBucketDirectoryPaths.insert(fileURL.deletingLastPathComponent().standardizedFileURL.path)
            }
            if transcriptFileCount >= maximumTranscriptCount {
                break
            }
        }

        return SessionSourceCounts(
            sessionBucketDirectoryCount: sessionBucketDirectoryPaths.count,
            transcriptFileCount: transcriptFileCount
        )
    }
}

public struct DefaultCodexSourceDiscoveryAdapter: SourceDiscoveryPort, Sendable {
    public static let sourceID = SessionSourceID(rawValue: "codex-default")

    private let homeDirectoryProvider: any HomeDirectoryProviding
    private let fileSystem: any CodexSourceFileSystemChecking
    private let sourceDefinitions: [LocalSessionSourceDefinition]?

    public init(
        homeDirectoryProvider: any HomeDirectoryProviding = EnvironmentHomeDirectoryProvider(),
        fileSystem: any CodexSourceFileSystemChecking = FoundationCodexSourceFileSystem(),
        sourceDefinitions: [LocalSessionSourceDefinition]? = nil
    ) {
        self.homeDirectoryProvider = homeDirectoryProvider
        self.fileSystem = fileSystem
        self.sourceDefinitions = sourceDefinitions
    }

    public func discoverSources() throws -> [SessionSourceSummary] {
        let definitions = sourceDefinitions ?? [defaultSourceDefinition()]

        var seenRootPaths: Set<String> = []
        var summaries: [SessionSourceSummary] = []
        for definition in definitions {
            let rootURL = rootURL(for: definition)
            let rootPath = rootURL.path
            if seenRootPaths.contains(rootPath) {
                summaries.append(duplicateSummary(definition: definition, rootURL: rootURL))
            } else {
                seenRootPaths.insert(rootPath)
                summaries.append(try discoverSource(definition: definition, rootURL: rootURL))
            }
        }

        return summaries
    }

    private func discoverSource(
        definition: LocalSessionSourceDefinition,
        rootURL: URL
    ) throws -> SessionSourceSummary {
        guard fileSystem.directoryExists(at: rootURL) else {
            return summary(
                definition: definition,
                rootURL: rootURL,
                availability: .missing,
                diagnostic: SessionSourceDiagnostic(
                    code: "codex.sessions_root_missing",
                    message: "Configured Codex sessions root was not found."
                ),
                counts: .empty
            )
        }

        do {
            let counts = try fileSystem.sourceCounts(at: rootURL)
            return summary(
                definition: definition,
                rootURL: rootURL,
                availability: .available,
                counts: counts
            )
        } catch {
            return summary(
                definition: definition,
                rootURL: rootURL,
                availability: .inaccessible,
                diagnostic: SessionSourceDiagnostic(
                    code: "codex.sessions_root_inaccessible",
                    message: "Configured Codex sessions root exists but could not be inspected."
                ),
                counts: .empty
            )
        }
    }

    private func rootURL(for definition: LocalSessionSourceDefinition) -> URL {
        URL(fileURLWithPath: definition.rootPath, isDirectory: true).standardizedFileURL
    }

    private func defaultSourceDefinition() -> LocalSessionSourceDefinition {
        let sessionsRoot = homeDirectoryProvider.homeDirectory()
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)

        return LocalSessionSourceDefinition(
            id: Self.sourceID,
            displayName: "Codex default",
            kind: .codex,
            rootPath: sessionsRoot.path,
            isEnabled: true
        )
    }

    private func duplicateSummary(
        definition: LocalSessionSourceDefinition,
        rootURL: URL
    ) -> SessionSourceSummary {
        summary(
            definition: definition,
            rootURL: rootURL,
            availability: .duplicate,
            diagnostic: SessionSourceDiagnostic(
                code: "source_root_duplicate",
                message: "Configured source root duplicates an earlier source root."
            ),
            counts: .empty
        )
    }

    private func summary(
        definition: LocalSessionSourceDefinition,
        rootURL: URL,
        availability: SourceAvailability,
        diagnostic: SessionSourceDiagnostic? = nil,
        counts: SessionSourceCounts
    ) -> SessionSourceSummary {
        SessionSourceSummary(
            id: definition.id,
            displayName: definition.displayName,
            kind: definition.kind,
            locationDescription: rootURL.standardizedFileURL.path,
            isEnabled: availability == .available,
            availability: availability,
            diagnostic: diagnostic,
            counts: counts
        )
    }
}
