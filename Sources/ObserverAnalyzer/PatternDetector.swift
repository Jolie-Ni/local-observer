import Foundation

/// One workflow proposal returned by Opus 4.7.
public struct DetectedSuggestion: Decodable {
    public let title: String
    public let description: String
    public let triggerPattern: String
    public let proposedAutomation: String
    public let evidenceSessionIndices: [Int]
    public let confidence: Double
    public let estimatedTimeSavedMin: Int

    enum CodingKeys: String, CodingKey {
        case title, description
        case triggerPattern = "trigger_pattern"
        case proposedAutomation = "proposed_automation"
        case evidenceSessionIndices = "evidence_session_indices"
        case confidence
        case estimatedTimeSavedMin = "estimated_time_saved_min"
    }
}

private struct DetectionResponse: Decodable {
    let suggestions: [DetectedSuggestion]
}

public struct PatternDetector {
    public let client: AnthropicClient

    public init(client: AnthropicClient) {
        self.client = client
    }

    public func detect(
        sessions: [Session],
        labels: [String: SessionLabel]
    ) async throws -> [DetectedSuggestion] {
        let payload = sessions.enumerated().map { (idx, s) -> [String: String] in
            let label = labels[s.id]
            return [
                "index": "\(idx)",
                "label": label?.label ?? "(unlabeled)",
                "intent": label?.intent ?? "other",
                "app": s.appName,
                "host": s.urlHost ?? "",
                "duration_min": "\(Int(s.durationSeconds / 60.0))",
                "started": ISO8601DateFormatter().string(from: s.startTs),
            ]
        }
        let userJSON = (try? JSONEncoder().encode(payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let request = MessagesRequest(
            model: "claude-opus-4-7",
            maxTokens: 16000,
            system: [.init(text: Self.systemPrompt, cacheControl: .init())],
            messages: [.init(role: "user", content: userJSON)],
            thinking: .adaptive,
            outputConfig: .init(format: .init(schema: Self.schema), effort: "high")
        )
        return try await client.messagesParsed(request, as: DetectionResponse.self).suggestions
    }

    static let systemPrompt: String = """
    You analyze a knowledge worker's recent labeled work sessions and propose
    AI-automatable workflows. The user wants to identify which parts of their
    daily work are AI-automatable.

    A good workflow suggestion:
    - Identifies a recurring multi-step pattern observed across multiple sessions.
    - Names the trigger ("when X, do Y").
    - Describes what an AI workflow would do end-to-end.
    - Cites specific evidence sessions by their index.

    Rules:
    - Only propose workflows where you see the pattern in ≥2 sessions.
    - Be specific. "Auto-research a LinkedIn profile before a sales meeting and
      attach a 5-bullet summary to the calendar invite" beats "Help with sales".
    - Propose at most 7 suggestions, ranked by confidence.
    - confidence: 0.0–1.0 (only your subjective assessment of pattern strength).
    - estimated_time_saved_min: minutes saved per occurrence of the trigger.

    Return JSON: { "suggestions": [...] }
    """

    static let schema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "suggestions": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title":               .object(["type": .string("string")]),
                        "description":         .object(["type": .string("string")]),
                        "trigger_pattern":     .object(["type": .string("string")]),
                        "proposed_automation": .object(["type": .string("string")]),
                        "evidence_session_indices": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("integer")]),
                        ]),
                        "confidence":              .object(["type": .string("number")]),
                        "estimated_time_saved_min":.object(["type": .string("integer")]),
                    ]),
                    "required": .array([
                        .string("title"), .string("description"),
                        .string("trigger_pattern"), .string("proposed_automation"),
                        .string("evidence_session_indices"),
                        .string("confidence"), .string("estimated_time_saved_min"),
                    ]),
                    "additionalProperties": .bool(false),
                ]),
            ]),
        ]),
        "required": .array([.string("suggestions")]),
        "additionalProperties": .bool(false),
    ])
}
