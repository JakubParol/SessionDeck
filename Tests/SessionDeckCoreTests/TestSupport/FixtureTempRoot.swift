import Foundation

final class FixtureTempRoot {
    let url: URL

    private let fileManager: FileManager
    private var didCleanUp = false

    init(
        parentDirectory: URL,
        name: String = UUID().uuidString,
        pathGuard: FixturePathGuard,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        let candidate = parentDirectory.appendingPathComponent(name, isDirectory: true)
        self.url = try pathGuard.validateFixtureRoot(candidate)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? cleanup()
    }

    func cleanup() throws {
        guard !didCleanUp else {
            return
        }

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        didCleanUp = true
    }
}
