import Foundation
import GRDB

public enum SuggestionStatus: String, Codable {
    case pending
    case accepted
    case dismissed
}

public struct WorkflowSuggestion: Codable, FetchableRecord, MutablePersistableRecord {
    public var id: Int64?
    public var createdAt: Date
    public var title: String
    public var description: String
    public var triggerPattern: String?
    public var evidenceJSON: String?
    public var confidence: Double
    public var estimatedTimeSavedMin: Int
    public var status: String

    public static let databaseTableName = "workflow_suggestions"

    public init(
        id: Int64? = nil,
        createdAt: Date,
        title: String,
        description: String,
        triggerPattern: String?,
        evidenceJSON: String?,
        confidence: Double,
        estimatedTimeSavedMin: Int,
        status: SuggestionStatus = .pending
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.description = description
        self.triggerPattern = triggerPattern
        self.evidenceJSON = evidenceJSON
        self.confidence = confidence
        self.estimatedTimeSavedMin = estimatedTimeSavedMin
        self.status = status.rawValue
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

public struct Workflow: Codable, FetchableRecord, MutablePersistableRecord {
    public var id: Int64?
    public var sourceSuggestionID: Int64?
    public var name: String
    public var configJSON: String?
    public var enabled: Bool
    public var createdAt: Date

    public static let databaseTableName = "workflows"

    public init(
        id: Int64? = nil,
        sourceSuggestionID: Int64? = nil,
        name: String,
        configJSON: String? = nil,
        enabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceSuggestionID = sourceSuggestionID
        self.name = name
        self.configJSON = configJSON
        self.enabled = enabled
        self.createdAt = createdAt
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
