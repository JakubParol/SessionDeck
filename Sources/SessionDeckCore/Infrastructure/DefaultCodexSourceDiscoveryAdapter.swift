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

    public init(
        homeDirectoryProvider: any HomeDirectoryProviding = EnvironmentHomeDirectoryProvider(),
        fileSystem: any CodexSourceFileSystemChecking = FoundationCodexSourceFileSystem()
    ) {
        self.homeDirectoryProvider = homeDirectoryProvider
        self.fileSystem = fileSystem
    }

    public func discoverSources() throws -> [SessionSourceSummary] {
        let sessionsRoot = homeDirectoryProvider.homeDirectory()
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)

        guard fileSystem.directoryExists(at: sessionsRoot) else {
            return [summary(
                sessionsRoot: sessionsRoot,
                availability: .missing,
                diagnostic: SessionSourceDiagnostic(
                    code: "codex.sessions_root_missing",
                    message: "Default Codex sessions root was not found."
                ),
                counts: .empty
            )]
        }

        do {
            let counts = try fileSystem.sourceCounts(at: sessionsRoot)
            return [summary(sessionsRoot: sessionsRoot, availability: .available, counts: counts)]
        } catch {
            return [summary(
                sessionsRoot: sessionsRoot,
                availability: .inaccessible,
                diagnostic: SessionSourceDiagnostic(
                    code: "codex.sessions_root_inaccessible",
                    message: "Default Codex sessions root exists but could not be inspected."
                ),
                counts: .empty
            )]
        }
    }

    private func summary(
        sessionsRoot: URL,
        availability: SourceAvailability,
        diagnostic: SessionSourceDiagnostic? = nil,
        counts: SessionSourceCounts
    ) -> SessionSourceSummary {
        SessionSourceSummary(
            id: Self.sourceID,
            displayName: "Codex default",
            kind: .codex,
            locationDescription: sessionsRoot.standardizedFileURL.path,
            isEnabled: availability == .available,
            availability: availability,
            diagnostic: diagnostic,
            counts: counts
        )
    }
}
