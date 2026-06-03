import Foundation

final class TempCodexSessionStoreFactory {
    private let parentDirectory: URL
    private let pathGuard: FixturePathGuard
    private let fileManager: FileManager

    init(
        parentDirectory: URL,
        pathGuard: FixturePathGuard,
        fileManager: FileManager = .default
    ) {
        self.parentDirectory = parentDirectory
        self.pathGuard = pathGuard
        self.fileManager = fileManager
    }

    func makeStore(name: String = UUID().uuidString) throws -> TempCodexSessionStore {
        let tempRoot = try FixtureTempRoot(
            parentDirectory: parentDirectory,
            name: name,
            pathGuard: pathGuard,
            fileManager: fileManager
        )
        return TempCodexSessionStore(tempRoot: tempRoot, fileManager: fileManager)
    }
}
