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
        "CodexSessionCatalogAdapter(",
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

@Test("catalog result-state presentation remains local and command-free")
func catalogResultStatePresentationRemainsLocalAndCommandFree() throws {
    let files = [
        repositoryRoot().appending(path: "Sources/SessionDeckCore/Application/AppShellCatalogResultStateViewModel.swift"),
        repositoryRoot().appending(path: "Sources/SessionDeckCore/Application/AppShellCatalogSummaryViewModel.swift"),
        repositoryRoot().appending(path: "Sources/SessionDeckApp/Presentation/AppShellCatalogView.swift"),
    ]
    let bannedTokens = [
        "URLSession",
        "URLRequest",
        "Process(",
        "NSWorkspace",
        "FileManager.default",
    ]

    for file in files {
        let contents = try String(contentsOf: file, encoding: .utf8)
        for token in bannedTokens {
            #expect(
                contents.contains(token) == false,
                "\(file.lastPathComponent) should keep result-state rendering local and command-free"
            )
        }
    }
}

@Test("Presentation renders navigation sections from the application DTO")
func presentationRendersNavigationSectionsFromApplicationDTO() throws {
    let navigationView = repositoryRoot()
        .appending(path: "Sources/SessionDeckApp/Presentation/AppShellNavigationView.swift")
    let contents = try String(contentsOf: navigationView, encoding: .utf8)

    #expect(
        contents.contains("summary.sectionNodes"),
        "AppShellNavigationView should render the Application-owned navigation section DTO"
    )
}

@Test("Presentation uses native sidebar selection to scope catalog content")
func presentationUsesNativeSidebarSelectionToScopeCatalogContent() throws {
    let appShellView = repositoryRoot()
        .appending(path: "Sources/SessionDeckApp/Presentation/AppShellView.swift")
    let navigationView = repositoryRoot()
        .appending(path: "Sources/SessionDeckApp/Presentation/AppShellNavigationView.swift")
    let appShellContents = try String(contentsOf: appShellView, encoding: .utf8)
    let navigationContents = try String(contentsOf: navigationView, encoding: .utf8)

    #expect(
        appShellContents.contains("NavigationSplitView"),
        "AppShellView should use a native macOS sidebar-detail layout"
    )
    #expect(
        appShellContents.contains("$selectedNavigationNodeID"),
        "AppShellView should own stable navigation selection state"
    )
    #expect(
        navigationContents.contains("List(selection: $selectedNavigationNodeID)"),
        "AppShellNavigationView should use native list selection instead of a disabled button grid"
    )
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
        "CodexSessionCatalogAdapter(",
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
