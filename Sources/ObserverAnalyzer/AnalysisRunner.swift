import Foundation
import GRDB
import ObserverCore

public struct AnalysisResult {
    public let sessionsAnalyzed: Int
    public let labelsGenerated: Int
    public let suggestionsCreated: Int
    public let usage: UsageSummary

    public struct UsageSummary {
        public var labelingInputTokens: Int = 0
        public var labelingOutputTokens: Int = 0
        public var detectionInputTokens: Int = 0
        public var detectionOutputTokens: Int = 0
    }
}

public enum AnalysisProgress {
    case clustering
    case labeling(batchIndex: Int, totalBatches: Int)
    case detecting
    case persisting
    case done
}

public actor AnalysisRunner {
    private let storage: Storage
    private let client: AnthropicClient
    private let lookbackDays: Int

    public init(storage: Storage, client: AnthropicClient, lookbackDays: Int = 7) {
        self.storage = storage
        self.client = client
        self.lookbackDays = lookbackDays
    }

    public func run(
        progress: @escaping @Sendable (AnalysisProgress) -> Void
    ) async throws -> AnalysisResult {
        // 1. Pull captures
        progress(.clustering)
        guard let since = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date())
        else { throw NSError(domain: "AnalysisRunner", code: 1) }

        let storage = self.storage
        let captures: [Capture] = try await Task.detached(priority: .userInitiated) {
            try storage.dbQueue.read { db in
                try Capture
                    .filter(Column("ts") >= since)
                    .filter(Column("excluded") == false)
                    .order(Column("ts").asc)
                    .fetchAll(db)
            }
        }.value

        // 2. Cluster locally
        let clusterer = SessionClusterer()
        let allSessions = clusterer.cluster(captures)
        // Drop micro-sessions (< 60s) — they're usually app switches, not real work.
        let sessions = allSessions.filter { $0.durationSeconds >= 60 }

        guard !sessions.isEmpty else {
            return AnalysisResult(
                sessionsAnalyzed: 0,
                labelsGenerated: 0,
                suggestionsCreated: 0,
                usage: .init()
            )
        }

        // 3. Haiku 4.5 labeling
        let labeling = LabelingService(client: client)
        let labels = try await labeling.label(sessions) { batch, total in
            progress(.labeling(batchIndex: batch, totalBatches: total))
        }

        // 4. Opus 4.7 pattern detection
        progress(.detecting)
        let detector = PatternDetector(client: client)
        let suggestions = try await detector.detect(sessions: sessions, labels: labels)

        // 5. Persist
        progress(.persisting)
        try await persist(suggestions: suggestions, sessions: sessions, labels: labels)

        progress(.done)
        return AnalysisResult(
            sessionsAnalyzed: sessions.count,
            labelsGenerated: labels.count,
            suggestionsCreated: suggestions.count,
            usage: .init()  // TODO: thread Usage through if we ever surface cost in UI
        )
    }

    private func persist(
        suggestions: [DetectedSuggestion],
        sessions: [Session],
        labels: [String: SessionLabel]
    ) async throws {
        let storage = self.storage
        try await Task.detached(priority: .userInitiated) {
            try storage.dbQueue.write { db in
                // Replace previous suggestions with the latest run. Simpler than
                // dedup logic, and the user explicitly chose to re-analyze.
                try db.execute(sql: "DELETE FROM workflow_suggestions WHERE status = 'pending'")

                for s in suggestions {
                    let evidence = s.evidenceSessionIndices.compactMap { idx -> [String: String]? in
                        guard idx >= 0, idx < sessions.count else { return nil }
                        let sess = sessions[idx]
                        return [
                            "session_id": sess.id,
                            "label": labels[sess.id]?.label ?? "",
                            "host": sess.urlHost ?? "",
                            "app": sess.appName,
                        ]
                    }
                    let evidenceJSON = (try? JSONSerialization.data(withJSONObject: evidence))
                        .flatMap { String(data: $0, encoding: .utf8) }

                    var record = WorkflowSuggestion(
                        createdAt: Date(),
                        title: s.title,
                        description: s.description + "\n\n" + s.proposedAutomation,
                        triggerPattern: s.triggerPattern,
                        evidenceJSON: evidenceJSON,
                        confidence: s.confidence,
                        estimatedTimeSavedMin: s.estimatedTimeSavedMin
                    )
                    try record.insert(db)
                }
            }
        }.value
    }
}
