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
    func candidateFiles(at sessionsRoot: URL, sourceID: SessionSourceID) throws -> [CandidateSessionFile]
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

    public func candidateFiles(at sessionsRoot: URL, sourceID: SessionSourceID) throws -> [CandidateSessionFile] {
        guard let enumerator = fileManager.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let rootPath = sessionsRoot.standardizedFileURL.path
        var files: [CandidateSessionFile] = []
        for case let fileURL as URL in enumerator {
            guard isConservativeCodexTranscriptCandidate(fileURL: fileURL, sessionsRoot: sessionsRoot) else {
                continue
            }

            let values = try fileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .contentModificationDateKey,
            ])
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  isContainedAfterResolvingSymlinks(fileURL: fileURL, sessionsRoot: sessionsRoot)
            else {
                continue
            }

            let absolutePath = fileURL.standardizedFileURL.path
            let diagnostic: CandidateSessionFileDiagnostic?
            if fileManager.isReadableFile(atPath: absolutePath) {
                diagnostic = nil
            } else {
                diagnostic = CandidateSessionFileDiagnostic(
                    code: "codex.candidate_file_unreadable",
                    message: "Candidate transcript file could not be read by the current process."
                )
            }

            files.append(
                CandidateSessionFile(
                    sourceID: sourceID,
                    relativePath: relativePath(absolutePath: absolutePath, rootPath: rootPath),
                    absolutePath: absolutePath,
                    byteSize: Int64(values.fileSize ?? 0),
                    modifiedAt: values.contentModificationDate,
                    confidence: .high,
                    reason: "codex.sessions.date-bucket-jsonl",
                    diagnostic: diagnostic
                )
            )

            if files.count >= maximumTranscriptCount {
                break
            }
        }

        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private func isConservativeCodexTranscriptCandidate(fileURL: URL, sessionsRoot: URL) -> Bool {
        guard fileURL.pathExtension == "jsonl" else {
            return false
        }

        let relativeComponents = Array(fileURL.standardizedFileURL.pathComponents.dropFirst(
            sessionsRoot.standardizedFileURL.pathComponents.count
        ))
        guard relativeComponents.count == 4 else {
            return false
        }

        let year = relativeComponents[0]
        let month = relativeComponents[1]
        let day = relativeComponents[2]
        let fileName = relativeComponents[3]
        return year.count == 4 && year.allSatisfy(\.isNumber)
            && month.count == 2 && month.allSatisfy(\.isNumber)
            && day.count == 2 && day.allSatisfy(\.isNumber)
            && fileName.hasPrefix("rollout-\(year)-\(month)-\(day)T")
    }

    private func relativePath(absolutePath: String, rootPath: String) -> String {
        let rootPrefix = "\(rootPath)/"
        guard absolutePath.hasPrefix(rootPrefix) else {
            return absolutePath
        }

        return String(absolutePath.dropFirst(rootPrefix.count))
    }

    private func isContainedAfterResolvingSymlinks(fileURL: URL, sessionsRoot: URL) -> Bool {
        let resolvedRootPath = sessionsRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let resolvedFilePath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
        return resolvedFilePath.hasPrefix("\(resolvedRootPath)/")
    }
}

public struct DefaultCodexSourceDiscoveryAdapter: SourceDiscoveryPort, CandidateSessionFileEnumerationPort, Sendable {
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
            if !definition.isEnabled {
                summaries.append(disabledSummary(definition: definition, rootURL: rootURL))
                continue
            }

            let duplicateKey = duplicateDetectionKey(for: rootURL)
            if seenRootPaths.contains(duplicateKey) {
                summaries.append(duplicateSummary(definition: definition, rootURL: rootURL))
            } else {
                seenRootPaths.insert(duplicateKey)
                summaries.append(try discoverSource(definition: definition, rootURL: rootURL))
            }
        }

        return summaries
    }

    public func enumerateCandidateFiles(sourceID: SessionSourceID? = nil) throws -> [CandidateSessionFile] {
        let definitions = sourceDefinitions ?? [defaultSourceDefinition()]

        var seenRootPaths: Set<String> = []
        var files: [CandidateSessionFile] = []
        for definition in definitions {
            let rootURL = rootURL(for: definition)
            let isCandidateSource = definition.isEnabled && definition.kind == .codex
            let duplicateKey = duplicateDetectionKey(for: rootURL)
            let isDuplicate = isCandidateSource && seenRootPaths.contains(duplicateKey)
            if isCandidateSource && !isDuplicate {
                seenRootPaths.insert(duplicateKey)
            }

            guard sourceID == nil || definition.id == sourceID else {
                continue
            }
            guard isCandidateSource && !isDuplicate else {
                continue
            }

            guard fileSystem.directoryExists(at: rootURL) else {
                continue
            }

            files.append(contentsOf: try fileSystem.candidateFiles(at: rootURL, sourceID: definition.id))
        }

        return files.sorted { $0.absolutePath < $1.absolutePath }
    }

    private func discoverSource(
        definition: LocalSessionSourceDefinition,
        rootURL: URL
    ) throws -> SessionSourceSummary {
        guard definition.kind == .codex else {
            return unsupportedSummary(definition: definition, rootURL: rootURL)
        }

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

    private func duplicateDetectionKey(for rootURL: URL) -> String {
        rootURL.standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
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

    private func disabledSummary(
        definition: LocalSessionSourceDefinition,
        rootURL: URL
    ) -> SessionSourceSummary {
        summary(
            definition: definition,
            rootURL: rootURL,
            availability: .disabled,
            diagnostic: SessionSourceDiagnostic(
                code: "source_root_disabled",
                message: "Configured source root is disabled."
            ),
            counts: .empty
        )
    }

    private func unsupportedSummary(
        definition: LocalSessionSourceDefinition,
        rootURL: URL
    ) -> SessionSourceSummary {
        summary(
            definition: definition,
            rootURL: rootURL,
            availability: .unsupported,
            diagnostic: SessionSourceDiagnostic(
                code: "source_kind_unsupported",
                message: "Configured source kind is not supported by this discovery adapter."
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
