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
    #expect(hasFixtureCategory("tool-error"))
    #expect(hasFixtureCategory("mixed-order"))
    #expect(hasFixtureCategory("malformed-line"))
    #expect(hasFixtureCategory("unknown-event"))
    #expect(hasFixtureCategory("missing-metadata"))
    #expect(hasFixtureCategory("bounded-read-truncated"))
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
    let projectSessionLines = try fixtureLines(.projectSession)
    let userTurn = try jsonObject(from: projectSessionLines[1])
    let assistantTurn = try jsonObject(from: projectSessionLines[2])
    #expect(userTurn["type"] as? String == "response_item")
    #expect(payloadString("type", in: userTurn) == "message")
    #expect(payloadString("role", in: userTurn) == "user")
    #expect(firstContentType(in: userTurn) == "input_text")
    #expect(assistantTurn["type"] as? String == "response_item")
    #expect(payloadString("type", in: assistantTurn) == "message")
    #expect(payloadString("role", in: assistantTurn) == "assistant")
    #expect(firstContentType(in: assistantTurn) == "output_text")

    let malformedLines = try fixtureLines(.malformedLine)
    #expect(malformedLines.count == 4)
    #expect(validJSONLineCount(in: malformedLines) == 3)

    let unknownEvent = try CodexTranscriptFixtureManifest.readFixture(.unknownEvent)
    #expect(unknownEvent.contains("\"type\":\"future_codex_event\""))

    let missingMetadata = try CodexTranscriptFixtureManifest.readFixture(.missingMetadata)
    #expect(!missingMetadata.contains("\"cwd\""))
    #expect(!missingMetadata.contains("\"project\""))

    let boundedReadTruncated = try CodexTranscriptFixtureManifest.readFixture(.boundedReadTruncated)
    #expect(boundedReadTruncated.contains("synthetic bounded-read payload"))

    let nonProjectChat = try CodexTranscriptFixtureManifest.readFixture(.nonProjectChat)
    #expect(nonProjectChat.contains("\"project\":null"))
    #expect(nonProjectChat.contains("\"cwd\":null"))
}

@Test("Codex transcript fixtures include mixed tool activity examples")
func codexTranscriptFixturesIncludeMixedToolActivityExamples() throws {
    let toolActivity = try CodexTranscriptFixtureManifest.readFixture(.toolActivityMixed)
    #expect(toolActivity.contains("\"type\":\"function_call\""))
    #expect(toolActivity.contains("\"type\":\"function_call_output\""))
    #expect(toolActivity.contains("\"call_id\":\"call_tool_activity_001\""))
    #expect(toolActivity.contains("\"call_id\":\"call_tool_activity_002\""))
    #expect(toolActivity.contains("\"status\":\"failed\""))
    #expect(toolActivity.contains("synthetic failure output"))
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

private func jsonObject(from line: String) throws -> [String: Any] {
    let data = Data(line.utf8)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func payloadString(_ key: String, in object: [String: Any]) -> String? {
    guard let payload = object["payload"] as? [String: Any] else {
        return nil
    }

    return payload[key] as? String
}

private func firstContentType(in object: [String: Any]) -> String? {
    guard
        let payload = object["payload"] as? [String: Any],
        let content = payload["content"] as? [[String: Any]],
        let firstContent = content.first
    else {
        return nil
    }

    return firstContent["type"] as? String
}
