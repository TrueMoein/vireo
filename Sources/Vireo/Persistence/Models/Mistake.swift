// Mistake.swift — one tagged mistake inside a session.

import Foundation
import GRDB

struct Mistake: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: Int64?
    let sessionId: Int64
    let originalPhrase: String
    let fixedPhrase: String
    let category: String
    let rule: String
    let explanation: String
}

extension Mistake: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "mistake"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
