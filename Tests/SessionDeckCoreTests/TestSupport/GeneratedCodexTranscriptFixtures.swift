import Foundation

struct GeneratedCodexTranscriptOptions: Equatable {
    let eventCount: Int
    let toolOutputByteCount: Int

    init(eventCount: Int, toolOutputByteCount: Int) {
        self.eventCount = eventCount
        self.toolOutputByteCount = toolOutputByteCount
    }
}

extension TempCodexSessionStore {
    @discardableResult
    func generateLargeProjectTranscript(
        source: TempCodexSessionSource,
        sessionID: String,
        projectName: String,
        timestamp: String = "2026-01-01T00:00:00Z",
        options: GeneratedCodexTranscriptOptions
    ) throws -> TempCodexSessionFile {
        let content = try GeneratedCodexTranscriptFixtures.largeProjectTranscript(
            sessionID: sessionID,
            projectName: projectName,
            sourceLabel: source.label,
            cwd: rootURL.appendingPathComponent("projects/\(Self.safePathComponent(projectName))", isDirectory: true).path,
            timestamp: timestamp,
            options: options
        )
        return try writeTranscript(
            content,
            source: source,
            sessionID: sessionID,
            placement: .project(projectName),
            timestamp: timestamp
        )
    }

}

enum GeneratedCodexTranscriptFixtures {
    enum Error: Swift.Error, Equatable {
        case invalidEventCount(Int)
        case invalidOutputByteCount(Int)
        case pathEscapesTempRoot(String)
    }

    static func largeToolOutputEvent(
        outputByteCount: Int,
        callID: String = "call-large-output",
        timestamp: String = "2026-01-01T00:00:01Z"
    ) throws -> String {
        guard outputByteCount >= 0 else {
            throw Error.invalidOutputByteCount(outputByteCount)
        }

        return try jsonLine([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "function_call_output",
                "call_id": callID,
                "output": fixedWidthPayload(byteCount: outputByteCount),
            ],
        ])
    }

    static func largeProjectTranscript(
        sessionID: String,
        projectName: String,
        sourceLabel: String,
        cwd: String,
        timestamp: String,
        options: GeneratedCodexTranscriptOptions
    ) throws -> String {
        guard options.eventCount >= 0 else {
            throw Error.invalidEventCount(options.eventCount)
        }

        var lines = [
            try jsonLine([
                "timestamp": timestamp,
                "type": "session_meta",
                "payload": [
                    "id": sessionID,
                    "title": "Synthetic \(projectName) Large Transcript",
                    "project": projectName,
                    "cwd": cwd,
                    "source": sourceLabel,
                ],
            ]),
        ]

        for index in 0..<options.eventCount {
            if index == options.eventCount - 1, options.toolOutputByteCount > 0 {
                lines.append(try largeToolOutputEvent(outputByteCount: options.toolOutputByteCount))
            } else {
                lines.append(try assistantMessageLine(index: index))
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func validatePath(_ candidate: URL, isInside rootURL: URL) throws {
        let rootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
        let candidatePath = candidate.standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
        guard candidatePath == rootPath || candidatePath.hasPrefix("\(rootPath)/") else {
            throw Error.pathEscapesTempRoot(candidate.standardizedFileURL.path)
        }
    }

    static func assistantMessageLine(index: Int) throws -> String {
        try jsonLine([
            "timestamp": "2026-01-01T00:00:01Z",
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "assistant",
                "content": [
                    [
                        "type": "output_text",
                        "text": "Synthetic generated assistant event \(index)",
                    ],
                ],
            ],
        ])
    }

    private static func fixedWidthPayload(byteCount: Int) -> String {
        guard byteCount > 0 else {
            return ""
        }

        let alphabet = "0123456789abcdef"
        var output = ""
        output.reserveCapacity(byteCount)
        while output.utf8.count < byteCount {
            output += alphabet
        }
        return String(output.prefix(byteCount))
    }

    static func jsonLine(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self)
    }
}
