import Foundation

final class TempCodexSessionStore {
    let rootURL: URL

    private let tempRoot: FixtureTempRoot
    private let fileManager: FileManager
    private let rootPath: String
    private let rootComparisonPath: String
    private(set) var sessionFiles: [TempCodexSessionFile] = []

    init(tempRoot: FixtureTempRoot, fileManager: FileManager = .default) {
        self.tempRoot = tempRoot
        self.fileManager = fileManager
        self.rootURL = tempRoot.url
        self.rootPath = tempRoot.url.standardizedFileURL.resolvingSymlinksInPath().path
        self.rootComparisonPath = rootPath.lowercased()
    }

    deinit {
        try? cleanup()
    }

    func cleanup() throws {
        try tempRoot.cleanup()
    }

    func source(label: String, profile: String) throws -> TempCodexSessionSource {
        let sourceRoot = try url(
            forPathComponents: [
                "sources",
                Self.safePathComponent(label),
                Self.safePathComponent(profile),
                ".codex",
            ],
            isDirectory: true
        )
        let sessionsRoot = sourceRoot.appendingPathComponent("sessions", isDirectory: true)
        try validateExistingAncestor(for: sessionsRoot)
        try fileManager.createDirectory(at: sessionsRoot, withIntermediateDirectories: true)
        try validateExistingParent(for: sessionsRoot.appendingPathComponent(".sentinel", isDirectory: false))

        return TempCodexSessionSource(
            label: label,
            profile: profile,
            rootURL: sourceRoot,
            sessionsRootURL: sessionsRoot
        )
    }

    @discardableResult
    func writeTranscript(
        _ content: String,
        source: TempCodexSessionSource,
        sessionID: String,
        placement: TempCodexSessionPlacement,
        timestamp: String = "2026-01-01T00:00:00Z"
    ) throws -> TempCodexSessionFile {
        let destination = try sessionURL(source: source, sessionID: sessionID, timestamp: timestamp)
        try write(content: content, to: destination)

        let sessionFile = TempCodexSessionFile(
            source: source,
            placement: placement,
            sessionID: sessionID,
            timestamp: timestamp,
            url: destination
        )
        sessionFiles.append(sessionFile)
        return sessionFile
    }

    @discardableResult
    func writeTranscript(_ content: String, relativePath: String) throws -> URL {
        let destination = try url(forRelativePath: relativePath, isDirectory: false)
        try write(content: content, to: destination)
        return destination
    }

    private func sessionURL(
        source: TempCodexSessionSource,
        sessionID: String,
        timestamp: String
    ) throws -> URL {
        let dateComponents = try Self.dateComponents(fromTimestamp: timestamp)
        let safeSessionID = try Self.safePathComponent(sessionID)
        let filename = "rollout-\(Self.safeFilenameTimestamp(timestamp))-\(safeSessionID).jsonl"
        let sessionsRoot = try validatedURL(source.sessionsRootURL, isDirectory: true)
        let sessionDirectory = sessionsRoot
            .appendingPathComponent(dateComponents.year, isDirectory: true)
            .appendingPathComponent(dateComponents.month, isDirectory: true)
            .appendingPathComponent(dateComponents.day, isDirectory: true)
        return try validatedURL(sessionDirectory.appendingPathComponent(filename, isDirectory: false), isDirectory: false)
    }

    private func write(content: String, to destination: URL) throws {
        let validatedDestination = try validatedURL(destination, isDirectory: false)
        try validateExistingAncestor(for: validatedDestination.deletingLastPathComponent())
        try fileManager.createDirectory(
            at: validatedDestination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try validateExistingParent(for: validatedDestination)
        try content.write(to: validatedDestination, atomically: true, encoding: .utf8)
    }

    private func url(forPathComponents pathComponents: [String], isDirectory: Bool) throws -> URL {
        let candidate = pathComponents.reduce(rootURL) { partialURL, component in
            partialURL.appendingPathComponent(component, isDirectory: component == pathComponents.last && isDirectory)
        }
        return try validatedURL(candidate, isDirectory: isDirectory)
    }

    private func url(forRelativePath relativePath: String, isDirectory: Bool) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
            throw TempCodexSessionStoreError.pathEscapesTempRoot(relativePath)
        }

        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw TempCodexSessionStoreError.pathEscapesTempRoot(relativePath)
        }

        return try url(forPathComponents: components, isDirectory: isDirectory)
    }

    private func validatedURL(_ candidate: URL, isDirectory: Bool) throws -> URL {
        let standardized = candidate.standardizedFileURL
        let candidatePath = standardized.path
        guard isPathInsideRoot(candidatePath) else {
            throw TempCodexSessionStoreError.pathEscapesTempRoot(candidatePath)
        }

        return URL(fileURLWithPath: candidatePath, isDirectory: isDirectory)
    }

    private func validateExistingParent(for destination: URL) throws {
        let parentPath = destination
            .deletingLastPathComponent()
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        guard isPathInsideRoot(parentPath) else {
            throw TempCodexSessionStoreError.pathEscapesTempRoot(parentPath)
        }
    }

    private func validateExistingAncestor(for destination: URL) throws {
        var current = destination.standardizedFileURL
        while !fileManager.fileExists(atPath: current.path) {
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else {
                break
            }
            current = parent
        }

        let ancestorPath = current.resolvingSymlinksInPath().path
        guard isPathInsideRoot(ancestorPath) else {
            throw TempCodexSessionStoreError.pathEscapesTempRoot(ancestorPath)
        }
    }

    private func isPathInsideRoot(_ path: String) -> Bool {
        let comparisonPath = path.lowercased()
        return comparisonPath == rootComparisonPath || comparisonPath.hasPrefix("\(rootComparisonPath)/")
    }

    static func safePathComponent(_ value: String) throws -> String {
        let safeScalars = value.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "."
                ? Character(scalar)
                : "-"
        }
        let component = String(safeScalars)
        guard !component.isEmpty, component != ".", component != ".." else {
            throw TempCodexSessionStoreError.invalidPathComponent(value)
        }

        return component
    }

    private static func safeFilenameTimestamp(_ timestamp: String) -> String {
        timestamp
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }

    private static func dateComponents(fromTimestamp timestamp: String) throws -> (year: String, month: String, day: String) {
        let parts = timestamp.split(separator: "T", maxSplits: 1)
        guard parts.count == 2 else {
            throw TempCodexSessionStoreError.invalidTimestamp(timestamp)
        }

        let dateParts = parts[0].split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard dateParts.count == 3, dateParts.allSatisfy({ !$0.isEmpty }) else {
            throw TempCodexSessionStoreError.invalidTimestamp(timestamp)
        }

        return (dateParts[0], dateParts[1], dateParts[2])
    }
}
