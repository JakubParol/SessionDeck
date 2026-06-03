import Foundation

enum TempCodexSessionMetadataRewriter {
    static func rewriteFirstSessionMetadataLine(
        in content: String,
        metadata: TempCodexSessionMetadata
    ) throws -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let firstLine = lines.first, let firstLineData = firstLine.data(using: .utf8) else {
            throw TempCodexSessionStoreError.invalidSessionMetadata
        }

        guard
            var event = try JSONSerialization.jsonObject(with: firstLineData) as? [String: Any],
            event["type"] as? String == "session_meta",
            var payload = event["payload"] as? [String: Any]
        else {
            throw TempCodexSessionStoreError.invalidSessionMetadata
        }

        event["timestamp"] = metadata.timestamp
        payload["id"] = metadata.sessionID
        payload["title"] = metadata.title
        payload["source"] = metadata.source

        if metadata.omitProjectAndCwd {
            payload.removeValue(forKey: "project")
            payload.removeValue(forKey: "cwd")
        } else {
            payload["project"] = metadata.project as Any
            payload["cwd"] = metadata.cwd as Any
        }

        event["payload"] = payload
        let rewrittenData = try JSONSerialization.data(
            withJSONObject: event,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        lines[0] = String(decoding: rewrittenData, as: UTF8.self)
        return lines.joined(separator: "\n")
    }
}
