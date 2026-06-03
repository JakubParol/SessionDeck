import Foundation
import Testing

@Test("Domain source files stay pure of UI, IO, OS, persistence, network, and infrastructure imports")
func domainSourceFilesStayPure() throws {
    let domainDirectory = try requiredDirectory(named: "Domain")
    let sourceFiles = try swiftFiles(in: domainDirectory)
    #expect(sourceFiles.isEmpty == false)

    let bannedImports = [
        "SwiftUI",
        "AppKit",
        "Foundation",
        "Network",
        "SQLite3",
    ]

    for file in sourceFiles {
        let contents = try String(contentsOf: file, encoding: .utf8)
        for moduleName in bannedImports {
            #expect(
                contents.contains("import \(moduleName)") == false,
                "\(file.lastPathComponent) must not import \(moduleName)"
            )
        }
        #expect(contents.contains("Infrastructure") == false, "\(file.lastPathComponent) must not reference Infrastructure")
        #expect(contents.contains("Presentation") == false, "\(file.lastPathComponent) must not reference Presentation")
    }
}

@Test("Presentation target consumes application DTOs without constructing infrastructure")
func presentationDoesNotConstructInfrastructure() throws {
    let presentationDirectory = repositoryRoot().appending(path: "Sources/SessionDeckApp/Presentation")
    let sourceFiles = try swiftFiles(in: presentationDirectory)
    #expect(sourceFiles.isEmpty == false)

    let bannedTokens = [
        "PlaceholderLaunchConfigurationProvider(",
        "PlaceholderSourceDiscoveryAdapter(",
        "DefaultCodexSourceDiscoveryAdapter(",
        "PlaceholderSessionCatalogAdapter(",
        "PlaceholderTranscriptLoadingAdapter(",
        "Infrastructure",
        "FileManager.default",
        "Process(",
    ]

    for file in sourceFiles {
        let contents = try String(contentsOf: file, encoding: .utf8)
        for token in bannedTokens {
            #expect(
                contents.contains(token) == false,
                "\(file.lastPathComponent) should not construct infrastructure or perform direct IO"
            )
        }
    }
}

@Test("concrete adapters are only constructed in the composition root")
func concreteAdaptersAreOnlyConstructedInCompositionRoot() throws {
    let sourcesDirectory = repositoryRoot().appending(path: "Sources")
    let sourceFiles = try swiftFiles(in: sourcesDirectory)
    #expect(sourceFiles.isEmpty == false)

    let compositionRootPathSuffix = "Sources/SessionDeckCore/CompositionRoot/SessionDeckCompositionRoot.swift"
    let adapterInitializers = [
        "PlaceholderLaunchConfigurationProvider(",
        "PlaceholderSourceDiscoveryAdapter(",
        "DefaultCodexSourceDiscoveryAdapter(",
        "PlaceholderSessionCatalogAdapter(",
        "PlaceholderTranscriptLoadingAdapter(",
    ]

    for file in sourceFiles {
        let path = file.path(percentEncoded: false)
        let isCompositionRoot = path.hasSuffix(compositionRootPathSuffix)
        let contents = try String(contentsOf: file, encoding: .utf8)

        for initializer in adapterInitializers where contents.contains(initializer) {
            #expect(
                isCompositionRoot,
                "\(file.lastPathComponent) must not construct \(initializer); centralize adapter wiring in SessionDeckCompositionRoot"
            )
        }
    }
}

private func requiredDirectory(named name: String) throws -> URL {
    let directory = repositoryRoot().appending(path: "Sources/SessionDeckCore/\(name)")
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
    #expect(exists && isDirectory.boolValue, "Expected \(name) layer directory to exist")
    return directory
}

private func swiftFiles(in directory: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return try enumerator.compactMap { item in
        guard let file = item as? URL else {
            return nil
        }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey])
        return values.isRegularFile == true && file.pathExtension == "swift" ? file : nil
    }
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
