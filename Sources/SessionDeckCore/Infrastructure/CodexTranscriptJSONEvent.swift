import Foundation

struct CodexTranscriptJSONEvent {
    let type: String
    let timestamp: String?
    let payload: [String: Any]

    init?(line: String) {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else {
            return nil
        }

        self.type = type
        self.timestamp = object["timestamp"] as? String
        self.payload = object["payload"] as? [String: Any] ?? [:]
    }

    var supportedMessageRole: String? {
        let role = payload["role"] as? String
        guard role == "user" || role == "assistant" else {
            return nil
        }

        if let payloadType = payload["type"] as? String, payloadType != "message" {
            return nil
        }

        switch type {
        case "event_msg", "response_item":
            return role
        default:
            return nil
        }
    }

    var isIgnorableForReadableTranscript: Bool {
        if type == "turn_context" {
            return true
        }

        if type == "event_msg" {
            return true
        }

        if payloadType == "reasoning" {
            return true
        }

        guard type == "response_item",
              payloadType == "message"
        else {
            return false
        }

        let role = payload["role"] as? String
        return role != "user" && role != "assistant"
    }

    var payloadType: String? {
        payload["type"] as? String
    }

    var isToolCall: Bool {
        payloadType == "function_call" || payloadType == "tool_call" || type == "tool_call"
    }

    var isToolOutput: Bool {
        payloadType == "function_call_output"
            || payloadType == "tool_output"
            || type == "tool_output"
            || type == "tool_result"
    }

    var toolName: String? {
        payloadString("name") ?? payloadString("tool_name")
    }

    var callID: String? {
        payloadString("call_id") ?? payloadString("id")
    }

    var status: String? {
        payloadString("status")
    }

    var toolCallText: String? {
        payloadString("arguments") ?? payloadString("input") ?? payloadString("command")
    }

    var toolOutputText: String? {
        payloadString("output")
            ?? payloadString("error")
            ?? payloadString("result")
            ?? payloadSummary("error")
            ?? payloadSummary("output")
            ?? payloadSummary("result")
    }

    func payloadSummary(_ key: String) -> String? {
        guard let object = payload[key] as? [String: Any] else {
            return nil
        }

        if let code = object["code"] as? String,
           let message = object["message"] as? String {
            return "\(code): \(message)"
        }

        if let message = object["message"] as? String {
            return message
        }

        let pairs = object.keys.sorted().compactMap { key -> String? in
            guard let value = object[key] else {
                return nil
            }

            return "\(key)=\(String(describing: value))"
        }

        return pairs.isEmpty ? nil : pairs.joined(separator: ", ")
    }

    var messageText: String? {
        if let content = payload["content"] as? String {
            return content
        }

        guard let contentItems = payload["content"] as? [[String: Any]] else {
            return nil
        }

        let texts = contentItems.compactMap { item -> String? in
            guard let text = item["text"] as? String else {
                return nil
            }

            switch item["type"] as? String {
            case "input_text", "output_text", nil:
                return text
            default:
                return nil
            }
        }

        guard texts.isEmpty == false else {
            return nil
        }

        return texts.joined(separator: "\n")
    }

    var messageContentType: String {
        if payload["content"] is String {
            return "string"
        }

        return "content_array"
    }

    func payloadString(_ key: String) -> String? {
        payload[key] as? String
    }
}
