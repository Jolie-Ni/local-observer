import Foundation
import GRDB

public final class Storage {
    public let dbQueue: DatabaseQueue

    public init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_captures") { db in
            try db.create(table: "captures") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .datetime).notNull().indexed()
                t.column("appName", .text).notNull()
                t.column("windowTitle", .text)
                t.column("url", .text)
                t.column("screenshotPath", .text)
                t.column("ocrText", .text)
                t.column("isRedacted", .boolean).notNull().defaults(to: false)
                t.column("excluded", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v2_workflows") { db in
            try db.create(table: "workflow_suggestions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("title", .text).notNull()
                t.column("description", .text).notNull()
                t.column("triggerPattern", .text)
                t.column("evidenceJSON", .text)
                t.column("confidence", .double).notNull().defaults(to: 0.0)
                t.column("estimatedTimeSavedMin", .integer).notNull().defaults(to: 0)
                t.column("status", .text).notNull().defaults(to: "pending")
            }

            try db.create(table: "workflows") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sourceSuggestionID", .integer)
                    .references("workflow_suggestions", onDelete: .setNull)
                t.column("name", .text).notNull()
                t.column("configJSON", .text)
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull()
            }
        }

        try migrator.migrate(dbQueue)
    }

    public func insert(capture: Capture) throws {
        var capture = capture
        try dbQueue.write { db in
            try capture.insert(db)
        }
    }

    public func purgeOlderThan(days: Int) throws {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        else { return }

        try dbQueue.write { db in
            let stale = try Capture
                .filter(Column("ts") < cutoff)
                .fetchAll(db)
            for row in stale {
                if let p = row.screenshotPath {
                    try? FileManager.default.removeItem(atPath: p)
                }
            }
            try db.execute(sql: "DELETE FROM captures WHERE ts < ?", arguments: [cutoff])
        }
    }

    public func recentCaptures(limit: Int = 100) throws -> [Capture] {
        try dbQueue.read { db in
            try Capture
                .order(Column("ts").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func setSuggestionStatus(id: Int64, status: SuggestionStatus) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE workflow_suggestions SET status = ? WHERE id = ?",
                arguments: [status.rawValue, id]
            )
        }
    }

    /// Mark a suggestion as accepted and create a Workflow row from it.
    /// Returns the new workflow's id.
    @discardableResult
    public func saveSuggestionAsWorkflow(_ suggestion: WorkflowSuggestion) throws -> Int64 {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE workflow_suggestions SET status = ? WHERE id = ?",
                arguments: [SuggestionStatus.accepted.rawValue, suggestion.id]
            )
            var workflow = Workflow(
                sourceSuggestionID: suggestion.id,
                name: suggestion.title,
                configJSON: suggestion.evidenceJSON,
                enabled: true,
                createdAt: Date()
            )
            try workflow.insert(db)
            return workflow.id ?? -1
        }
    }
}
