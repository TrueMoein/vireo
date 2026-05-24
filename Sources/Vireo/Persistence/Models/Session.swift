// Session.swift — one capture event: the user's selection + the model's
// corrected version + provenance.

import Foundation
import GRDB

struct Session: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: Int64?
    let timestamp: Date
    let sourceApp: String?
    let rawText: String
    let correctedText: String
    let llmProvider: String?
    let model: String?
    let latencyMs: Int?
}

extension Session: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "session"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
