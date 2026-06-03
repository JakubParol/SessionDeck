import Foundation
import Testing

@Test("Codex transcript fixture manifest covers required fixture categories")
func codexTranscriptFixtureManifestCoversRequiredFixtureCategories() {
    let manifestIDs = Set(CodexTranscriptFixtureManifest.fixtures.map(\.id))
    #expect(manifestIDs == Set(CodexTranscriptFixtureID.allCases))

    for fixture in CodexTranscriptFixtureManifest.fixtures {
        #expect(!fixture.filename.isEmpty)
        #expect(!fixture.summary.isEmpty)
        #expect(!fixture.categories.isEmpty)
    }

    #expect(hasFixtureCategory("valid"))
    #expect(hasFixtureCategory("project"))
    #expect(hasFixtureCategory("tool-call"))
    #expect(hasFixtureCategory("tool-output"))
    #expect(hasFixtureCategory("malformed-line"))
    #expect(hasFixtureCategory("unknown-event"))
    #expect(hasFixtureCategory("missing-metadata"))
    #expect(hasFixtureCategory("non-project"))
}

@Test("Codex transcript fixtures are readable through the stable manifest helper")
func codexTranscriptFixturesAreReadableThroughManifestHelper() throws {
    for id in CodexTranscriptFixtureID.allCases {
        let url = try CodexTranscriptFixtureManifest.fixtureURL(for: id)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.path.contains("CodexTranscripts"))
        #expect(!url.path.contains("/.codex"))
        #expect(!url.path.contains("/.hermes"))

        let content = try CodexTranscriptFixtureManifest.readFixture(id)
        #expect(!content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

@Test("Codex transcript fixtures preserve degraded input examples")
func codexTranscriptFixturesPreserveDegradedInputExamples() throws {
    let projectSession = try CodexTranscriptFixtureManifest.readFixture(.projectSession)
    #expect(projectSession.contains("\"type\":\"user_message\""))
    #expect(projectSession.contains("\"type\":\"message\",\"role\":\"assistant\""))

    let malformedLines = try fixtureLines(.malformedLine)
    #expect(malformedLines.count == 4)
    #expect(validJSONLineCount(in: malformedLines) == 3)

    let unknownEvent = try CodexTranscriptFixtureManifest.readFixture(.unknownEvent)
    #expect(unknownEvent.contains("\"type\":\"future_codex_event\""))

    let missingMetadata = try CodexTranscriptFixtureManifest.readFixture(.missingMetadata)
    #expect(!missingMetadata.contains("\"cwd\""))
    #expect(!missingMetadata.contains("\"project\""))

    let nonProjectChat = try CodexTranscriptFixtureManifest.readFixture(.nonProjectChat)
    #expect(nonProjectChat.contains("\"project\":null"))
    #expect(nonProjectChat.contains("\"cwd\":null"))
}

@Test("Codex transcript fixtures contain only synthetic redacted content")
func codexTranscriptFixturesContainOnlySyntheticRedactedContent() throws {
    let forbiddenSnippets = [
        "/Users",
        "/Repos",
        ".codex",
        ".hermes",
        "jakub",
        "parol",
        "kuba",
        "agent.naomi",
        "@",
        "token",
        "secret",
        "password",
        "github_pat",
        "sk-",
        "BEGIN PRIVATE KEY",
    ]

    for id in CodexTranscriptFixtureID.allCases {
        let content = try CodexTranscriptFixtureManifest.readFixture(id)
        let lowercasedContent = content.lowercased()

        for forbiddenSnippet in forbiddenSnippets {
            #expect(!lowercasedContent.contains(forbiddenSnippet.lowercased()))
        }
    }
}

private func hasFixtureCategory(_ category: String) -> Bool {
    CodexTranscriptFixtureManifest.fixtures.contains { fixture in
        fixture.categories.contains(category)
    }
}

private func fixtureLines(_ id: CodexTranscriptFixtureID) throws -> [String] {
    try CodexTranscriptFixtureManifest.readFixture(id)
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map(String.init)
}

private func validJSONLineCount(in lines: [String]) -> Int {
    lines.filter { line in
        guard let data = line.data(using: .utf8) else {
            return false
        }

        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }.count
}
