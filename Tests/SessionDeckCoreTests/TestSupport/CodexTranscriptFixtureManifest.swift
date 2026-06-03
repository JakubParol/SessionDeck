import Foundation

enum CodexTranscriptFixtureID: String, CaseIterable {
    case projectSession = "project-session"
    case malformedLine = "malformed-line"
    case unknownEvent = "unknown-event"
    case missingMetadata = "missing-metadata"
    case nonProjectChat = "non-project-chat"
}

struct CodexTranscriptFixture: Equatable {
    let id: CodexTranscriptFixtureID
    let filename: String
    let summary: String
    let categories: Set<String>
}

enum CodexTranscriptFixtureManifest {
    enum Error: Swift.Error, Equatable {
        case missingManifestEntry(CodexTranscriptFixtureID)
    }

    static let fixtures: [CodexTranscriptFixture] = [
        CodexTranscriptFixture(
            id: .projectSession,
            filename: "project-session.jsonl",
            summary: "Valid synthetic project session with user, assistant, tool call, and tool output events.",
            categories: ["valid", "project", "tool-call", "tool-output"]
        ),
        CodexTranscriptFixture(
            id: .malformedLine,
            filename: "malformed-line.jsonl",
            summary: "Synthetic transcript containing one malformed JSONL line between valid events.",
            categories: ["degraded", "malformed-line"]
        ),
        CodexTranscriptFixture(
            id: .unknownEvent,
            filename: "unknown-event.jsonl",
            summary: "Synthetic transcript containing an unknown event shape for graceful parser fallback tests.",
            categories: ["degraded", "unknown-event"]
        ),
        CodexTranscriptFixture(
            id: .missingMetadata,
            filename: "missing-metadata.jsonl",
            summary: "Synthetic transcript with missing cwd/project metadata.",
            categories: ["degraded", "missing-metadata"]
        ),
        CodexTranscriptFixture(
            id: .nonProjectChat,
            filename: "non-project-chat.jsonl",
            summary: "Synthetic non-project chat transcript without repository context.",
            categories: ["valid", "non-project"]
        ),
    ]

    static func fixture(for id: CodexTranscriptFixtureID) throws -> CodexTranscriptFixture {
        guard let fixture = fixtures.first(where: { $0.id == id }) else {
            throw Error.missingManifestEntry(id)
        }

        return fixture
    }

    static func fixtureURL(
        for id: CodexTranscriptFixtureID,
        pathGuard: FixturePathGuard = defaultPathGuard
    ) throws -> URL {
        let fixtureRoot = try pathGuard.validateFixtureRoot(rootDirectory)
        let fixture = try fixture(for: id)
        return fixtureRoot.appendingPathComponent(fixture.filename, isDirectory: false)
    }

    static func readFixture(
        _ id: CodexTranscriptFixtureID,
        pathGuard: FixturePathGuard = defaultPathGuard
    ) throws -> String {
        try String(contentsOf: fixtureURL(for: id, pathGuard: pathGuard), encoding: .utf8)
    }

    static var rootDirectory: URL {
        testDirectory.appendingPathComponent("Fixtures/CodexTranscripts", isDirectory: true)
    }

    private static var testDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var defaultPathGuard: FixturePathGuard {
        FixturePathGuard(
            forbiddenHomeDirectories: [
                FileManager.default.homeDirectoryForCurrentUser,
                URL(fileURLWithPath: "/Users/jakubparol", isDirectory: true),
            ]
        )
    }
}
