import Foundation

struct FixturePathGuard {
    private let forbiddenRoots: [String]

    init(forbiddenHomeDirectories: [URL]) {
        self.forbiddenRoots = forbiddenHomeDirectories.flatMap { homeDirectory in
            [".codex", ".hermes"].map { storeName in
                Self.normalizedPath(homeDirectory.appendingPathComponent(storeName))
            }
        }
    }

    func validateFixtureRoot(_ fixtureRoot: URL) throws -> URL {
        let candidate = Self.normalizedPath(fixtureRoot)
        if forbiddenRoots.contains(where: { Self.path(candidate, isAtOrInside: $0) }) {
            throw FixturePathGuardError.forbiddenRealSessionStore(candidate)
        }

        return URL(fileURLWithPath: candidate)
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private static func path(_ candidate: String, isAtOrInside forbiddenRoot: String) -> Bool {
        candidate == forbiddenRoot || candidate.hasPrefix("\(forbiddenRoot)/")
    }
}

enum FixturePathGuardError: Error, Equatable {
    case forbiddenRealSessionStore(String)
}
