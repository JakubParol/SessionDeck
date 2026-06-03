import Foundation

struct FixturePathGuard {
    private let forbiddenRoots: [PathIdentity]

    init(forbiddenHomeDirectories: [URL]) {
        self.forbiddenRoots = forbiddenHomeDirectories.flatMap { homeDirectory in
            [".codex", ".hermes"].map { storeName in
                Self.pathIdentity(homeDirectory.appendingPathComponent(storeName))
            }
        }
    }

    func validateFixtureRoot(_ fixtureRoot: URL) throws -> URL {
        let candidate = Self.pathIdentity(fixtureRoot)
        if forbiddenRoots.contains(where: { Self.path(candidate.comparisonPath, isAtOrInside: $0.comparisonPath) }) {
            throw FixturePathGuardError.forbiddenRealSessionStore(candidate.displayPath)
        }

        return URL(fileURLWithPath: candidate.displayPath)
    }

    private static func pathIdentity(_ url: URL) -> PathIdentity {
        let displayPath = url.standardizedFileURL.resolvingSymlinksInPath().path
        return PathIdentity(displayPath: displayPath, comparisonPath: displayPath.lowercased())
    }

    private static func path(_ candidate: String, isAtOrInside forbiddenRoot: String) -> Bool {
        candidate == forbiddenRoot || candidate.hasPrefix("\(forbiddenRoot)/")
    }
}

private struct PathIdentity {
    let displayPath: String
    let comparisonPath: String
}

enum FixturePathGuardError: Error, Equatable {
    case forbiddenRealSessionStore(String)
}
